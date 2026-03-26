<#
.SYNOPSIS
    Runs end-to-end health checks for repository validation and runtime drift.

.DESCRIPTION
    Executes:
    - optional runtime bootstrap sync
    - validation suite (`scripts/validation/validate-all.ps1`)
    - runtime drift doctor (`scripts/runtime/doctor.ps1`)

    Produces:
    - console summary
    - structured JSON report
    - plain-text execution log

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when warning-only is disabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER TargetGithubPath
    Runtime target path for .github assets. Defaults to <user-home>/.github.

.PARAMETER TargetCodexPath
    Runtime target path for .codex assets. Defaults to <user-home>/.codex.

.PARAMETER SyncRuntime
    Runs bootstrap sync before health checks.

.PARAMETER Mirror
    Uses mirror mode when -SyncRuntime is enabled.

.PARAMETER StrictExtras
    Passes -StrictExtras to runtime doctor.

.PARAMETER ValidationProfile
    Validation profile id used by validate-all.

.PARAMETER WarningOnly
    Global warning-only mode. Default true.

.PARAMETER TreatRuntimeDriftAsWarning
    Converts runtime doctor non-zero exit to warning. Default true.

.PARAMETER OutputPath
    Path for JSON healthcheck report. Defaults to .temp/healthcheck-report.json.

.PARAMETER LogPath
    Path for text execution log. Defaults to .temp/logs/healthcheck-<timestamp>.log.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1 -SyncRuntime -Mirror -ValidationProfile release

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1 -WarningOnly:$false -TreatRuntimeDriftAsWarning:$false

.NOTES
    Version: 2.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath,
    [string] $TargetCodexPath,
    [switch] $SyncRuntime,
    [switch] $Mirror,
    [switch] $StrictExtras,
    [string] $ValidationProfile = 'dev',
    [bool] $WarningOnly = $true,
    [bool] $TreatRuntimeDriftAsWarning = $true,
    [string] $OutputPath = '.temp/healthcheck-report.json',
    [string] $LogPath,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:RuntimePathsPath = Join-Path $PSScriptRoot '..\common\runtime-paths.ps1'
if (-not (Test-Path -LiteralPath $script:RuntimePathsPath -PathType Leaf)) {
    $script:RuntimePathsPath = Join-Path $PSScriptRoot '..\..\common\runtime-paths.ps1'
}
if (Test-Path -LiteralPath $script:RuntimePathsPath -PathType Leaf) {
    . $script:RuntimePathsPath
}
else {
    throw "Missing shared runtime path helper: $script:RuntimePathsPath"
}
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:LogFilePath = $null
$script:IsVerboseEnabled = [bool] $Verbose

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Resolves a path from repo root.
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

# Resolves repository root from input and fallback candidates.
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
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
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

    Write-StyledOutput $line
}

