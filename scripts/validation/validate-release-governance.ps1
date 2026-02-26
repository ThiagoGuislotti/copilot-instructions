<#
.SYNOPSIS
    Validates release governance contracts (CODEOWNERS, CHANGELOG, and branch protection baseline).

.DESCRIPTION
    Enforces local release-governance requirements without automating pull requests or merges:
    - required governance files exist
    - CODEOWNERS has baseline ownership rules
    - CHANGELOG follows semantic version/date entry format
    - branch protection baseline JSON is structurally valid

    Exit code:
    - 0 when validation passes (warnings allowed)
    - 1 when any required contract fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER ChangelogPath
    Path to changelog file. Defaults to `CHANGELOG.md`.

.PARAMETER CodeownersPath
    Path to CODEOWNERS file. Defaults to `CODEOWNERS`.

.PARAMETER GovernanceDocPath
    Path to release governance documentation. Defaults to `.github/governance/release-governance.md`.

.PARAMETER BranchProtectionBaselinePath
    Path to branch protection baseline JSON. Defaults to `.github/governance/branch-protection.baseline.json`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-release-governance.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ChangelogPath = 'CHANGELOG.md',
    [string] $CodeownersPath = 'CODEOWNERS',
    [string] $GovernanceDocPath = '.github/governance/release-governance.md',
    [string] $BranchProtectionBaselinePath = '.github/governance/branch-protection.baseline.json',
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
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

# Registers a validation failure and prints a standardized failure message.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-Output ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning and prints a standardized warning message.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-Output ("[WARN] {0}" -f $Message)
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

# Extracts semantic version entries and dates from changelog content.
function Get-ChangelogEntryList {
    param(
        [string] $Content
    )

    $pattern = '(?m)^\s{0,3}(?:#{1,6}\s*)?\[(?<version>\d+\.\d+\.\d+)\]\s*-\s*(?<date>\d{4}-\d{2}-\d{2})\s*$'
    $entryMatches = [System.Text.RegularExpressions.Regex]::Matches($Content, $pattern)
    $entries = New-Object System.Collections.Generic.List[object]

    foreach ($match in $entryMatches) {
        $entryDate = [datetime]::MinValue
        $isDateValid = [datetime]::TryParseExact(
            $match.Groups['date'].Value,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref] $entryDate
        )

        if (-not $isDateValid) {
            Add-ValidationFailure ("Invalid changelog date '{0}' for version {1}" -f $match.Groups['date'].Value, $match.Groups['version'].Value)
            continue
        }

        $entries.Add([pscustomobject]@{
            version = $match.Groups['version'].Value
            dateToken = $match.Groups['date'].Value
            date = $entryDate
        }) | Out-Null
    }

    return $entries
}

# Validates changelog structure and chronological ordering of release entries.
function Test-Changelog {
    param(
        [string] $Path
    )

    $content = Get-Content -Raw -LiteralPath $Path
    $entries = Get-ChangelogEntryList -Content $content

    if ($entries.Count -eq 0) {
        Add-ValidationFailure 'CHANGELOG does not contain entries in format [X.Y.Z] - YYYY-MM-DD.'
        return $null
    }

    for ($index = 1; $index -lt $entries.Count; $index++) {
        if ($entries[$index].date -gt $entries[$index - 1].date) {
            Add-ValidationFailure ("CHANGELOG date order invalid: {0} appears after newer entry {1}." -f $entries[$index].dateToken, $entries[$index - 1].dateToken)
            break
        }
    }

    Write-VerboseColor ("Latest changelog version: {0}" -f $entries[0].version) 'Green'
    return $entries[0].version
}

# Validates required CODEOWNERS rules for repository governance paths.
function Test-CodeownerFile {
    param(
        [string] $Path
    )

    $rawLines = @(Get-Content -LiteralPath $Path)
    $activeLines = @(
        $rawLines |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith('#') }
    )

    if ($activeLines.Count -eq 0) {
        Add-ValidationFailure 'CODEOWNERS has no active rules.'
        return
    }

    if (-not ($activeLines | Where-Object { $_ -match '^\*\s+@' })) {
        Add-ValidationFailure 'CODEOWNERS must define a catch-all owner rule: "* @owner".'
    }

    $requiredPaths = @('.github/', '.githooks/', 'scripts/')
    foreach ($requiredPath in $requiredPaths) {
        $pathPattern = '^{0}\s+@' -f [regex]::Escape($requiredPath)
        if (-not ($activeLines | Where-Object { $_ -match $pathPattern })) {
            Add-ValidationFailure ("CODEOWNERS missing required ownership rule for '{0}'." -f $requiredPath)
        }
    }
}

