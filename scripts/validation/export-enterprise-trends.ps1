<#
.SYNOPSIS
    Exports enterprise validation and vulnerability trend metrics.

.DESCRIPTION
    Builds a consolidated trend snapshot from:
    - validation ledger (.temp/audit/validation-ledger.jsonl)
    - latest validate-all report (.temp/audit/validate-all.latest.json)
    - latest pre-build security gate summary (.temp/vulnerability-audit/prebuild-security-gate-summary.json)

    Generates:
    - JSON dashboard artifact
    - Markdown executive summary

    Exit code:
    - 0 when export succeeds (or warning-only mode handles missing inputs)
    - 1 when export fails and warning-only mode is disabled

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER LedgerPath
    Validation ledger path relative to repository root.

.PARAMETER ValidationReportPath
    Latest validation report path relative to repository root.

.PARAMETER VulnerabilitySummaryPath
    Latest vulnerability summary path relative to repository root.

.PARAMETER OutputPath
    JSON dashboard output path relative to repository root.

.PARAMETER SummaryPath
    Markdown summary output path relative to repository root.

.PARAMETER MaxEntries
    Maximum number of historical ledger entries included in trend history.

.PARAMETER WarningOnly
    Converts missing/invalid input conditions into warnings and exits successfully.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/export-enterprise-trends.ps1

.EXAMPLE
    pwsh -File scripts/validation/export-enterprise-trends.ps1 `
      -MaxEntries 50 `
      -WarningOnly:$true

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $LedgerPath = '.temp/audit/validation-ledger.jsonl',
    [string] $ValidationReportPath = '.temp/audit/validate-all.latest.json',
    [string] $VulnerabilitySummaryPath = '.temp/vulnerability-audit/prebuild-security-gate-summary.json',
    [string] $OutputPath = '.temp/audit/enterprise-trends.latest.json',
    [string] $SummaryPath = '.temp/audit/enterprise-trends.latest.md',
    [int] $MaxEntries = 30,
    [bool] $WarningOnly = $true,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param([string] $Message)

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers non-blocking warning.
function Add-ExportWarning {
    param([string] $Message)

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Resolves a path from repository root.
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
    param([string] $RequestedRoot)

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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Reads JSON file and returns null when missing or invalid.
function Read-JsonFileSafe {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ExportWarning ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ExportWarning ("Invalid JSON in {0}: {1}" -f $Label, $_.Exception.Message)
        return $null
    }
}

# Returns parsed validation ledger records with payload projection.
function Get-LedgerRecordList {
    param([string] $Path)

    $records = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ExportWarning ("Validation ledger not found: {0}" -f $Path)
        return @()
    }

    foreach ($line in (Get-Content -LiteralPath $Path)) {
        if ([string]::IsNullOrWhiteSpace([string] $line)) {
            continue
        }

        try {
            $entry = $line | ConvertFrom-Json -Depth 200
            $payload = $null
            if (-not [string]::IsNullOrWhiteSpace([string] $entry.payloadJson)) {
                $payload = [string] $entry.payloadJson | ConvertFrom-Json -Depth 200
            }

            $records.Add([pscustomobject]@{
                    generatedAt = [string] $entry.generatedAt
                    profile = [string] $entry.profile
                    warningOnly = [bool] $entry.warningOnly
                    payload = $payload
                }) | Out-Null
        }
        catch {
            Add-ExportWarning ("Skipped invalid ledger line: {0}" -f $_.Exception.Message)
        }
    }

    return @($records.ToArray())
}

# Sums check durations in payload.
function Get-TotalDurationFromPayload {
    param([object] $Payload)

    if ($null -eq $Payload -or $null -eq $Payload.checks) {
        return 0
    }

    $durationSum = 0
    foreach ($check in @($Payload.checks)) {
        if ($null -eq $check -or $null -eq $check.durationMs) {
            continue
        }

        $durationSum += [int] $check.durationMs
    }

    return [int] $durationSum
}