# Runs a script check and captures status and execution metrics.
function Invoke-ScriptCheck {
    param(
        [string] $Name,
        [string] $ScriptPath,
        [hashtable] $Arguments,
        [bool] $TreatFailureAsWarning
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        $errorMessage = "Script not found: $ScriptPath"
        if ($TreatFailureAsWarning) {
            $status = 'warning'
            $exitCode = 0
            Write-ExecutionLog -Level 'WARN' -Message ("{0}: {1}" -f $Name, $errorMessage)
        }
        else {
            Write-ExecutionLog -Level 'ERROR' -Message ("{0}: {1}" -f $Name, $errorMessage)
        }
    }
    else {
        Write-ExecutionLog -Level 'INFO' -Message ("Starting check: {0}" -f $Name)
        try {
            & $ScriptPath @Arguments | Out-Host
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }

            if ($exitCode -eq 0) {
                $status = 'passed'
                Write-ExecutionLog -Level 'OK' -Message ("Check passed: {0}" -f $Name)
            }
            elseif ($TreatFailureAsWarning) {
                $status = 'warning'
                $exitCode = 0
                Write-ExecutionLog -Level 'WARN' -Message ("Check warning: {0} (non-zero exit converted to warning)" -f $Name)
            }
            else {
                $status = 'failed'
                Write-ExecutionLog -Level 'ERROR' -Message ("Check failed: {0} (exit code {1})" -f $Name, $exitCode)
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($TreatFailureAsWarning) {
                $status = 'warning'
                $exitCode = 0
                Write-ExecutionLog -Level 'WARN' -Message ("Check warning: {0} (exception converted to warning: {1})" -f $Name, $errorMessage)
            }
            else {
                $status = 'failed'
                $exitCode = 1
                Write-ExecutionLog -Level 'ERROR' -Message ("Check exception: {0} :: {1}" -f $Name, $errorMessage)
            }
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

$userHome = Resolve-UserHomePath
if ([string]::IsNullOrWhiteSpace($TargetGithubPath)) {
    $TargetGithubPath = Join-Path $userHome '.github'
}
if ([string]::IsNullOrWhiteSpace($TargetCodexPath)) {
    $TargetCodexPath = Join-Path $userHome '.codex'
}

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
Write-ExecutionLog -Level 'INFO' -Message ("Validation profile: {0}" -f $ValidationProfile)
Write-ExecutionLog -Level 'INFO' -Message ("Warning-only mode: {0}" -f $WarningOnly)
Write-ExecutionLog -Level 'INFO' -Message ("Output report: {0}" -f $resolvedOutputPath)
Write-ExecutionLog -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$checks = New-Object System.Collections.Generic.List[object]

$bootstrapScript = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'
$validateAllScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-all.ps1'
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

    $bootstrapCheck = @(Invoke-ScriptCheck -Name 'runtime-bootstrap' -ScriptPath $bootstrapScript -Arguments $bootstrapArgs -TreatFailureAsWarning:$WarningOnly) | Select-Object -Last 1
    if ($null -ne $bootstrapCheck) {
        $checks.Add($bootstrapCheck) | Out-Null
    }
}

$validateAllArgs = @{
    RepoRoot = $resolvedRepoRoot
    ValidationProfile = $ValidationProfile
    WarningOnly = $WarningOnly
}
$validateAllCheck = @(Invoke-ScriptCheck -Name 'validate-all' -ScriptPath $validateAllScript -Arguments $validateAllArgs -TreatFailureAsWarning:$WarningOnly) | Select-Object -Last 1
if ($null -ne $validateAllCheck) {
    $checks.Add($validateAllCheck) | Out-Null
}

$doctorArgs = @{
    RepoRoot = $resolvedRepoRoot
    TargetGithubPath = $resolvedTargetGithubPath
    TargetCodexPath = $resolvedTargetCodexPath
}
if ($StrictExtras) {
    $doctorArgs.StrictExtras = $true
}

$doctorAsWarning = [bool] ($WarningOnly -or $TreatRuntimeDriftAsWarning)
$doctorCheck = @(Invoke-ScriptCheck -Name 'runtime-doctor' -ScriptPath $doctorScript -Arguments $doctorArgs -TreatFailureAsWarning:$doctorAsWarning) | Select-Object -Last 1
if ($null -ne $doctorCheck) {
    $checks.Add($doctorCheck) | Out-Null
}

$passedChecks = @($checks | Where-Object { $_.status -eq 'passed' }).Count
$warningChecks = @($checks | Where-Object { $_.status -eq 'warning' }).Count
$failedChecks = @($checks | Where-Object { $_.status -eq 'failed' }).Count

$overallStatus = if ($failedChecks -gt 0) {
    'failed'
}
elseif ($warningChecks -gt 0) {
    'warning'
}
else {
    'passed'
}

$report = [ordered]@{
    schemaVersion = 2
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
        validationProfile = $ValidationProfile
        warningOnly = [bool] $WarningOnly
        treatRuntimeDriftAsWarning = [bool] $TreatRuntimeDriftAsWarning
    }
    summary = [ordered]@{
        totalChecks = $checks.Count
        passedChecks = $passedChecks
        warningChecks = $warningChecks
        failedChecks = $failedChecks
        overallStatus = $overallStatus
    }
    checks = $checks.ToArray()
    logPath = $resolvedLogPath
}

Set-Content -LiteralPath $resolvedOutputPath -Value ($report | ConvertTo-Json -Depth 100)
Write-ExecutionLog -Level 'INFO' -Message ("Healthcheck summary: total={0} passed={1} warning={2} failed={3}" -f $checks.Count, $passedChecks, $warningChecks, $failedChecks)
Write-ExecutionLog -Level 'INFO' -Message ("Healthcheck report generated: {0}" -f $resolvedOutputPath)

if ($failedChecks -gt 0 -and -not $WarningOnly) {
    exit 1
}

exit 0