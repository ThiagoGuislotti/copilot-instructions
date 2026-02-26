<#
.SYNOPSIS
    Validates release provenance contracts for local governance.

.DESCRIPTION
    Enforces traceability controls declared in
    `.github/governance/release-provenance.baseline.json`.

    Checks include:
    - baseline JSON structure and required files
    - latest changelog release entry validity
    - required check names present in `validate-all`
    - evidence files existence and git traceability
    - optional audit report status and git commit alignment

    Exit code:
    - 0 when checks run in warning-only mode (default)
    - 1 when any required check fails in enforcing mode

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Release provenance baseline JSON path relative to repository root.

.PARAMETER AuditReportPath
    Optional audit report path used for provenance checks.

.PARAMETER RequireAuditReport
    Forces audit report validation even if baseline does not require it.

.PARAMETER WarningOnly
    When true (default), validation findings are emitted as warnings and do not fail the script.
    Set to false to enforce blocking failures.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-release-provenance.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-release-provenance.ps1 -RequireAuditReport

.EXAMPLE
    pwsh -File scripts/validation/validate-release-provenance.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/release-provenance.baseline.json',
    [string] $AuditReportPath = '.temp/audit-report.json',
    [switch] $RequireAuditReport,
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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Converts null/scalar/arrays to string arrays.
function Convert-ToStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @([string] $Value)
    }

    return @($Value | ForEach-Object { [string] $_ })
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

# Returns latest changelog entry using [X.Y.Z] - YYYY-MM-DD format.
function Get-ChangelogLatestEntry {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Changelog file not found: {0}" -f $Path)
        return $null
    }

    $content = Get-Content -Raw -LiteralPath $Path
    $pattern = '(?m)^\s{0,3}(?:#{1,6}\s*)?\[(?<version>\d+\.\d+\.\d+)\]\s*-\s*(?<date>\d{4}-\d{2}-\d{2})\s*$'
    $matchList = [System.Text.RegularExpressions.Regex]::Matches($content, $pattern)
    if ($matchList.Count -eq 0) {
        Add-ValidationFailure 'CHANGELOG has no entries matching [X.Y.Z] - YYYY-MM-DD.'
        return $null
    }

    $latestMatch = $matchList[0]
    $entryDate = [datetime]::MinValue
    $isDateValid = [datetime]::TryParseExact(
        $latestMatch.Groups['date'].Value,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref] $entryDate
    )

    if (-not $isDateValid) {
        Add-ValidationFailure ("Invalid latest changelog date: {0}" -f $latestMatch.Groups['date'].Value)
        return $null
    }

    if ($entryDate.Date -gt (Get-Date).Date) {
        Add-ValidationFailure ("Latest changelog date is in the future: {0}" -f $latestMatch.Groups['date'].Value)
    }

    return [pscustomobject]@{
        version = $latestMatch.Groups['version'].Value
        dateToken = $latestMatch.Groups['date'].Value
        date = $entryDate
    }
}

# Extracts check names from validate-all script definitions.
function Get-ValidationCheckNameList {
    param(
        [string] $ValidateAllScriptPath
    )

    if (-not (Test-Path -LiteralPath $ValidateAllScriptPath -PathType Leaf)) {
        Add-ValidationFailure ("validate-all script not found: {0}" -f $ValidateAllScriptPath)
        return @()
    }

    $rawContent = Get-Content -Raw -LiteralPath $ValidateAllScriptPath
    $nameMatches = [System.Text.RegularExpressions.Regex]::Matches($rawContent, "name\s*=\s*'(?<name>[^']+)'")
    $checkNameList = New-Object System.Collections.Generic.List[string]
    foreach ($nameMatch in $nameMatches) {
        $value = [string] $nameMatch.Groups['name'].Value
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $checkNameList.Add($value) | Out-Null
        }
    }

    return @($checkNameList | Select-Object -Unique)
}

# Validates required check names against validate-all entries.
function Test-ValidationCheckCoverage {
    param(
        [string[]] $RequiredCheckList,
        [string[]] $DefinedCheckList
    )

    $definedSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($checkName in $DefinedCheckList) {
        $definedSet.Add($checkName) | Out-Null
    }

    foreach ($requiredCheck in $RequiredCheckList) {
        if (-not $definedSet.Contains($requiredCheck)) {
            Add-ValidationFailure ("Required check missing from validate-all: {0}" -f $requiredCheck)
        }
    }
}

# Runs git command and returns exit code plus output lines.
function Invoke-GitCommand {
    param(
        [string] $Root,
        [string[]] $Arguments
    )

    $output = @(& git -C $Root @Arguments 2>$null)
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }

    return [pscustomobject]@{
        exitCode = $exitCode
        output = $output
    }
}