# Validates required section headers in the release governance document.
function Test-GovernanceDocument {
    param(
        [string] $Path
    )

    $content = Get-Content -Raw -LiteralPath $Path
    $requiredSections = @(
        '^## Scope',
        '^## Branch Protection',
        '^## CODEOWNERS',
        '^## Release Checklist',
        '^## Rollback'
    )

    foreach ($sectionPattern in $requiredSections) {
        if ($content -notmatch "(?m)$sectionPattern") {
            Add-ValidationFailure ("Release governance doc missing section matching '{0}'." -f $sectionPattern)
        }
    }
}

# Validates required contracts in branch-protection baseline JSON.
function Test-BranchProtectionBaseline {
    param(
        [string] $Path
    )

    $baseline = $null
    try {
        $baseline = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in branch protection baseline: {0}" -f $_.Exception.Message)
        return
    }

    if ([string]::IsNullOrWhiteSpace([string] $baseline.repository) -or [string] $baseline.repository -notmatch '^[^/]+/[^/]+$') {
        Add-ValidationFailure 'branch-protection.baseline.json must include repository in owner/name format.'
    }

    if ([string]::IsNullOrWhiteSpace([string] $baseline.branch)) {
        Add-ValidationFailure 'branch-protection.baseline.json must include a target branch.'
    }

    if ($null -eq $baseline.protection) {
        Add-ValidationFailure 'branch-protection.baseline.json must include a protection object.'
        return
    }

    $statusChecks = $baseline.protection.required_status_checks
    if ($null -eq $statusChecks) {
        Add-ValidationFailure 'Branch protection baseline must define required_status_checks.'
    }
    else {
        $contexts = @($statusChecks.contexts)
        if ($contexts.Count -eq 0) {
            Add-ValidationFailure 'Branch protection baseline must define at least one required status check context.'
        }
        if (-not [bool] $statusChecks.strict) {
            Add-ValidationWarning 'Branch protection baseline has strict=false (recommended strict=true).'
        }
    }

    if (-not [bool] $baseline.protection.enforce_admins) {
        Add-ValidationWarning 'Branch protection baseline has enforce_admins=false (recommended true).'
    }

    $reviews = $baseline.protection.required_pull_request_reviews
    if ($null -eq $reviews) {
        Add-ValidationFailure 'Branch protection baseline must define required_pull_request_reviews.'
    }
    else {
        if (-not [bool] $reviews.require_code_owner_reviews) {
            Add-ValidationFailure 'Branch protection baseline must set require_code_owner_reviews=true.'
        }

        if ([int] $reviews.required_approving_review_count -lt 1) {
            Add-ValidationFailure 'Branch protection baseline must require at least 1 approving review.'
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedChangelogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ChangelogPath
$resolvedCodeownersPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $CodeownersPath
$resolvedGovernanceDocPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $GovernanceDocPath
$resolvedBranchProtectionBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BranchProtectionBaselinePath

$requiredFiles = @(
    $resolvedChangelogPath,
    $resolvedCodeownersPath,
    $resolvedGovernanceDocPath,
    $resolvedBranchProtectionBaselinePath
)

foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        Add-ValidationFailure ("Required file not found: {0}" -f [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $requiredFile))
    }
}

if (Test-Path -LiteralPath $resolvedChangelogPath -PathType Leaf) {
    [void](Test-Changelog -Path $resolvedChangelogPath)
}

if (Test-Path -LiteralPath $resolvedCodeownersPath -PathType Leaf) {
    Test-CodeownerFile -Path $resolvedCodeownersPath
}

if (Test-Path -LiteralPath $resolvedGovernanceDocPath -PathType Leaf) {
    Test-GovernanceDocument -Path $resolvedGovernanceDocPath
}

if (Test-Path -LiteralPath $resolvedBranchProtectionBaselinePath -PathType Leaf) {
    Test-BranchProtectionBaseline -Path $resolvedBranchProtectionBaselinePath
}

Write-Output ''
Write-Output 'Release governance validation summary'
Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Output ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-Output 'Release governance validation passed.'
exit 0