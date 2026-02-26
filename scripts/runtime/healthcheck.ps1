<#
.SYNOPSIS
    Runs end-to-end health checks for the repository instruction and runtime system.

.DESCRIPTION
    Executes core validation checks and produces:
    - console summary
    - structured JSON report
    - plain-text execution log

    Checks:
    - scripts/validation/validate-instructions.ps1
    - scripts/validation/validate-readme-standards.ps1
    - scripts/validation/validate-powershell-standards.ps1
    - scripts/validation/validate-dotnet-standards.ps1
    - scripts/validation/validate-architecture-boundaries.ps1
    - scripts/validation/validate-instruction-metadata.ps1
    - scripts/validation/validate-routing-coverage.ps1
    - scripts/validation/validate-agent-skill-alignment.ps1
    - scripts/validation/validate-policy.ps1
    - scripts/validation/validate-security-baseline.ps1
    - scripts/validation/validate-agent-orchestration.ps1
    - scripts/validation/validate-release-governance.ps1
    - scripts/validation/validate-release-provenance.ps1
    - scripts/runtime/doctor.ps1

    Optional:
    - scripts/runtime/bootstrap.ps1 (when -SyncRuntime is used)

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER TargetGithubPath
    Runtime target path for .github assets. Defaults to $env:USERPROFILE\.github.

.PARAMETER TargetCodexPath
    Runtime target path for .codex assets. Defaults to $env:USERPROFILE\.codex.

.PARAMETER SyncRuntime
    Runs bootstrap sync before health checks.

.PARAMETER Mirror
    Uses mirror mode when -SyncRuntime is enabled.

.PARAMETER StrictExtras
    Fails runtime doctor when extra files exist in runtime targets.

.PARAMETER OutputPath
    Path for JSON healthcheck report. Defaults to .temp/healthcheck-report.json.

.PARAMETER LogPath
    Path for text execution log. Defaults to .temp/logs/healthcheck-<timestamp>.log.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1 -SyncRuntime -Mirror -StrictExtras

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1 -TargetGithubPath ./.temp/runtime/github -TargetCodexPath ./.temp/runtime/codex -SyncRuntime

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath = "$env:USERPROFILE\.github",
    [string] $TargetCodexPath = "$env:USERPROFILE\.codex",
    [switch] $SyncRuntime,
    [switch] $Mirror,
    [switch] $StrictExtras,
    [string] $OutputPath = '.temp/healthcheck-report.json',
    [string] $LogPath,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:LogFilePath = $null
$script:IsVerboseEnabled = [bool] $Verbose

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE:{0}] {1}" -f $Color, $Message)
    }
}

# Builds an absolute path from repository root and relative input path.
function Resolve-RepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

# Resolves the repository root using explicit and fallback location candidates.
function Resolve-RepositoryRoot {
    param(
        [string] $RequestedRoot
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $RequestedRoot).Path
        }
        catch {
            throw "Invalid RepoRoot path: $RequestedRoot"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ScriptRoot)) {
        $candidates += (Resolve-Path -LiteralPath (Join-Path $script:ScriptRoot '..\..')).Path
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $i++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Returns the parent directory for a given file path when available.
function Get-ParentDirectoryPath {
    param(
        [string] $Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) { return $null }
    return $parent
}

# Writes execution log entries to console output and optional log file.
function Write-ExecutionLog {
    param(
        [string] $Level,
        [string] $Message
    )

    $timestamp = (Get-Date).ToString('o')
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    if ($null -ne $script:LogFilePath) {
        Add-Content -LiteralPath $script:LogFilePath -Value $line
    }

    Write-Output $line
}

# Runs a validation script check and captures status and execution metrics.
function Invoke-ScriptCheck {
    param(
        [string] $Name,
        [string] $ScriptPath,
        [hashtable] $Arguments
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        $errorMessage = "Script not found: $ScriptPath"
        Write-ExecutionLog -Level 'ERROR' -Message ("{0}: {1}" -f $Name, $errorMessage)
    }
    else {
        Write-ExecutionLog -Level 'INFO' -Message ("Starting check: {0}" -f $Name)

        try {
            & $ScriptPath @Arguments
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            if ($exitCode -eq 0) {
                $status = 'passed'
                Write-ExecutionLog -Level 'OK' -Message ("Check passed: {0}" -f $Name)
            }
            else {
                Write-ExecutionLog -Level 'ERROR' -Message ("Check failed: {0} (exit code {1})" -f $Name, $exitCode)
            }
        }
        catch {
            $exitCode = 1
            $errorMessage = $_.Exception.Message
            Write-ExecutionLog -Level 'ERROR' -Message ("Check exception: {0} :: {1}" -f $Name, $errorMessage)
        }
    }

    $finishedAt = Get-Date
    $durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
    $relativeScriptPath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $ScriptPath)
    $argumentList = @()
    foreach ($entry in ($Arguments.GetEnumerator() | Sort-Object Name)) {
        $argumentList += ("-{0}={1}" -f $entry.Key, $entry.Value)
    }

    return [pscustomobject]@{
        name = $Name
        script = $relativeScriptPath
        arguments = $argumentList
        status = $status
        exitCode = $exitCode
        durationMs = $durationMs
        startedAt = $startedAt.ToString('o')
        finishedAt = $finishedAt.ToString('o')
        error = $errorMessage
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
$resolvedOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $OutputPath
$resolvedTargetGithubPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $TargetGithubPath
$resolvedTargetCodexPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $TargetCodexPath

$resolvedLogPath = if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $timestampToken = Get-Date -Format 'yyyyMMdd-HHmmss'
    Resolve-RepoPath -Root $resolvedRepoRoot -Path (".temp/logs/healthcheck-{0}.log" -f $timestampToken)
}
else {
    Resolve-RepoPath -Root $resolvedRepoRoot -Path $LogPath
}

$outputParent = Get-ParentDirectoryPath -Path $resolvedOutputPath
if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
    New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}