# Validates evidence file presence.
function Test-EvidenceFileSet {
    param(
        [string] $Root,
        [string[]] $EvidenceFileList
    )

    foreach ($evidenceFile in $EvidenceFileList) {
        $evidencePath = Resolve-RepoPath -Root $Root -Path $evidenceFile
        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
            Add-ValidationFailure ("Required evidence file not found: {0}" -f $evidenceFile)
        }
    }
}

# Validates git traceability for evidence files.
function Test-GitEvidenceTraceability {
    param(
        [string] $Root,
        [string[]] $EvidenceFileList,
        [bool] $AllowPendingChanges
    )

    foreach ($evidenceFile in $EvidenceFileList) {
        $trackedResult = Invoke-GitCommand -Root $Root -Arguments @('ls-files', '--error-unmatch', '--', $evidenceFile)
        if ($trackedResult.exitCode -ne 0) {
            if ($AllowPendingChanges) {
                Add-ValidationWarning ("Evidence file is not tracked by git yet (pending changes): {0}" -f $evidenceFile)
            }
            else {
                Add-ValidationFailure ("Evidence file is not tracked by git: {0}" -f $evidenceFile)
            }
            continue
        }

        $historyResult = Invoke-GitCommand -Root $Root -Arguments @('log', '-1', '--format=%H', '--', $evidenceFile)
        $lastCommit = [string] ($historyResult.output | Select-Object -First 1)
        if ($historyResult.exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($lastCommit)) {
            if ($AllowPendingChanges) {
                Add-ValidationWarning ("No committed history for evidence file yet (pending changes): {0}" -f $evidenceFile)
            }
            else {
                Add-ValidationFailure ("No git history found for evidence file: {0}" -f $evidenceFile)
            }
            continue
        }

        Write-VerboseLog ("Evidence trace {0}: {1}" -f $evidenceFile, $lastCommit)
    }
}

