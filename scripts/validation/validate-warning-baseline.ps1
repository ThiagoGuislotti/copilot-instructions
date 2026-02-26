<#
.SYNOPSIS
    Validates current PowerShell analyzer warning volume against governance baseline.

.DESCRIPTION
    Runs PSScriptAnalyzer warning scan for repository scripts and compares counts
    against `.github/governance/warning-baseline.json`.

    Checks include:
    - total warnings cap
    - per-rule warning cap
    - report export under `.temp/audit/`

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when enforcing mode is enabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Warning baseline JSON path relative to repository root.

.PARAMETER WarningOnly
    When true (default), findings are emitted as warnings and do not fail execution.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-warning-baseline.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-warning-baseline.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, PSScriptAnalyzer module for full behavior.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/warning-baseline.json',
    [bool] $WarningOnly = $true,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    if ($script:IsWarningOnly) {
        $script:Warnings.Add($Message) | Out-Null
        Write-Output ("[WARN] {0}" -f $Message)
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-Output ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-Output ("[WARN] {0}" -f $Message)
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

# Reads and parses a required JSON document.
function Get-RequiredJsonDocument {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in {0}: {1}" -f $Label, $_.Exception.Message)
        return $null
    }
}

# Converts absolute path to repository-relative path.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return ([System.IO.Path]::GetRelativePath($Root, $Path)).Replace('\', '/')
}

# Converts warning records to a grouped count map.
function Get-WarningCountMap {
    param(
        [object[]] $WarningResults
    )

    $map = @{}
    foreach ($result in $WarningResults) {
        $ruleName = [string] $result.RuleName
        if ([string]::IsNullOrWhiteSpace($ruleName)) {
            $ruleName = 'UnknownRule'
        }

        if (-not $map.ContainsKey($ruleName)) {
            $map[$ruleName] = 0
        }

        $map[$ruleName] = [int] $map[$ruleName] + 1
    }

    return $map
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$baseline = Get-RequiredJsonDocument -Path $resolvedBaselinePath -Label 'warning baseline'
if ($null -eq $baseline) {
    Write-Output ''
    Write-Output 'Warning baseline validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Total warnings: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$analyzerCommand = Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
if ($null -eq $analyzerCommand) {
    Add-ValidationWarning 'PSScriptAnalyzer not found; warning baseline check skipped.'
    Write-Output ''
    Write-Output 'Warning baseline validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Total warnings: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    exit 0
}

$scanRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path ([string] $baseline.scanRoot)
if (-not (Test-Path -LiteralPath $scanRoot -PathType Container)) {
    Add-ValidationFailure ("scanRoot not found in warning baseline: {0}" -f [string] $baseline.scanRoot)
    Write-Output ''
    Write-Output 'Warning baseline validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Total warnings: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$warningResults = @()
try {
    $warningResults = @(Invoke-ScriptAnalyzer -Path $scanRoot -Recurse -Severity Warning)
}
catch {
    Add-ValidationWarning ("PSScriptAnalyzer execution failed: {0}" -f $_.Exception.Message)
}

$warningCountMap = Get-WarningCountMap -WarningResults $warningResults
$totalWarnings = $warningResults.Count
$maxTotalWarnings = [int] $baseline.maxTotalWarnings
if ($totalWarnings -gt $maxTotalWarnings) {
    Add-ValidationFailure ("Total analyzer warnings ({0}) exceed baseline maxTotalWarnings ({1})." -f $totalWarnings, $maxTotalWarnings)
}

$maxByRule = $baseline.maxWarningsByRule
$knownRuleSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($property in $maxByRule.PSObject.Properties) {
    $ruleName = [string] $property.Name
    $threshold = [int] $property.Value
    $knownRuleSet.Add($ruleName) | Out-Null

    $count = if ($warningCountMap.ContainsKey($ruleName)) { [int] $warningCountMap[$ruleName] } else { 0 }
    if ($count -gt $threshold) {
        Add-ValidationFailure ("Analyzer warning count for '{0}' ({1}) exceeds threshold ({2})." -f $ruleName, $count, $threshold)
    }
}

foreach ($detectedRule in ($warningCountMap.Keys | Sort-Object)) {
    if (-not $knownRuleSet.Contains($detectedRule)) {
        Add-ValidationWarning ("Analyzer reported rule not present in baseline thresholds: {0} ({1})" -f $detectedRule, $warningCountMap[$detectedRule])
    }
}

$reportPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/audit/warning-baseline-report.json'
$reportParent = Split-Path -Path $reportPath -Parent
if (-not [string]::IsNullOrWhiteSpace($reportParent)) {
    New-Item -ItemType Directory -Path $reportParent -Force | Out-Null
}

$ruleBreakdown = @()
foreach ($detectedRule in ($warningCountMap.Keys | Sort-Object)) {
    $ruleBreakdown += [pscustomobject]@{
        rule = $detectedRule
        count = [int] $warningCountMap[$detectedRule]
    }
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    scanRoot = Convert-ToRelativePath -Root $resolvedRepoRoot -Path $scanRoot
    totalWarnings = $totalWarnings
    maxTotalWarnings = $maxTotalWarnings
    warningByRule = $ruleBreakdown
}
Set-Content -LiteralPath $reportPath -Value ($report | ConvertTo-Json -Depth 100)

Write-Output ''
Write-Output 'Warning baseline validation summary'
Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-Output ("  Total warnings: {0}" -f $totalWarnings)
Write-Output ("  Report path: {0}" -f (Convert-ToRelativePath -Root $resolvedRepoRoot -Path $reportPath))
Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Output ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

Write-Output 'Warning baseline validation passed.'
exit 0