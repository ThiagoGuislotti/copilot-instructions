<#
.SYNOPSIS
    Exports a consolidated audit report for the agent instruction/runtime system.

.DESCRIPTION
    Runs runtime healthcheck, collects repository metadata, and writes a
    structured JSON audit report that can be archived locally or in CI.

    The report includes:
    - healthcheck result and checks
    - git metadata (branch, commit, dirty state)
    - policy file inventory
    - execution log path

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
    Path for JSON audit report. Defaults to .temp/audit-report.json.

.PARAMETER HealthcheckOutputPath
    Path for intermediate healthcheck JSON report.

.PARAMETER LogPath
    Path for text execution log. Defaults to .temp/logs/audit-report-<timestamp>.log.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/export-audit-report.ps1

.EXAMPLE
    pwsh -File scripts/validation/export-audit-report.ps1 -SyncRuntime -Mirror -StrictExtras

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
    [string] $OutputPath = '.temp/audit-report.json',
    [string] $HealthcheckOutputPath = '.temp/healthcheck-report.json',
    [string] $LogPath,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:LogFilePath = $null

# -------------------------------
# Helpers
# -------------------------------
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($Verbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

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

function Set-CorrectWorkingDirectory {
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
                Set-Location -Path $current
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

function Ensure-ParentDirectory {
    param(
        [string] $Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return
    }

    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

function Write-Log {
    param(
        [string] $Level,
        [string] $Message
    )

    $timestamp = (Get-Date).ToString('o')
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    if ($null -ne $script:LogFilePath) {
        Add-Content -LiteralPath $script:LogFilePath -Value $line
    }

    $color = 'Gray'
    if ($Level -eq 'ERROR') { $color = 'Red' }
    elseif ($Level -eq 'WARN') { $color = 'Yellow' }
    elseif ($Level -eq 'OK') { $color = 'Green' }
    elseif ($Level -eq 'INFO') { $color = 'Cyan' }

    Write-Host $line -ForegroundColor $color
}

function Get-GitMetadata {
    param(
        [string] $Root
    )

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        return [ordered]@{
            available = $false
            branch = $null
            commit = $null
            isDirty = $null
        }
    }

    $branch = (& git -C $Root rev-parse --abbrev-ref HEAD 2>$null)
    $commit = (& git -C $Root rev-parse HEAD 2>$null)
    $statusLines = (& git -C $Root status --porcelain 2>$null)
    $isDirty = -not [string]::IsNullOrWhiteSpace(($statusLines -join ''))

    return [ordered]@{
        available = $true
        branch = if ([string]::IsNullOrWhiteSpace($branch)) { $null } else { $branch }
        commit = if ([string]::IsNullOrWhiteSpace($commit)) { $null } else { $commit }
        isDirty = $isDirty
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot
$resolvedOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $OutputPath
$resolvedHealthcheckOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $HealthcheckOutputPath

$resolvedLogPath = if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $timestampToken = Get-Date -Format 'yyyyMMdd-HHmmss'
    Resolve-RepoPath -Root $resolvedRepoRoot -Path (".temp/logs/audit-report-{0}.log" -f $timestampToken)
}
else {
    Resolve-RepoPath -Root $resolvedRepoRoot -Path $LogPath
}

Ensure-ParentDirectory -Path $resolvedOutputPath
Ensure-ParentDirectory -Path $resolvedHealthcheckOutputPath
Ensure-ParentDirectory -Path $resolvedLogPath
Set-Content -LiteralPath $resolvedLogPath -Value ("# audit-report log`n# generatedAt={0}" -f (Get-Date).ToString('o'))
$script:LogFilePath = $resolvedLogPath

Write-Log -Level 'INFO' -Message ("Repo root: {0}" -f $resolvedRepoRoot)
Write-Log -Level 'INFO' -Message ("Audit report output: {0}" -f $resolvedOutputPath)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$healthcheckScript = Join-Path $resolvedRepoRoot 'scripts/runtime/healthcheck.ps1'
$healthcheckLogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/logs/healthcheck-from-audit.log'
$healthcheckArgs = @{
    RepoRoot = $resolvedRepoRoot
    TargetGithubPath = $TargetGithubPath
    TargetCodexPath = $TargetCodexPath
    OutputPath = $resolvedHealthcheckOutputPath
    LogPath = $healthcheckLogPath
}
if ($SyncRuntime) {
    $healthcheckArgs.SyncRuntime = $true
}
if ($Mirror) {
    $healthcheckArgs.Mirror = $true
}
if ($StrictExtras) {
    $healthcheckArgs.StrictExtras = $true
}

$healthcheckExitCode = 1
try {
    Write-Log -Level 'INFO' -Message 'Executing runtime healthcheck for audit baseline.'
    & $healthcheckScript @healthcheckArgs
    $healthcheckExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
}
catch {
    $healthcheckExitCode = 1
    Write-Log -Level 'ERROR' -Message ("Healthcheck execution exception: {0}" -f $_.Exception.Message)
}

$healthcheckReport = $null
if (Test-Path -LiteralPath $resolvedHealthcheckOutputPath -PathType Leaf) {
    try {
        $healthcheckReport = Get-Content -Raw -LiteralPath $resolvedHealthcheckOutputPath | ConvertFrom-Json -Depth 100
        Write-Log -Level 'OK' -Message 'Loaded healthcheck report.'
    }
    catch {
        Write-Log -Level 'ERROR' -Message ("Could not parse healthcheck report JSON: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-Log -Level 'ERROR' -Message ("Healthcheck report not found: {0}" -f $resolvedHealthcheckOutputPath)
}

$policyDirectory = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/policies'
$policyFiles = @()
if (Test-Path -LiteralPath $policyDirectory -PathType Container) {
    $policyFiles = @(Get-ChildItem -LiteralPath $policyDirectory -File -Filter '*.json' | ForEach-Object {
        [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $_.FullName)
    })
}

$gitMetadata = Get-GitMetadata -Root $resolvedRepoRoot
$overallStatus = if ($healthcheckExitCode -eq 0) { 'passed' } else { 'failed' }

$auditReport = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    repoRoot = $resolvedRepoRoot
    targets = [ordered]@{
        github = $TargetGithubPath
        codex = $TargetCodexPath
    }
    options = [ordered]@{
        syncRuntime = [bool] $SyncRuntime
        mirror = [bool] $Mirror
        strictExtras = [bool] $StrictExtras
    }
    git = $gitMetadata
    policyFiles = $policyFiles
    healthcheck = $healthcheckReport
    summary = [ordered]@{
        overallStatus = $overallStatus
        healthcheckExitCode = $healthcheckExitCode
    }
    artifacts = [ordered]@{
        auditReportPath = $resolvedOutputPath
        healthcheckReportPath = $resolvedHealthcheckOutputPath
        auditLogPath = $resolvedLogPath
        healthcheckLogPath = $healthcheckLogPath
    }
}

$auditJson = $auditReport | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $resolvedOutputPath -Value $auditJson
Write-Log -Level 'INFO' -Message ("Audit report generated: {0}" -f $resolvedOutputPath)

if ($overallStatus -ne 'passed') {
    exit 1
}

exit 0