<#
.SYNOPSIS
    Produces route-selection artifacts for the orchestration pipeline.

.DESCRIPTION
    Optimizes the context pack and recommends the specialist focus for the
    implementation stage. When live dispatch is enabled, the router agent is
    invoked through the local Codex CLI and must return schema-valid JSON.

.PARAMETER RepoRoot
    Repository root used to resolve manifests, prompts, schemas, and artifacts.

.PARAMETER RunDirectory
    Pipeline run directory where stage artifacts and metadata are persisted.

.PARAMETER TraceId
    Stable execution trace identifier for the current pipeline run.

.PARAMETER StageId
    Stage identifier from the pipeline manifest.

.PARAMETER AgentId
    Agent contract identifier used for this stage.

.PARAMETER RequestPath
    Path to the normalized request payload for the run.

.PARAMETER InputArtifactManifestPath
    Artifact manifest produced by the previous stage.

.PARAMETER OutputArtifactManifestPath
    Artifact manifest written by this stage.

.PARAMETER AgentsManifestPath
    Relative or absolute path to the orchestration agent manifest.

.PARAMETER DispatchMode
    Dispatch mode declared by the pipeline stage contract.

.PARAMETER PromptTemplatePath
    Router prompt template used when live dispatch is enabled.

.PARAMETER ResponseSchemaPath
    JSON schema used to validate live router output.

.PARAMETER DispatchCommand
    Local command used to invoke Codex dispatch.

.PARAMETER ExecutionBackend
    Selected backend for the run, such as `script-only` or `codex-exec`.

.PARAMETER EffectiveModel
    Optional resolved model override for live router dispatch.

.PARAMETER StageStatePath
    Optional override path for the persisted stage-state artifact.

.PARAMETER DetailedOutput
    Enables verbose diagnostics for stage execution.

.EXAMPLE
    pwsh -File scripts/orchestration/stages/route-stage.ps1 -RepoRoot . -RunDirectory .temp/runs/example -TraceId trace-1 -StageId route -AgentId router -RequestPath .temp/runs/example/request.md -InputArtifactManifestPath .temp/runs/example/plan-output.json -OutputArtifactManifestPath .temp/runs/example/route-output.json

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RunDirectory,
    [Parameter(Mandatory = $true)] [string] $TraceId,
    [Parameter(Mandatory = $true)] [string] $StageId,
    [Parameter(Mandatory = $true)] [string] $AgentId,
    [Parameter(Mandatory = $true)] [string] $RequestPath,
    [Parameter(Mandatory = $true)] [string] $InputArtifactManifestPath,
    [Parameter(Mandatory = $true)] [string] $OutputArtifactManifestPath,
    [string] $AgentsManifestPath = '.codex/orchestration/agents.manifest.json',
    [string] $DispatchMode = 'scripted',
    [string] $PromptTemplatePath,
    [string] $ResponseSchemaPath,
    [string] $DispatchCommand = 'codex',
    [string] $ExecutionBackend = 'script-only',
    [string] $EffectiveModel,
    [string] $StageStatePath,
    [switch] $DetailedOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:IsVerboseEnabled = [bool] $DetailedOutput
# Builds one artifact descriptor with checksum metadata.
function Get-ArtifactDescriptor {
    param(
        [string] $Name,
        [string] $Path,
        [string] $Root
    )

    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return [ordered]@{
        name = $Name
        path = (Convert-ToRelativeRepoPath -Root $Root -Path $Path)
        checksum = ("sha256:{0}" -f $hash.Hash.ToLowerInvariant())
    }
}

