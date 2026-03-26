<#
.SYNOPSIS
    Produces brainstorming/specification artifacts for the orchestration pipeline.

.DESCRIPTION
    Runs the repository-owned brainstorm/spec lifecycle before execution
    planning begins. When live dispatch is enabled, invokes the brainstorming
    agent through the local Codex CLI and persists a versioned specification
    when required.

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
    Path to the request artifact used as the initial payload.

.PARAMETER InputArtifactManifestPath
    Path to the upstream artifact manifest containing intake artifacts.

.PARAMETER OutputArtifactManifestPath
    Artifact manifest written by this stage.

.PARAMETER AgentsManifestPath
    Relative or absolute path to the orchestration agent manifest.

.PARAMETER DispatchMode
    Dispatch mode declared by the pipeline stage contract.

.PARAMETER PromptTemplatePath
    Specification prompt template used when live dispatch is enabled.

.PARAMETER ResponseSchemaPath
    JSON schema used to validate live brainstorm/spec output.

.PARAMETER DispatchCommand
    Local command used to invoke Codex dispatch.

.PARAMETER ExecutionBackend
    Selected backend for the run, such as `script-only` or `codex-exec`.

.PARAMETER EffectiveModel
    Optional resolved model override for live brainstorm/spec dispatch.

.PARAMETER StageStatePath
    Optional override path for the persisted stage-state artifact.

.PARAMETER DetailedOutput
    Enables verbose diagnostics for stage execution.

.EXAMPLE
    pwsh -File scripts/orchestration/stages/spec-stage.ps1 -RepoRoot . -RunDirectory .temp/runs/example -TraceId trace-1 -StageId spec -AgentId brainstormer -RequestPath .temp/runs/example/request.md -InputArtifactManifestPath .temp/runs/example/intake-output.json -OutputArtifactManifestPath .temp/runs/example/spec-output.json -ExecutionBackend codex-exec -DispatchMode codex-exec

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

# Builds a checksum-bearing artifact descriptor for the stage manifest.
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

# Reads a JSON file using a repository-wide deep parse depth.
function Read-JsonFile {
    param([string] $Path)

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Writes JSON deterministically without adding an implicit trailing newline.
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

# Writes text only when the target content changes, preserving file timestamps when unchanged.
function Set-TextContentIfChanged {
    param(
        [string] $Path,
        [string] $Content
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existingContent = Get-Content -Raw -LiteralPath $Path
        if ([string]::Equals($existingContent, $Content, [System.StringComparison]::Ordinal)) {
            return $false
        }
    }

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8 -NoNewline
    return $true
}

# Expands a prompt template by replacing token placeholders with supplied values.
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

# Converts free-text work intent into a stable specification slug.
function Convert-ToSlug {
    param([string] $Text)

    $value = ($Text ?? '').ToLowerInvariant()
    $value = [regex]::Replace($value, '[^a-z0-9]+', '-')
    $value = $value.Trim('-')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 'workstream'
    }

    if ($value.Length -gt 48) {
        return $value.Substring(0, 48).Trim('-')
    }

    return $value
}

# Retrieves a single agent contract from the orchestration manifest.
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

