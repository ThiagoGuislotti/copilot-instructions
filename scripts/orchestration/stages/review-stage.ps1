<#
.SYNOPSIS
    Produces review and decision artifacts for the orchestration pipeline.

.DESCRIPTION
    Reads validation outputs and writes:
    - review-report markdown artifact
    - decision-log markdown artifact
    - output artifact manifest for handoff

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

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/orchestration/stages/review-stage.ps1 -RepoRoot . -RunDirectory .temp/runs/run-123 -TraceId run-123 -StageId review -AgentId reviewer -RequestPath .temp/runs/run-123/artifacts/request.md -InputArtifactManifestPath .temp/runs/run-123/stages/validate-input.json -OutputArtifactManifestPath .temp/runs/run-123/stages/review-output.json

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
    [switch] $DetailedOutput
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:IsVerboseEnabled = [bool] $DetailedOutput

# Writes verbose diagnostics for stage execution.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Converts an absolute path to repository-relative path when possible.
function Convert-ToRelativeRepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    try {
        return [System.IO.Path]::GetRelativePath($Root, $Path)
    }
    catch {
        return $Path
    }
}

# Builds an artifact descriptor including checksum.
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

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$resolvedRequestPath = [System.IO.Path]::GetFullPath($RequestPath)
$resolvedInputManifestPath = [System.IO.Path]::GetFullPath($InputArtifactManifestPath)
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null

$inputManifest = $null
if (Test-Path -LiteralPath $resolvedInputManifestPath -PathType Leaf) {
    $inputManifest = Get-Content -Raw -LiteralPath $resolvedInputManifestPath | ConvertFrom-Json -Depth 100
}

$validationArtifact = $null
if ($null -ne $inputManifest) {
    $validationArtifact = @($inputManifest.artifacts | Where-Object { $_.name -eq 'validation-report' } | Select-Object -First 1)
}

$validationReport = $null
if ($null -ne $validationArtifact) {
    $validationPath = Join-Path $resolvedRepoRoot ([string] $validationArtifact.path)
    if (Test-Path -LiteralPath $validationPath -PathType Leaf) {
        $validationReport = Get-Content -Raw -LiteralPath $validationPath | ConvertFrom-Json -Depth 100
    }
}

$failedChecks = if ($null -ne $validationReport) { [int] $validationReport.summary.failedChecks } else { 1 }
$decision = if ($failedChecks -eq 0) { 'approved' } else { 'blocked' }
$requestPreview = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}
if ($requestPreview.Length -gt 220) {
    $requestPreview = $requestPreview.Substring(0, 220) + '...'
}

$reviewReportPath = Join-Path $stageArtifactsDirectory 'review-report.md'
$decisionLogPath = Join-Path $stageArtifactsDirectory 'decision-log.md'
$recommendationText = if ($decision -eq 'approved') {
    '- Proceed with delivery.'
}
else {
    '- Resolve failed validation checks before delivery.'
}

$reviewReport = @(
    ('# Review Report ({0})' -f $TraceId),
    '',
    ('- Stage: {0}' -f $StageId),
    ('- Agent: {0}' -f $AgentId),
    ('- GeneratedAt: {0}' -f (Get-Date).ToString('o')),
    ('- Decision: {0}' -f $decision),
    '',
    '## Validation Summary',
    ('- Failed checks: {0}' -f $failedChecks),
    ('- Request artifact: {0}' -f (Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedRequestPath)),
    '',
    '## Recommendation',
    $recommendationText,
    '',
    '## Request Snapshot',
    $requestPreview
) -join "`n"

Set-Content -LiteralPath $reviewReportPath -Value $reviewReport -Encoding UTF8 -NoNewline

$decisionLog = @(
    ('# Decision Log ({0})' -f $TraceId),
    '',
    ('- Decision: {0}' -f $decision),
    ('- RecordedAt: {0}' -f (Get-Date).ToString('o')),
    '',
    '## Notes',
    '- Decision is based on validation-report artifact status.',
    '- Guardrails and policy checks must remain green for release.'
) -join "`n"

Set-Content -LiteralPath $decisionLogPath -Value $decisionLog -Encoding UTF8 -NoNewline

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

Set-Content -LiteralPath $resolvedOutputManifestPath -Value ($outputManifest | ConvertTo-Json -Depth 40) -Encoding UTF8 -NoNewline

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)
exit 0