# Reads a JSON file and returns the parsed object.
function Read-JsonFile {
    param([string] $Path)

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Writes JSON content without a trailing newline.
function Write-JsonFile {
    param(
        [string] $Path,
        [object] $Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value ($Value | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}

# Replaces token placeholders in a prompt template.
function Expand-Template {
    param(
        [string] $TemplateText,
        [hashtable] $Tokens
    )

    $rendered = $TemplateText
    foreach ($key in $Tokens.Keys) {
        $rendered = $rendered.Replace(("{{{0}}}" -f $key), [string] $Tokens[$key])
    }

    return $rendered
}

# Loads one agent contract from the orchestration manifest.
function Get-AgentContract {
    param(
        [string] $ManifestPath,
        [string] $TargetAgentId
    )

    $manifest = Read-JsonFile -Path $ManifestPath
    return @($manifest.agents | Where-Object { $_.id -eq $TargetAgentId } | Select-Object -First 1)
}

# Converts an artifact manifest into a name-to-path lookup table.
function Convert-ArtifactManifestToMap {
    param(
        [object] $Manifest,
        [string] $Root
    )

    $map = @{}
    foreach ($artifact in @($Manifest.artifacts)) {
        $name = [string] $artifact.name
        $path = [string] $artifact.path
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $map[$name] = Resolve-FullPath -BasePath $Root -Candidate $path
    }

    return $map
}

# Normalizes request text for keyword-based fallback routing.
function Get-RequestKeywords {
    param([string] $Text)

    return ($Text ?? '').ToLowerInvariant()
}

# Produces the deterministic fallback routing result when live dispatch is unavailable.
function New-FallbackRouteResult {
    param(
        [string] $RequestText,
        [object] $TaskPlanData
    )

    $requestKeywords = Get-RequestKeywords -Text $RequestText
    $recommendedSkill = 'dev-software-engineer'
    $specialistFocus = 'General repository implementation and refactor work.'

    if ($requestKeywords -match 'rust|cargo|crate') {
        $recommendedSkill = 'dev-rust-engineer'
        $specialistFocus = 'Rust crate organization, implementation, and tests.'
    }
    elseif ($requestKeywords -match 'vue|quasar|frontend|ui|ux') {
        $recommendedSkill = 'dev-frontend-vue-quasar-engineer'
        $specialistFocus = 'Vue/Quasar UI behavior, state, and responsive frontend structure.'
    }
    elseif ($requestKeywords -match 'docker|k8s|kubernetes|workflow|pipeline|github actions|devops') {
        $recommendedSkill = 'ops-devops-platform-engineer'
        $specialistFocus = 'CI/CD, container, workflow, and platform automation changes.'
    }
    elseif ($requestKeywords -match 'security|vulnerability|owasp|audit|hardening') {
        $recommendedSkill = 'sec-security-vulnerability-engineer'
        $specialistFocus = 'Security posture, package risk, and vulnerability remediation.'
    }
    elseif ($requestKeywords -match 'observability|sre|sli|slo|telemetry|incident') {
        $recommendedSkill = 'obs-sre-observability-engineer'
        $specialistFocus = 'Observability controls, telemetry, and operational readiness.'
    }
    elseif ($requestKeywords -match 'dotnet|c#|asp.net|backend|api|ef core|cqrs') {
        $recommendedSkill = 'dev-dotnet-backend-engineer'
        $specialistFocus = '.NET backend, API, CQRS, and service-layer implementation.'
    }

    $contextPaths = New-Object System.Collections.Generic.List[string]
    foreach ($contextPath in @($TaskPlanData.contextPaths)) {
        $pathText = [string] $contextPath
        if (-not [string]::IsNullOrWhiteSpace($pathText) -and -not $contextPaths.Contains($pathText)) {
            $contextPaths.Add($pathText) | Out-Null
        }
    }
    foreach ($extraPath in @(
        '.github/instructions/super-agent.instructions.md',
        '.github/instructions/subagent-planning-workflow.instructions.md',
        '.github/instruction-routing.catalog.yml'
    )) {
        if (-not $contextPaths.Contains($extraPath)) {
            $contextPaths.Add($extraPath) | Out-Null
        }
    }

    return [ordered]@{
        summary = 'Fallback routing selected a specialist focus and reduced the context pack deterministically.'
        recommendedSpecialistSkill = $recommendedSkill
        recommendedSpecialistFocus = $specialistFocus
        contextPaths = @($contextPaths)
        tokenBudgetGuidance = @(
            'Load only mandatory context plus the routed domain files.',
            'Keep specialist prompts focused on the current work item and route result.',
            'Do not expand context with unrelated templates or prompts.'
        )
        executionNotes = @(
            'Apply the routed specialist focus to all work items.',
            'Preserve the planning artifact until closeout succeeds.'
        )
        validationFocus = @($TaskPlanData.validations | ForEach-Object { [string] $_ })
        closeoutExpectations = @(
            'Prepare commit-ready summary in closeout stage.',
            'Update README or changelog only when the changed scope requires it.'
        )
        shouldRunTester = $true
        readmeImpact = ($requestKeywords -match 'readme|documentation|docs')
        changelogImpact = $true
    }
}

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$resolvedRequestPath = [System.IO.Path]::GetFullPath($RequestPath)
$resolvedInputManifestPath = [System.IO.Path]::GetFullPath($InputArtifactManifestPath)
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)
$resolvedAgentsManifestPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $AgentsManifestPath
$resolvedPromptTemplatePath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $PromptTemplatePath
$resolvedResponseSchemaPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResponseSchemaPath
$resolvedStageStatePath = if ([string]::IsNullOrWhiteSpace($StageStatePath)) { Join-Path $resolvedRunDirectory ('stages/{0}-state.json' -f $StageId) } else { Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $StageStatePath }

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
$stageMetadataDirectory = Join-Path $resolvedRunDirectory ('stages/{0}' -f $StageId)
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stageMetadataDirectory -Force | Out-Null

$requestContent = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}

$agent = Get-AgentContract -ManifestPath $resolvedAgentsManifestPath -TargetAgentId $AgentId
if ($null -eq $agent) {
    throw ("Agent contract not found for stage {0}: {1}" -f $StageId, $AgentId)
}

$inputManifest = Read-JsonFile -Path $resolvedInputManifestPath
$artifactMap = Convert-ArtifactManifestToMap -Manifest $inputManifest -Root $resolvedRepoRoot
$normalizedRequestPath = if ($artifactMap.ContainsKey('normalized-request')) { [string] $artifactMap['normalized-request'] } else { $null }
$taskPlanDataPath = if ($artifactMap.ContainsKey('task-plan-data')) { [string] $artifactMap['task-plan-data'] } else { $null }
$contextPackPath = if ($artifactMap.ContainsKey('context-pack')) { [string] $artifactMap['context-pack'] } else { $null }

if ($null -ne $normalizedRequestPath -and (Test-Path -LiteralPath $normalizedRequestPath -PathType Leaf)) {
    $normalizedRequestContent = (Get-Content -Raw -LiteralPath $normalizedRequestPath).Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalizedRequestContent)) {
        $requestContent = $normalizedRequestContent
    }
}