$logParent = Get-ParentDirectoryPath -Path $resolvedLogPath
if (-not [string]::IsNullOrWhiteSpace($logParent)) {
    New-Item -ItemType Directory -Path $logParent -Force | Out-Null
}
Set-Content -LiteralPath $resolvedLogPath -Value ("# healthcheck log`n# generatedAt={0}" -f (Get-Date).ToString('o'))
$script:LogFilePath = $resolvedLogPath

Write-ExecutionLog -Level 'INFO' -Message ("Repo root: {0}" -f $resolvedRepoRoot)
Write-ExecutionLog -Level 'INFO' -Message ("Output report: {0}" -f $resolvedOutputPath)
Write-ExecutionLog -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$checks = New-Object System.Collections.Generic.List[object]

$bootstrapScript = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'
$validateInstructionsScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-instructions.ps1'
$validateReadmeStandardsScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-readme-standards.ps1'
$validatePowershellStandardsScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-powershell-standards.ps1'
$validateDotnetStandardsScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-dotnet-standards.ps1'
$validateArchitectureBoundariesScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-architecture-boundaries.ps1'
$validateInstructionMetadataScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-instruction-metadata.ps1'
$validateRoutingCoverageScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-routing-coverage.ps1'
$validateAgentSkillAlignmentScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-agent-skill-alignment.ps1'
$validatePolicyScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-policy.ps1'
$validateSecurityBaselineScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-security-baseline.ps1'
$validateAgentOrchestrationScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-agent-orchestration.ps1'
$validateReleaseGovernanceScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-release-governance.ps1'
$validateReleaseProvenanceScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-release-provenance.ps1'
$doctorScript = Join-Path $resolvedRepoRoot 'scripts/runtime/doctor.ps1'

if ($SyncRuntime) {
    $bootstrapArgs = @{
        RepoRoot = $resolvedRepoRoot
        TargetGithubPath = $resolvedTargetGithubPath
        TargetCodexPath = $resolvedTargetCodexPath
    }
    if ($Mirror) {
        $bootstrapArgs.Mirror = $true
    }

    $checks.Add((Invoke-ScriptCheck -Name 'runtime-bootstrap' -ScriptPath $bootstrapScript -Arguments $bootstrapArgs)) | Out-Null
}

$checks.Add((Invoke-ScriptCheck -Name 'validate-instructions' -ScriptPath $validateInstructionsScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-readme-standards' -ScriptPath $validateReadmeStandardsScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-powershell-standards' -ScriptPath $validatePowershellStandardsScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-dotnet-standards' -ScriptPath $validateDotnetStandardsScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-architecture-boundaries' -ScriptPath $validateArchitectureBoundariesScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-instruction-metadata' -ScriptPath $validateInstructionMetadataScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-routing-coverage' -ScriptPath $validateRoutingCoverageScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-agent-skill-alignment' -ScriptPath $validateAgentSkillAlignmentScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-policy' -ScriptPath $validatePolicyScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-security-baseline' -ScriptPath $validateSecurityBaselineScript -Arguments @{
    RepoRoot = $resolvedRepoRoot
    WarningOnly = $true
})) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-agent-orchestration' -ScriptPath $validateAgentOrchestrationScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-release-governance' -ScriptPath $validateReleaseGovernanceScript -Arguments @{ RepoRoot = $resolvedRepoRoot })) | Out-Null
$checks.Add((Invoke-ScriptCheck -Name 'validate-release-provenance' -ScriptPath $validateReleaseProvenanceScript -Arguments @{
    RepoRoot = $resolvedRepoRoot
    WarningOnly = $true
})) | Out-Null

$doctorArgs = @{
    RepoRoot = $resolvedRepoRoot
    TargetGithubPath = $resolvedTargetGithubPath
    TargetCodexPath = $resolvedTargetCodexPath
}
if ($StrictExtras) {
    $doctorArgs.StrictExtras = $true
}

$checks.Add((Invoke-ScriptCheck -Name 'runtime-doctor' -ScriptPath $doctorScript -Arguments $doctorArgs)) | Out-Null

$passedChecks = @($checks | Where-Object { $_.status -eq 'passed' }).Count
$failedChecks = @($checks | Where-Object { $_.status -ne 'passed' }).Count
$overallStatus = if ($failedChecks -eq 0) { 'passed' } else { 'failed' }

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    repoRoot = $resolvedRepoRoot
    targets = [ordered]@{
        github = $resolvedTargetGithubPath
        codex = $resolvedTargetCodexPath
    }
    options = [ordered]@{
        syncRuntime = [bool] $SyncRuntime
        mirror = [bool] $Mirror
        strictExtras = [bool] $StrictExtras
    }
    summary = [ordered]@{
        totalChecks = $checks.Count
        passedChecks = $passedChecks
        failedChecks = $failedChecks
        overallStatus = $overallStatus
    }
    checks = $checks.ToArray()
    logPath = $resolvedLogPath
}

$reportJson = $report | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $resolvedOutputPath -Value $reportJson

Write-ExecutionLog -Level 'INFO' -Message ("Healthcheck summary: total={0} passed={1} failed={2}" -f $checks.Count, $passedChecks, $failedChecks)
Write-ExecutionLog -Level 'INFO' -Message ("Healthcheck report generated: {0}" -f $resolvedOutputPath)

if ($overallStatus -ne 'passed') {
    exit 1
}

exit 0