<#
.SYNOPSIS
    Produces review and decision artifacts for the orchestration pipeline.

.DESCRIPTION
    Produces review outputs and, when enabled, dispatches the reviewer through
    the local Codex CLI using changeset and validation artifacts as context.

.PARAMETER RepoRoot
    Repository root path.

.PARAMETER RunDirectory
    Absolute run directory for generated artifacts.

.PARAMETER TraceId
    Unique trace identifier for the pipeline run.

.PARAMETER StageId
    Current stage identifier.

.PARAMETER AgentId
    Current agent identifier.

.PARAMETER RequestPath
    Path to the request text artifact.

.PARAMETER InputArtifactManifestPath
    Path to input artifact manifest.

.PARAMETER OutputArtifactManifestPath
    Path where this stage writes its output artifact manifest.

.PARAMETER AgentsManifestPath
    Agent contract manifest path.

.PARAMETER DispatchMode
    Stage dispatch mode from pipeline execution settings.

.PARAMETER PromptTemplatePath
    Prompt template path for live dispatch.

.PARAMETER ResponseSchemaPath
    JSON schema path for live dispatch.

.PARAMETER DispatchCommand
    Codex CLI command name or absolute path.

.PARAMETER ExecutionBackend
    Runtime backend selection. `codex-exec` enables live dispatch.

.PARAMETER EffectiveModel
    Optional resolved model override for live reviewer dispatch.

.PARAMETER StageStatePath
    Optional path where stage execution metadata is written.

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File .\scripts\orchestration\stages\review-stage.ps1 -RepoRoot . -RunDirectory .temp\runs\trace-001 -TraceId trace-001 -StageId review -AgentId reviewer -RequestPath .temp\runs\trace-001\request.txt -InputArtifactManifestPath .temp\runs\trace-001\stages\validate\output-artifacts.json -OutputArtifactManifestPath .temp\runs\trace-001\stages\review\output-artifacts.json -ExecutionBackend codex-exec -DispatchMode codex-exec

.NOTES
    Falls back to a deterministic review decision derived from validation status when live reviewer dispatch is unavailable.
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

# Retrieves a single agent contract from the orchestration manifest.
function Get-AgentContract {
    param(
        [string] $ManifestPath,
        [string] $TargetAgentId
    )

    $manifest = Read-JsonFile -Path $ManifestPath
    return @($manifest.agents | Where-Object { $_.id -eq $TargetAgentId } | Select-Object -First 1)
}

# Converts an artifact manifest into a name-to-absolute-path lookup table.
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

# Creates a deterministic fallback review result when live reviewer dispatch is unavailable.
function New-FallbackReviewResult {
    param([int] $FailedChecks)

    $decision = if ($FailedChecks -eq 0) { 'approved' } else { 'blocked' }
    return [ordered]@{
        decision = $decision
        summary = 'Fallback review mode produced a deterministic decision from validation status only.'
        findings = if ($FailedChecks -eq 0) { @() } else { @('Validation stage reported one or more failed checks.') }
        requiredFollowUps = if ($FailedChecks -eq 0) { @() } else { @('Resolve validation failures before release.') }
        recommendation = if ($FailedChecks -eq 0) { 'Proceed with delivery.' } else { 'Block release until validation failures are resolved.' }
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

$agent = Get-AgentContract -ManifestPath $resolvedAgentsManifestPath -TargetAgentId $AgentId
if ($null -eq $agent) {
    throw ("Agent contract not found for stage {0}: {1}" -f $StageId, $AgentId)
}

$inputManifest = Read-JsonFile -Path $resolvedInputManifestPath
$artifactMap = Convert-ArtifactManifestToMap -Manifest $inputManifest -Root $resolvedRepoRoot
$normalizedRequestPath = if ($artifactMap.ContainsKey('normalized-request')) { [string] $artifactMap['normalized-request'] } else { $null }
$changesetPath = if ($artifactMap.ContainsKey('changeset')) { [string] $artifactMap['changeset'] } else { $null }
$validationReportPath = if ($artifactMap.ContainsKey('validation-report')) { [string] $artifactMap['validation-report'] } else { $null }

if ($null -ne $normalizedRequestPath -and (Test-Path -LiteralPath $normalizedRequestPath -PathType Leaf)) {
    $normalizedRequestContent = (Get-Content -Raw -LiteralPath $normalizedRequestPath).Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalizedRequestContent)) {
        $requestContent = $normalizedRequestContent
    }
}