$taskPlanData = if ($null -ne $taskPlanDataPath -and (Test-Path -LiteralPath $taskPlanDataPath -PathType Leaf)) { Read-JsonFile -Path $taskPlanDataPath } else { $null }
if ($null -eq $taskPlanData) {
    throw 'Route stage requires task-plan-data artifact.'
}

$contextPackJson = if ($null -ne $contextPackPath -and (Test-Path -LiteralPath $contextPackPath -PathType Leaf)) {
    Get-Content -Raw -LiteralPath $contextPackPath
}
else {
    '{}'
}

$shouldUseCodexDispatch = ($ExecutionBackend -eq 'codex-exec') -and ($DispatchMode -eq 'codex-exec')
$backendUsed = if ($shouldUseCodexDispatch) { 'codex-exec' } else { 'scripted' }
$dispatchError = $null
$routeResult = $null
$dispatchRecordPath = Join-Path $stageMetadataDirectory 'router-dispatch.json'
$dispatchResultPath = Join-Path $stageMetadataDirectory 'router-result.json'
$dispatchPromptPath = Join-Path $stageMetadataDirectory 'router-prompt.md'

if ($shouldUseCodexDispatch) {
    try {
        $templateText = Get-Content -Raw -LiteralPath $resolvedPromptTemplatePath
        $renderedPrompt = Expand-Template -TemplateText $templateText -Tokens @{
            REQUEST_TEXT = $requestContent
            TASK_PLAN_JSON = ($taskPlanData | ConvertTo-Json -Depth 100)
            CONTEXT_PACK_JSON = $contextPackJson
        }
        Set-Content -LiteralPath $dispatchPromptPath -Value $renderedPrompt -Encoding UTF8 -NoNewline

        $dispatchScriptPath = Join-Path $resolvedRepoRoot 'scripts/orchestration/engine/invoke-codex-dispatch.ps1'
        $dispatchParams = @{
            RepoRoot = $resolvedRepoRoot
            WorkingDirectory = $resolvedRepoRoot
            TraceId = $TraceId
            StageId = $StageId
            AgentId = $AgentId
            PromptPath = $dispatchPromptPath
            ResponseSchemaPath = $resolvedResponseSchemaPath
            ResultPath = $dispatchResultPath
            DispatchRecordPath = $dispatchRecordPath
            CommandName = $DispatchCommand
            Model = if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $agent.model } else { $EffectiveModel }
            DetailedOutput = [bool] $DetailedOutput
        }
        & $dispatchScriptPath @dispatchParams
        $routeResult = Read-JsonFile -Path $dispatchResultPath
    }
    catch {
        $dispatchError = $_.Exception.Message
        Write-StyledOutput ("[WARN] Router live dispatch failed. Falling back to scripted mode. {0}" -f $dispatchError)
        $backendUsed = 'scripted'
    }
}