# Creates a deterministic fallback spec result when live dispatch is unavailable.
function New-FallbackSpecResult {
    param(
        [string] $RequestText,
        [object] $IntakeReport
    )

    $normalizedRequest = ($RequestText ?? '').Trim()
    if ([string]::IsNullOrWhiteSpace($normalizedRequest)) {
        $normalizedRequest = 'No request content provided.'
    }

    $slug = if ($null -ne $IntakeReport -and -not [string]::IsNullOrWhiteSpace([string] $IntakeReport.workstreamSlug)) {
        [string] $IntakeReport.workstreamSlug
    }
    else {
        Convert-ToSlug -Text $normalizedRequest
    }

    $lowerRequest = $normalizedRequest.ToLowerInvariant()
    $specRequired = ($null -ne $IntakeReport -and [bool] $IntakeReport.planningRequired) -and (
        $lowerRequest -match '\b(add|build|change|create|design|feature|flow|implement|introduce|migrate|refactor|workflow)\b'
    )

    return [ordered]@{
        stage = 'brainstorm-spec'
        status = if ($specRequired) { 'required' } else { 'not-required' }
        specRequired = $specRequired
        workstreamSlug = $slug
        specSummary = if ($specRequired) {
            'A versioned spec is required before planning because the workstream changes behavior or workflow in a non-trivial way.'
        }
        else {
            'No separate spec is required because the workstream is narrow enough to move directly into execution planning.'
        }
        designDecisions = if ($specRequired) {
            @(
                'Capture the normalized request before planning.',
                'Keep design intent versioned separately from the task plan.'
            )
        }
        else {
            @('Proceed directly to planning with the normalized request as the controlling input.')
        }
        alternativesConsidered = if ($specRequired) {
            @('Skipping a separate spec and planning directly from intake.')
        }
        else {
            @('Creating a separate spec despite the low design complexity.')
        }
        assumptions = @('Repository instructions and planning policy remain authoritative.')
        risks = if ($specRequired) {
            @('Skipping the spec would force design decisions into the task plan.')
        }
        else {
            @('The workstream may need a late spec if hidden design complexity appears.')
        }
        acceptanceCriteria = @(
            'The workstream has an explicit design summary.',
            'Planning can proceed with a stable source of intent.'
        )
        planningReadiness = if ($specRequired) { 'ready-for-plan' } else { 'not-needed' }
        recommendedSpecialists = @()
        notes = @('Fallback spec routing was used because live brainstorm dispatch was unavailable.')
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
$intakeReportPath = if ($artifactMap.ContainsKey('intake-report')) { [string] $artifactMap['intake-report'] } else { $null }

if ($null -ne $normalizedRequestPath -and (Test-Path -LiteralPath $normalizedRequestPath -PathType Leaf)) {
    $normalizedRequestContent = (Get-Content -Raw -LiteralPath $normalizedRequestPath).Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalizedRequestContent)) {
        $requestContent = $normalizedRequestContent
    }
}

$intakeReport = if ($null -ne $intakeReportPath -and (Test-Path -LiteralPath $intakeReportPath -PathType Leaf)) {
    Read-JsonFile -Path $intakeReportPath
}
else {
    throw 'Specification stage requires intake-report artifact.'
}
$intakeReportJson = if ($null -ne $intakeReportPath -and (Test-Path -LiteralPath $intakeReportPath -PathType Leaf)) {
    Get-Content -Raw -LiteralPath $intakeReportPath
}
else {
    '{}'
}

$allowedPaths = @($agent.allowedPaths | ForEach-Object { [string] $_ })
$shouldUseCodexDispatch = ($ExecutionBackend -eq 'codex-exec') -and ($DispatchMode -eq 'codex-exec')
$dispatchRecordPath = Join-Path $stageMetadataDirectory 'spec-dispatch.json'
$dispatchResultPath = Join-Path $stageMetadataDirectory 'spec-result.json'
$dispatchPromptPath = Join-Path $stageMetadataDirectory 'spec-prompt.md'
$dispatchError = $null
$specResult = $null
$backendUsed = if ($shouldUseCodexDispatch) { 'codex-exec' } else { 'scripted' }

