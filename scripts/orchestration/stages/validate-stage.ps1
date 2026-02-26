<#
.SYNOPSIS
    Executes repository validation checks and produces validation artifacts.

.DESCRIPTION
    Runs deterministic validation scripts and writes:
    - validation-report json artifact
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

# Runs a validation script and returns status metadata.
function Invoke-ValidationScript {
    param(
        [string] $Name,
        [string] $ScriptPath,
        [string] $Root
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    try {
        & $ScriptPath -RepoRoot $Root
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        if ($exitCode -eq 0) {
            $status = 'passed'
        }
    }
    catch {
        $exitCode = 1
        $errorMessage = $_.Exception.Message
    }

    $finishedAt = Get-Date

    return [ordered]@{
        name = $Name
        script = (Convert-ToRelativeRepoPath -Root $Root -Path $ScriptPath)
        status = $status
        exitCode = $exitCode
        startedAt = $startedAt.ToString('o')
        finishedAt = $finishedAt.ToString('o')
        durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
        error = $errorMessage
    }
}

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$resolvedRequestPath = [System.IO.Path]::GetFullPath($RequestPath)
$resolvedInputManifestPath = [System.IO.Path]::GetFullPath($InputArtifactManifestPath)
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null

$validationScripts = @(
    [ordered]@{ Name = 'validate-instructions'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-instructions.ps1') },
    [ordered]@{ Name = 'validate-policy'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-policy.ps1') },
    [ordered]@{ Name = 'validate-agent-orchestration'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-agent-orchestration.ps1') },
    [ordered]@{ Name = 'validate-release-governance'; Path = (Join-Path $resolvedRepoRoot 'scripts/validation/validate-release-governance.ps1') }
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($scriptEntry in $validationScripts) {
    if (-not (Test-Path -LiteralPath $scriptEntry.Path -PathType Leaf)) {
        $results.Add([ordered]@{
            name = $scriptEntry.Name
            script = (Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $scriptEntry.Path)
            status = 'failed'
            exitCode = 1
            startedAt = (Get-Date).ToString('o')
            finishedAt = (Get-Date).ToString('o')
            durationMs = 0
            error = 'Validation script not found.'
        }) | Out-Null
        continue
    }

    $results.Add((Invoke-ValidationScript -Name $scriptEntry.Name -ScriptPath $scriptEntry.Path -Root $resolvedRepoRoot)) | Out-Null
}

$failedChecks = @($results | Where-Object { $_.status -ne 'passed' }).Count
$inputArtifactCount = 0
if (Test-Path -LiteralPath $resolvedInputManifestPath -PathType Leaf) {
    $inputManifest = Get-Content -Raw -LiteralPath $resolvedInputManifestPath | ConvertFrom-Json -Depth 100
    $inputArtifactCount = @($inputManifest.artifacts).Count
}
$validationReportPath = Join-Path $stageArtifactsDirectory 'validation-report.json'

$validationReport = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    generatedAt = (Get-Date).ToString('o')
    summary = [ordered]@{
        totalChecks = $results.Count
        failedChecks = $failedChecks
        overallStatus = if ($failedChecks -eq 0) { 'passed' } else { 'failed' }
    }
    inputs = [ordered]@{
        requestPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedRequestPath
        inputArtifactManifestPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedInputManifestPath
        inputArtifactCount = $inputArtifactCount
    }
    checks = $results
}

Set-Content -LiteralPath $validationReportPath -Value ($validationReport | ConvertTo-Json -Depth 60) -Encoding UTF8 -NoNewline

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
        (Get-ArtifactDescriptor -Name 'validation-report' -Path $validationReportPath -Root $resolvedRepoRoot)
    )
}

Set-Content -LiteralPath $resolvedOutputManifestPath -Value ($outputManifest | ConvertTo-Json -Depth 40) -Encoding UTF8 -NoNewline

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)

if ($failedChecks -gt 0) {
    exit 1
}

exit 0