if ($null -eq $routeResult) {
    $routeResult = New-FallbackRouteResult -RequestText $requestContent -TaskPlanData $taskPlanData
}

$routeSelectionPath = Join-Path $stageArtifactsDirectory 'route-selection.json'
$specialistContextPackPath = Join-Path $stageArtifactsDirectory 'specialist-context-pack.json'

Write-JsonFile -Path $routeSelectionPath -Value $routeResult

$specialistContextPack = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    generatedAt = (Get-Date).ToString('o')
    mandatoryContext = @(
        '.github/AGENTS.md',
        '.github/copilot-instructions.md'
    )
    recommendedSpecialistSkill = [string] $routeResult.recommendedSpecialistSkill
    recommendedSpecialistFocus = [string] $routeResult.recommendedSpecialistFocus
    contextPaths = @($routeResult.contextPaths | ForEach-Object { [string] $_ })
    tokenBudgetGuidance = @($routeResult.tokenBudgetGuidance | ForEach-Object { [string] $_ })
    executionNotes = @($routeResult.executionNotes | ForEach-Object { [string] $_ })
    validationFocus = @($routeResult.validationFocus | ForEach-Object { [string] $_ })
    closeoutExpectations = @($routeResult.closeoutExpectations | ForEach-Object { [string] $_ })
}
Write-JsonFile -Path $specialistContextPackPath -Value $specialistContextPack

$outputManifest = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    producedAt = (Get-Date).ToString('o')
    artifacts = @(
        (Get-ArtifactDescriptor -Name 'route-selection' -Path $routeSelectionPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'specialist-context-pack' -Path $specialistContextPackPath -Root $resolvedRepoRoot)
    )
}
Write-JsonFile -Path $resolvedOutputManifestPath -Value $outputManifest

$stageState = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    dispatchCount = if ($backendUsed -eq 'codex-exec') { 1 } else { 0 }
    workItemCount = @($taskPlanData.workItems).Count
    promptTemplatePath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedPromptTemplatePath } else { $null }
    responseSchemaPath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedResponseSchemaPath } else { $null }
    dispatchRecordPath = if ((Test-Path -LiteralPath $dispatchRecordPath -PathType Leaf)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $dispatchRecordPath } else { $null }
    selectedSkill = [string] $routeResult.recommendedSpecialistSkill
    warning = $dispatchError
}
Write-JsonFile -Path $resolvedStageStatePath -Value $stageState

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)
exit 0