# Builds normalized trend history from parsed ledger records.
function Get-ValidationTrendEntryList {
    param(
        [object[]] $RecordList,
        [int] $Limit
    )

    if ($Limit -lt 1) {
        return @()
    }

    $ordered = @(
        $RecordList |
            Sort-Object -Property @{ Expression = {
                    try { [datetime] $_.generatedAt } catch { [datetime]::MinValue }
                }
            }
    )

    $selected = @($ordered | Select-Object -Last $Limit)
    return @($selected | ForEach-Object {
            $summary = if ($null -eq $_.payload) { $null } else { $_.payload.summary }
            [pscustomobject]@{
                generatedAt = $_.generatedAt
                profile = $_.profile
                warningOnly = $_.warningOnly
                totalChecks = if ($null -eq $summary) { 0 } else { [int] $summary.totalChecks }
                passed = if ($null -eq $summary) { 0 } else { [int] $summary.passed }
                warnings = if ($null -eq $summary) { 0 } else { [int] $summary.warnings }
                failed = if ($null -eq $summary) { 0 } else { [int] $summary.failed }
                totalDurationMs = [int] (Get-TotalDurationFromPayload -Payload $_.payload)
            }
        })
}

# Returns normalized vulnerability summary payload.
function Get-VulnerabilitySnapshot {
    param([object] $SummaryPayload)

    if ($null -eq $SummaryPayload) {
        return [ordered]@{
            available = $false
            overallStatus = 'unknown'
            warningOnly = $null
            auditRuns = 0
            failedAudits = 0
            failures = 0
            warnings = 0
        }
    }

    $auditRuns = @($SummaryPayload.auditRuns)
    $failedAudits = @($auditRuns | Where-Object { [string] $_.status -eq 'FAIL' }).Count

    return [ordered]@{
        available = $true
        overallStatus = [string] $SummaryPayload.overallStatus
        warningOnly = [bool] $SummaryPayload.warningOnly
        auditRuns = $auditRuns.Count
        failedAudits = $failedAudits
        failures = @($SummaryPayload.failures).Count
        warnings = @($SummaryPayload.warnings).Count
    }
}