$changesetJson = if ($null -ne $changesetPath -and (Test-Path -LiteralPath $changesetPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $changesetPath } else { '{}' }
$validationReport = if ($null -ne $validationReportPath -and (Test-Path -LiteralPath $validationReportPath -PathType Leaf)) { Read-JsonFile -Path $validationReportPath } else { $null }
$validationReportJson = if ($null -ne $validationReportPath -and (Test-Path -LiteralPath $validationReportPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $validationReportPath } else { '{}' }
$requestContent = if ($null -ne $normalizedRequestPath -and (Test-Path -LiteralPath $normalizedRequestPath -PathType Leaf)) {
    (Get-Content -Raw -LiteralPath $normalizedRequestPath).Trim()
}
elseif (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}
$failedChecks = if ($null -ne $validationReport) { [int] $validationReport.summary.failedChecks } else { 1 }
$shouldUseCodexDispatch = ($ExecutionBackend -eq 'codex-exec') -and ($DispatchMode -eq 'codex-exec')
$backendUsed = if ($shouldUseCodexDispatch) { 'codex-exec' } else { 'scripted' }
$dispatchError = $null
$reviewResult = $null
$dispatchRecordPath = Join-Path $stageMetadataDirectory 'reviewer-dispatch.json'
$dispatchResultPath = Join-Path $stageMetadataDirectory 'reviewer-result.json'
$dispatchPromptPath = Join-Path $stageMetadataDirectory 'reviewer-prompt.md'

if ($shouldUseCodexDispatch) {
    try {
        $templateText = Get-Content -Raw -LiteralPath $resolvedPromptTemplatePath
        $renderedPrompt = Expand-Template -TemplateText $templateText -Tokens @{
            REQUEST_TEXT = $requestContent
            CHANGESET_JSON = $changesetJson
            VALIDATION_REPORT_JSON = $validationReportJson
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
        $reviewResult = Read-JsonFile -Path $dispatchResultPath
    }
    catch {
        $dispatchError = $_.Exception.Message
        Write-StyledOutput ("[WARN] Reviewer live dispatch failed. Falling back to scripted mode. {0}" -f $dispatchError)
        $backendUsed = 'scripted'
    }
}

if ($null -eq $reviewResult) {
    $reviewResult = New-FallbackReviewResult -FailedChecks $failedChecks
}

$reviewReportPath = Join-Path $stageArtifactsDirectory 'review-report.md'
$decisionLogPath = Join-Path $stageArtifactsDirectory 'decision-log.md'

$reviewReport = @(
    ('# Review Report ({0})' -f $TraceId),
    '',
    ('- Stage: {0}' -f $StageId),
    ('- Agent: {0}' -f $AgentId),
    ('- Backend: {0}' -f $backendUsed),
    ('- GeneratedAt: {0}' -f (Get-Date).ToString('o')),
    ('- Decision: {0}' -f [string] $reviewResult.decision),
    '',
    '## Summary',
    ('- {0}' -f [string] $reviewResult.summary),
    '',
    '## Findings'
)
$reviewReport += @($reviewResult.findings | ForEach-Object { '- ' + [string] $_ })
$reviewReport += @(
    '',
    '## Required Follow-Ups'
)
$reviewReport += @($reviewResult.requiredFollowUps | ForEach-Object { '- ' + [string] $_ })
$reviewReport += @(
    '',
    '## Recommendation',
    ('- {0}' -f [string] $reviewResult.recommendation)
)
Set-Content -LiteralPath $reviewReportPath -Value ($reviewReport -join "`n") -Encoding UTF8 -NoNewline

$decisionLog = @(
    ('# Decision Log ({0})' -f $TraceId),
    '',
    ('- Decision: {0}' -f [string] $reviewResult.decision),
    ('- RecordedAt: {0}' -f (Get-Date).ToString('o')),
    ('- Backend: {0}' -f $backendUsed),
    '',
    '## Recommendation',
    ('- {0}' -f [string] $reviewResult.recommendation)
)
Set-Content -LiteralPath $decisionLogPath -Value ($decisionLog -join "`n") -Encoding UTF8 -NoNewline

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
        (Get-ArtifactDescriptor -Name 'review-report' -Path $reviewReportPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'decision-log' -Path $decisionLogPath -Root $resolvedRepoRoot)
    )
}
Write-JsonFile -Path $resolvedOutputManifestPath -Value $outputManifest

$stageState = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    dispatchCount = if ($backendUsed -eq 'codex-exec') { 1 } else { 0 }
    promptTemplatePath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedPromptTemplatePath } else { $null }
    responseSchemaPath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedResponseSchemaPath } else { $null }
    dispatchRecordPath = if ((Test-Path -LiteralPath $dispatchRecordPath -PathType Leaf)) { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $dispatchRecordPath } else { $null }
    warning = $dispatchError
}
Write-JsonFile -Path $resolvedStageStatePath -Value $stageState

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)
exit 0