if ($shouldUseCodexDispatch) {
    try {
        if (-not (Test-Path -LiteralPath $resolvedPromptTemplatePath -PathType Leaf)) {
            throw "Specification prompt template not found: $resolvedPromptTemplatePath"
        }

        if (-not (Test-Path -LiteralPath $resolvedResponseSchemaPath -PathType Leaf)) {
            throw "Specification response schema not found: $resolvedResponseSchemaPath"
        }

        $templateText = Get-Content -Raw -LiteralPath $resolvedPromptTemplatePath
        $renderedPrompt = Expand-Template -TemplateText $templateText -Tokens @{
            REQUEST_TEXT = $requestContent
            INTAKE_REPORT_JSON = $intakeReportJson
            AGENT_ALLOWED_PATHS = (($allowedPaths | ForEach-Object { '- ' + $_ }) -join [Environment]::NewLine)
        }
        Set-Content -LiteralPath $dispatchPromptPath -Value $renderedPrompt -Encoding UTF8 -NoNewline

        $dispatchScriptPath = Join-Path $resolvedRepoRoot 'scripts/orchestration/engine/invoke-codex-dispatch.ps1'
        $dispatchParameters = @{
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
        & $dispatchScriptPath @dispatchParameters
        $specResult = Read-JsonFile -Path $dispatchResultPath
    }
    catch {
        $dispatchError = $_.Exception.Message
        Write-StyledOutput ("[WARN] Specification live dispatch failed. Falling back to scripted mode. {0}" -f $dispatchError)
        $backendUsed = 'scripted'
    }
}

if ($null -eq $specResult) {
    $specResult = New-FallbackSpecResult -RequestText $requestContent -IntakeReport $intakeReport
}

$specSummaryPath = Join-Path $stageArtifactsDirectory 'spec-summary.json'
$activeSpecArtifactPath = Join-Path $stageArtifactsDirectory 'spec-not-required.md'
$specVersioned = $false

if ([bool] $specResult.specRequired) {
    $specsDirectory = Join-Path $resolvedRepoRoot 'planning/specs/active'
    New-Item -ItemType Directory -Path $specsDirectory -Force | Out-Null
    $specSlug = if (-not [string]::IsNullOrWhiteSpace([string] $specResult.workstreamSlug)) {
        [string] $specResult.workstreamSlug
    }
    else {
        Convert-ToSlug -Text $requestContent
    }
    $existingActiveSpec = Get-ChildItem -LiteralPath $specsDirectory -File -Filter ("spec-*-{0}.md" -f $specSlug) |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    $activeSpecArtifactPath = if ($null -ne $existingActiveSpec) {
        $existingActiveSpec.FullName
    }
    else {
        Join-Path $specsDirectory ("spec-{0}-{1}.md" -f $TraceId, $specSlug)
    }

    $specMarkdown = @(
        '# Specification',
        '',
        ('- Workstream: {0}' -f [string] $specResult.workstreamSlug),
        '',
        '## Objective',
        ('- {0}' -f $requestContent),
        '',
        '## Summary',
        ('- {0}' -f [string] $specResult.specSummary),
        '',
        '## Design Decisions'
    )
    $specMarkdown += @($specResult.designDecisions | ForEach-Object { '- ' + [string] $_ })
    $specMarkdown += @(
        '',
        '## Alternatives Considered'
    )
    $specMarkdown += @($specResult.alternativesConsidered | ForEach-Object { '- ' + [string] $_ })
    $specMarkdown += @(
        '',
        '## Assumptions'
    )
    $specMarkdown += @($specResult.assumptions | ForEach-Object { '- ' + [string] $_ })
    $specMarkdown += @(
        '',
        '## Risks'
    )
    $specMarkdown += @($specResult.risks | ForEach-Object { '- ' + [string] $_ })
    $specMarkdown += @(
        '',
        '## Acceptance Criteria'
    )
    $specMarkdown += @($specResult.acceptanceCriteria | ForEach-Object { '- ' + [string] $_ })
    $specMarkdown += @(
        '',
        '## Planning Readiness',
        ('- {0}' -f [string] $specResult.planningReadiness),
        '',
        '## Recommended Specialists'
    )
    $specMarkdown += @($specResult.recommendedSpecialists | ForEach-Object { '- ' + [string] $_ })
    $specMarkdown += @(
        '',
        '## Notes'
    )
    $specMarkdown += @($specResult.notes | ForEach-Object { '- ' + [string] $_ })
    $null = Set-TextContentIfChanged -Path $activeSpecArtifactPath -Content ($specMarkdown -join "`n")
    $specVersioned = $true
}
else {
    Set-Content -LiteralPath $activeSpecArtifactPath -Value 'No separate spec was required for this workstream.' -Encoding UTF8 -NoNewline
}

Write-JsonFile -Path $specSummaryPath -Value $specResult

$outputManifestDirectory = Split-Path -Parent $resolvedOutputManifestPath
if (-not [string]::IsNullOrWhiteSpace($outputManifestDirectory)) {
    New-Item -ItemType Directory -Path $outputManifestDirectory -Force | Out-Null
}

$outputManifest = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    producedAt = (Get-Date).ToString('o')
    artifacts = @(
        (Get-ArtifactDescriptor -Name 'spec-summary' -Path $specSummaryPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'active-spec' -Path $activeSpecArtifactPath -Root $resolvedRepoRoot)
    )
}
Write-JsonFile -Path $resolvedOutputManifestPath -Value $outputManifest

$stageState = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    dispatchCount = if ($backendUsed -eq 'codex-exec') { 1 } else { 0 }
    specRequired = [bool] $specResult.specRequired
    specVersioned = $specVersioned
    planningReadiness = [string] $specResult.planningReadiness
    promptTemplatePath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedPromptTemplatePath } else { $null }
    responseSchemaPath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedResponseSchemaPath } else { $null }
    dispatchRecordPath = if ((Test-Path -LiteralPath $dispatchRecordPath -PathType Leaf)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $dispatchRecordPath } else { $null }
    activeSpecPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $activeSpecArtifactPath
    warning = $dispatchError
}
Write-JsonFile -Path $resolvedStageStatePath -Value $stageState

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)
exit 0