# Validates optional audit report content for provenance continuity.
function Test-AuditReportContract {
    param(
        [string] $AuditFilePath,
        [bool] $IsRequired,
        [string] $HeadCommit
    )

    if (-not (Test-Path -LiteralPath $AuditFilePath -PathType Leaf)) {
        if ($IsRequired) {
            Add-ValidationFailure ("Required audit report not found: {0}" -f $AuditFilePath)
        }
        else {
            Add-ValidationWarning ("Audit report not found (optional): {0}" -f $AuditFilePath)
        }

        return
    }

    $auditReport = $null
    try {
        $auditReport = Get-Content -Raw -LiteralPath $AuditFilePath | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in audit report: {0}" -f $_.Exception.Message)
        return
    }

    $overallStatus = [string] $auditReport.summary.overallStatus
    if ([string]::IsNullOrWhiteSpace($overallStatus)) {
        Add-ValidationFailure 'Audit report summary.overallStatus is missing.'
    }
    elseif ($overallStatus -ne 'passed') {
        Add-ValidationFailure ("Audit report overallStatus must be 'passed' but found '{0}'." -f $overallStatus)
    }

    $generatedAtToken = [string] $auditReport.generatedAt
    if (-not [string]::IsNullOrWhiteSpace($generatedAtToken)) {
        $generatedAt = [datetime]::MinValue
        if ([datetime]::TryParse($generatedAtToken, [ref] $generatedAt)) {
            if ($generatedAt -gt (Get-Date).ToUniversalTime().AddMinutes(1)) {
                Add-ValidationWarning ("Audit report generatedAt is in the future: {0}" -f $generatedAtToken)
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($HeadCommit)) {
        $auditCommit = [string] $auditReport.git.commit
        if (-not [string]::IsNullOrWhiteSpace($auditCommit) -and $auditCommit -ne $HeadCommit) {
            Add-ValidationWarning ("Audit report commit differs from HEAD (audit={0}, head={1})." -f $auditCommit, $HeadCommit)
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$baseline = Get-RequiredJsonDocument -Path $resolvedBaselinePath -Label 'release provenance baseline'

if ($null -eq $baseline) {
    Write-Output ''
    Write-Output 'Release provenance validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Checks declared: 0'
    Write-Output '  Evidence files: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$baselineVersion = [int] $baseline.version
if ($baselineVersion -lt 1) {
    Add-ValidationFailure 'release-provenance baseline version must be >= 1.'
}

$releaseBranch = [string] $baseline.releaseBranch
$requireCleanWorktree = [bool] $baseline.requireCleanWorktree
$baselineRequiresAuditReport = [bool] $baseline.requireAuditReport
$shouldRequireAuditReport = [bool] ($baselineRequiresAuditReport -or $RequireAuditReport)

$changelogPath = [string] $baseline.changelogPath
$validateAllPath = [string] $baseline.validateAllPath
$requiredValidationChecks = Convert-ToStringArray -Value $baseline.requiredValidationChecks
$requiredEvidenceFiles = Convert-ToStringArray -Value $baseline.requiredEvidenceFiles

if ([string]::IsNullOrWhiteSpace($changelogPath)) {
    Add-ValidationFailure 'release-provenance baseline must define changelogPath.'
}

if ([string]::IsNullOrWhiteSpace($validateAllPath)) {
    Add-ValidationFailure 'release-provenance baseline must define validateAllPath.'
}

if ($requiredValidationChecks.Count -eq 0) {
    Add-ValidationFailure 'release-provenance baseline must define at least one requiredValidationCheck.'
}

if ($requiredEvidenceFiles.Count -eq 0) {
    Add-ValidationFailure 'release-provenance baseline must define at least one requiredEvidenceFile.'
}

$resolvedChangelogPath = if ([string]::IsNullOrWhiteSpace($changelogPath)) { $null } else { Resolve-RepoPath -Root $resolvedRepoRoot -Path $changelogPath }
$resolvedValidateAllPath = if ([string]::IsNullOrWhiteSpace($validateAllPath)) { $null } else { Resolve-RepoPath -Root $resolvedRepoRoot -Path $validateAllPath }
$resolvedAuditReportPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AuditReportPath

$latestChangelogEntry = $null
if ($null -ne $resolvedChangelogPath) {
    $latestChangelogEntry = Get-ChangelogLatestEntry -Path $resolvedChangelogPath
}

if ($null -ne $latestChangelogEntry) {
    Write-VerboseLog ("Latest changelog entry: {0} ({1})" -f $latestChangelogEntry.version, $latestChangelogEntry.dateToken)
}

$definedChecks = @()
if ($null -ne $resolvedValidateAllPath) {
    $definedChecks = Get-ValidationCheckNameList -ValidateAllScriptPath $resolvedValidateAllPath
    Test-ValidationCheckCoverage -RequiredCheckList $requiredValidationChecks -DefinedCheckList $definedChecks
}

Test-EvidenceFileSet -Root $resolvedRepoRoot -EvidenceFileList $requiredEvidenceFiles

$gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
$headCommit = $null

if (-not $gitAvailable) {
    Add-ValidationWarning 'Git command not found; skipping git provenance checks.'
}
else {
    $branchResult = Invoke-GitCommand -Root $resolvedRepoRoot -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
    $currentBranch = [string] ($branchResult.output | Select-Object -First 1)
    if ($branchResult.exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($currentBranch)) {
        Add-ValidationFailure 'Could not resolve current git branch.'
    }
    elseif (-not [string]::IsNullOrWhiteSpace($releaseBranch) -and $currentBranch -ne $releaseBranch) {
        Add-ValidationWarning ("Current branch '{0}' differs from releaseBranch '{1}'." -f $currentBranch, $releaseBranch)
    }

    $headResult = Invoke-GitCommand -Root $resolvedRepoRoot -Arguments @('rev-parse', 'HEAD')
    $headCommit = [string] ($headResult.output | Select-Object -First 1)
    if ($headResult.exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($headCommit)) {
        Add-ValidationFailure 'Could not resolve HEAD commit hash.'
    }

    $statusResult = Invoke-GitCommand -Root $resolvedRepoRoot -Arguments @('status', '--porcelain')
    $isDirty = ($statusResult.exitCode -eq 0) -and (-not [string]::IsNullOrWhiteSpace(($statusResult.output -join '')))
    if ($isDirty -and $requireCleanWorktree) {
        Add-ValidationFailure 'Worktree is dirty and release-provenance baseline requires clean state.'
    }
    elseif ($isDirty) {
        Add-ValidationWarning 'Worktree is dirty; provenance checks usually run cleaner in committed state.'
    }

    Test-GitEvidenceTraceability -Root $resolvedRepoRoot -EvidenceFileList $requiredEvidenceFiles -AllowPendingChanges:$isDirty
}

Test-AuditReportContract -AuditFilePath $resolvedAuditReportPath -IsRequired:$shouldRequireAuditReport -HeadCommit $headCommit

Write-Output ''
Write-Output 'Release provenance validation summary'
Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-Output ("  Checks declared: {0}" -f $requiredValidationChecks.Count)
Write-Output ("  Checks found in validate-all: {0}" -f $definedChecks.Count)
Write-Output ("  Evidence files: {0}" -f $requiredEvidenceFiles.Count)
Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Output ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

Write-Output 'Release provenance validation passed.'
exit 0