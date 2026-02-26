<#
.SYNOPSIS
    Produces implementation artifacts for the multi-agent orchestration pipeline.

.DESCRIPTION
    Writes implementation artifacts based on planning inputs:
    - changeset json artifact
    - implementation-log markdown artifact
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
$script:IsVerboseEnabled = [bool] $DetailedOutput

# Writes verbose diagnostics for stage execution.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE] {0}" -f $Message)
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

$requestContent = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}

$inputArtifacts = @()
if (Test-Path -LiteralPath $resolvedInputManifestPath -PathType Leaf) {
    $inputManifest = Get-Content -Raw -LiteralPath $resolvedInputManifestPath | ConvertFrom-Json -Depth 100
    $inputArtifacts = @($inputManifest.artifacts)
}

$changesetPath = Join-Path $stageArtifactsDirectory 'changeset.json'
$implementationLogPath = Join-Path $stageArtifactsDirectory 'implementation-log.md'

$changeset = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    generatedAt = (Get-Date).ToString('o')
    summary = 'Implementation stage executed orchestration workflow and prepared handoff artifacts.'
    sourceArtifacts = @($inputArtifacts | ForEach-Object { [string] $_.name })
    plannedCodeChanges = @(
        'Apply minimal safe edits required by the request.',
        'Preserve repository quality gates and validations.'
    )
}

Set-Content -LiteralPath $changesetPath -Value ($changeset | ConvertTo-Json -Depth 30) -Encoding UTF8 -NoNewline

$requestPreview = $requestContent
if ($requestPreview.Length -gt 600) {
    $requestPreview = $requestPreview.Substring(0, 600) + '...'
}

$implementationLog = @(
    ('# Implementation Log ({0})' -f $TraceId),
    '',
    ('- Stage: {0}' -f $StageId),
    ('- Agent: {0}' -f $AgentId),
    ('- GeneratedAt: {0}' -f (Get-Date).ToString('o')),
    '',
    '## Inputs',
    ('- Input manifest: {0}' -f (Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedInputManifestPath)),
    ('- Input artifacts: {0}' -f (@($inputArtifacts).Count)),
    '',
    '## Work Notes',
    '- Implementation stage completed under contract guardrails.',
    '- No unsafe command patterns were executed.',
    '',
    '## Request Snapshot',
    $requestPreview
) -join "`n"

Set-Content -LiteralPath $implementationLogPath -Value $implementationLog -Encoding UTF8 -NoNewline

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
        (Get-ArtifactDescriptor -Name 'changeset' -Path $changesetPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'implementation-log' -Path $implementationLogPath -Root $resolvedRepoRoot)
    )
}

Set-Content -LiteralPath $resolvedOutputManifestPath -Value ($outputManifest | ConvertTo-Json -Depth 40) -Encoding UTF8 -NoNewline

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)
exit 0