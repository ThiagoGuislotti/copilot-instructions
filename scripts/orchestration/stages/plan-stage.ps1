<#
.SYNOPSIS
    Produces planning artifacts for the multi-agent orchestration pipeline.

.DESCRIPTION
    Reads the user request and writes:
    - task-plan markdown artifact
    - context-pack json artifact
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
    Path to input artifact manifest (not required in this stage).

.PARAMETER OutputArtifactManifestPath
    Path where this stage writes its output artifact manifest.

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/orchestration/stages/plan-stage.ps1 -RepoRoot . -RunDirectory .temp/runs/run-1 -TraceId run-1 -StageId plan -AgentId planner -RequestPath .temp/runs/run-1/artifacts/request.md -OutputArtifactManifestPath .temp/runs/run-1/stages/plan-output.json

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
    [string] $InputArtifactManifestPath,
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
$resolvedInputManifestPath = if ([string]::IsNullOrWhiteSpace($InputArtifactManifestPath)) { $null } else { [System.IO.Path]::GetFullPath($InputArtifactManifestPath) }
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null

$requestContent = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}

$requestPreview = $requestContent
if ($requestPreview.Length -gt 600) {
    $requestPreview = $requestPreview.Substring(0, 600) + '...'
}

$taskPlanPath = Join-Path $stageArtifactsDirectory 'task-plan.md'
$contextPackPath = Join-Path $stageArtifactsDirectory 'context-pack.json'

$taskPlanContent = @(
    ('# Task Plan ({0})' -f $TraceId),
    '',
    ('- Stage: {0}' -f $StageId),
    ('- Agent: {0}' -f $AgentId),
    ('- GeneratedAt: {0}' -f (Get-Date).ToString('o')),
    '',
    '## Objective',
    '- Deliver the requested change with deterministic validation.',
    '',
    '## Steps',
    '1. Load mandatory context and selected domain instructions.',
    '2. Implement minimal safe changes aligned with repository standards.',
    '3. Run validations and tests before review handoff.',
    '',
    '## Request Snapshot',
    $requestPreview
) -join "`n"

Set-Content -LiteralPath $taskPlanPath -Value $taskPlanContent -Encoding UTF8 -NoNewline

$contextPack = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    generatedAt = (Get-Date).ToString('o')
    mandatoryContext = @(
        '.github/AGENTS.md',
        '.github/copilot-instructions.md'
    )
    requestPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedRequestPath
    inputArtifactManifestPath = if ($null -eq $resolvedInputManifestPath) { $null } else { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedInputManifestPath }
    notes = @(
        'Route before execute using instruction-routing catalog.',
        'Keep context minimal and deterministic.'
    )
}

Set-Content -LiteralPath $contextPackPath -Value ($contextPack | ConvertTo-Json -Depth 30) -Encoding UTF8 -NoNewline

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
        (Get-ArtifactDescriptor -Name 'task-plan' -Path $taskPlanPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'context-pack' -Path $contextPackPath -Root $resolvedRepoRoot)
    )
}

Set-Content -LiteralPath $resolvedOutputManifestPath -Value ($outputManifest | ConvertTo-Json -Depth 40) -Encoding UTF8 -NoNewline

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)
exit 0