# Writes markdown summary for quick inspection.
function Write-SummaryMarkdown {
    param(
        [string] $Path,
        [hashtable] $Dashboard
    )

    $validationSummary = $Dashboard.current.validation
    $vulnerabilitySummary = $Dashboard.current.vulnerability
    $kpis = $Dashboard.kpis

    $lines = @(
        '# Enterprise Trends Snapshot',
        '',
        "- Generated At (UTC): $($Dashboard.generatedAt)",
        "- Profile: $($validationSummary.profile)",
        '',
        '## Validation',
        "- Total Checks: $($validationSummary.totalChecks)",
        "- Passed: $($validationSummary.passed)",
        "- Warnings: $($validationSummary.warnings)",
        "- Failed: $($validationSummary.failed)",
        "- Suite Warnings: $($validationSummary.suiteWarnings)",
        "- Total Duration (ms): $($validationSummary.totalDurationMs)",
        "- Average Check Duration (ms): $($validationSummary.averageCheckDurationMs)",
        '',
        '## Vulnerability Snapshot',
        "- Available: $($vulnerabilitySummary.available)",
        "- Overall Status: $($vulnerabilitySummary.overallStatus)",
        "- Audit Runs: $($vulnerabilitySummary.auditRuns)",
        "- Failed Audits: $($vulnerabilitySummary.failedAudits)",
        "- Failures: $($vulnerabilitySummary.failures)",
        "- Warnings: $($vulnerabilitySummary.warnings)",
        '',
        '## KPIs',
        "- Validation Warning Rate (%): $($kpis.validationWarningRatePercent)",
        "- Validation Failure Rate (%): $($kpis.validationFailureRatePercent)",
        "- Average Duration Last N (ms): $($kpis.averageDurationMsLastN)",
        "- Trend Entries Considered: $($kpis.historyEntries)"
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

try {
    $resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
    Set-Location -Path $resolvedRepoRoot

    $resolvedLedgerPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $LedgerPath
    $resolvedValidationReportPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ValidationReportPath
    $resolvedVulnerabilitySummaryPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $VulnerabilitySummaryPath
    $resolvedOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $OutputPath
    $resolvedSummaryPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $SummaryPath

    $validationReport = Read-JsonFileSafe -Path $resolvedValidationReportPath -Label 'validate-all report'
    $vulnerabilitySummaryPayload = Read-JsonFileSafe -Path $resolvedVulnerabilitySummaryPath -Label 'vulnerability summary'
    $ledgerRecords = @(Get-LedgerRecordList -Path $resolvedLedgerPath)
    $trendHistory = @(Get-ValidationTrendEntryList -RecordList $ledgerRecords -Limit $MaxEntries)

    $validationSummary = if ($null -eq $validationReport) {
        [ordered]@{
            profile = 'unknown'
            totalChecks = 0
            passed = 0
            warnings = 0
            failed = 0
            suiteWarnings = 0
            totalDurationMs = 0
            averageCheckDurationMs = 0
        }
    }
    else {
        [ordered]@{
            profile = [string] $validationReport.profile
            totalChecks = [int] $validationReport.summary.totalChecks
            passed = [int] $validationReport.summary.passed
            warnings = [int] $validationReport.summary.warnings
            failed = [int] $validationReport.summary.failed
            suiteWarnings = [int] $validationReport.summary.suiteWarnings
            totalDurationMs = [int] $validationReport.performance.totalDurationMs
            averageCheckDurationMs = [double] $validationReport.performance.averageCheckDurationMs
        }
    }

    $vulnerabilitySnapshot = Get-VulnerabilitySnapshot -SummaryPayload $vulnerabilitySummaryPayload

    $totalChecks = [double] $validationSummary.totalChecks
    $warningRate = if ($totalChecks -gt 0) { [math]::Round((100.0 * [double] $validationSummary.warnings) / $totalChecks, 2) } else { 0.0 }
    $failureRate = if ($totalChecks -gt 0) { [math]::Round((100.0 * [double] $validationSummary.failed) / $totalChecks, 2) } else { 0.0 }
    $avgDurationHistory = if ($trendHistory.Count -gt 0) {
        $historyDurationTotal = 0.0
        foreach ($historyEntry in $trendHistory) {
            $historyDurationTotal += [double] $historyEntry.totalDurationMs
        }

        [math]::Round(($historyDurationTotal / [double] $trendHistory.Count), 2)
    }
    else {
        0.0
    }

    $dashboard = [ordered]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        repoRoot = $resolvedRepoRoot
        inputs = [ordered]@{
            ledgerPath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedLedgerPath)
            validationReportPath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedValidationReportPath)
            vulnerabilitySummaryPath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedVulnerabilitySummaryPath)
        }
        current = [ordered]@{
            validation = $validationSummary
            vulnerability = $vulnerabilitySnapshot
        }
        trends = [ordered]@{
            validationHistory = $trendHistory
        }
        kpis = [ordered]@{
            validationWarningRatePercent = $warningRate
            validationFailureRatePercent = $failureRate
            averageDurationMsLastN = $avgDurationHistory
            historyEntries = $trendHistory.Count
        }
        warnings = @($script:Warnings.ToArray())
    }

    $outputParent = Split-Path -Path $resolvedOutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
    }

    $dashboard | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
    Write-SummaryMarkdown -Path $resolvedSummaryPath -Dashboard $dashboard

    Write-StyledOutput ("[OK] Enterprise trends JSON written: {0}" -f [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedOutputPath))
    Write-StyledOutput ("[OK] Enterprise trends summary written: {0}" -f [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedSummaryPath))
    Write-StyledOutput ("[INFO] Trend history entries: {0}" -f $trendHistory.Count)
    Write-StyledOutput ("[INFO] Warnings: {0}" -f $script:Warnings.Count)
    exit 0
}
catch {
    if ($WarningOnly) {
        Write-StyledOutput ("[WARN] export-enterprise-trends fallback: {0}" -f $_.Exception.Message)
        exit 0
    }

    Write-StyledOutput ("[FAIL] {0}" -f $_.Exception.Message)
    exit 1
}