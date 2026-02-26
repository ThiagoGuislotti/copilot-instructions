<#
.SYNOPSIS
    Validates repository security baseline contracts.

.DESCRIPTION
    Enforces local security governance declared in
    `.github/governance/security-baseline.json`.

    Checks include:
    - required files and directories
    - forbidden sensitive path patterns
    - forbidden secret-like content patterns on configured text extensions

    Exit code:
    - 0 when checks run in warning-only mode (default)
    - 1 when any required check fails in enforcing mode

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Security baseline JSON path relative to repository root.

.PARAMETER WarningOnly
    When true (default), validation findings are emitted as warnings and do not fail the script.
    Set to false to enforce blocking failures.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-security-baseline.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-security-baseline.ps1 -Verbose

.EXAMPLE
    pwsh -File scripts/validation/validate-security-baseline.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/security-baseline.json',
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

# Converts absolute path to repository-relative forward-slash format.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    $relative = [System.IO.Path]::GetRelativePath($Root, $Path)
    return $relative.Replace('\', '/')
}

# Converts glob syntax to a regex pattern.
function Convert-GlobToRegex {
    param(
        [string] $Glob
    )

    $normalized = $Glob.Replace('\', '/')
    $escaped = [System.Text.RegularExpressions.Regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return "^{0}$" -f $escaped
}

# Matches a relative path against one or more glob patterns.
function Test-PathGlobMatch {
    param(
        [string] $RelativePath,
        [string[]] $GlobPatterns
    )

    $normalized = $RelativePath.Replace('\', '/')
    foreach ($globPattern in $GlobPatterns) {
        if ([string]::IsNullOrWhiteSpace($globPattern)) {
            continue
        }

        $regexPattern = Convert-GlobToRegex -Glob $globPattern
        if ($normalized -match $regexPattern) {
            return $true
        }
    }

    return $false
}

# Validates required files from baseline.
function Test-RequiredFileSet {
    param(
        [string] $Root,
        [string[]] $RequiredFiles
    )

    foreach ($requiredFile in $RequiredFiles) {
        $absolutePath = Resolve-RepoPath -Root $Root -Path $requiredFile
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            Add-ValidationFailure ("Missing required file: {0}" -f $requiredFile)
        }
    }
}

# Validates required directories from baseline.
function Test-RequiredDirectorySet {
    param(
        [string] $Root,
        [string[]] $RequiredDirectories
    )

    foreach ($requiredDirectory in $RequiredDirectories) {
        $absolutePath = Resolve-RepoPath -Root $Root -Path $requiredDirectory
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Container)) {
            Add-ValidationFailure ("Missing required directory: {0}" -f $requiredDirectory)
        }
    }
}

# Returns repository file entries after glob-based exclusion.
function Get-RepositoryFileEntryList {
    param(
        [string] $Root,
        [string[]] $ExcludedPathGlobs
    )

    $results = New-Object System.Collections.Generic.List[object]
    $fileList = @(Get-ChildItem -LiteralPath $Root -Recurse -File)

    foreach ($fileInfo in $fileList) {
        $relativePath = Convert-ToRelativePath -Root $Root -Path $fileInfo.FullName
        if (Test-PathGlobMatch -RelativePath $relativePath -GlobPatterns $ExcludedPathGlobs) {
            continue
        }

        $results.Add([pscustomobject]@{
            fullPath = $fileInfo.FullName
            relativePath = $relativePath
            extension = [System.IO.Path]::GetExtension($fileInfo.FullName).ToLowerInvariant()
        }) | Out-Null
    }

    return @($results.ToArray())
}

# Validates forbidden path globs against repository file entries.
function Test-ForbiddenPathSet {
    param(
        [object[]] $FileEntries,
        [string[]] $ForbiddenPathGlobs
    )

    foreach ($fileEntry in $FileEntries) {
        if (Test-PathGlobMatch -RelativePath $fileEntry.relativePath -GlobPatterns $ForbiddenPathGlobs) {
            Add-ValidationFailure ("Forbidden sensitive file path found: {0}" -f $fileEntry.relativePath)
        }
    }
}

# Returns files that should be scanned for content checks.
function Get-ContentScanFileEntryList {
    param(
        [object[]] $FileEntries,
        [string[]] $ScanExtensions
    )

    $extensionSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $ScanExtensions) {
        if ([string]::IsNullOrWhiteSpace($extension)) {
            continue
        }

        if ($extension.StartsWith('.')) {
            $extensionSet.Add($extension) | Out-Null
        }
        else {
            $extensionSet.Add(".{0}" -f $extension) | Out-Null
        }
    }

    if ($extensionSet.Count -eq 0) {
        return @()
    }

    return @($FileEntries | Where-Object { $extensionSet.Contains([string] $_.extension) })
}

# Builds compiled regex rules for forbidden content checks.
function Get-ContentPatternRuleList {
    param(
        [object[]] $PatternObjects
    )

    $rules = New-Object System.Collections.Generic.List[object]

    foreach ($patternObject in $PatternObjects) {
        $patternId = [string] $patternObject.id
        $patternValue = [string] $patternObject.pattern
        $severity = ([string] $patternObject.severity).ToLowerInvariant()

        if ([string]::IsNullOrWhiteSpace($patternId)) {
            $patternId = 'unnamed-pattern'
        }

        if ([string]::IsNullOrWhiteSpace($patternValue)) {
            Add-ValidationFailure ("Security baseline pattern has empty regex: {0}" -f $patternId)
            continue
        }

        if ($severity -ne 'warning') {
            $severity = 'failure'
        }

        try {
            $regex = [System.Text.RegularExpressions.Regex]::new($patternValue, [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $rules.Add([pscustomobject]@{
                id = $patternId
                severity = $severity
                regex = $regex
            }) | Out-Null
        }
        catch {
            Add-ValidationFailure ("Invalid regex in security baseline pattern '{0}': {1}" -f $patternId, $_.Exception.Message)
        }
    }

    return @($rules.ToArray())
}

# Builds compiled regex list from simple string patterns.
function Get-RegexList {
    param(
        [string[]] $PatternList,
        [string] $Label
    )

    $regexList = New-Object System.Collections.Generic.List[System.Text.RegularExpressions.Regex]
    foreach ($patternValue in $PatternList) {
        if ([string]::IsNullOrWhiteSpace($patternValue)) {
            continue
        }

        try {
            $regexList.Add([System.Text.RegularExpressions.Regex]::new($patternValue, [System.Text.RegularExpressions.RegexOptions]::Multiline)) | Out-Null
        }
        catch {
            Add-ValidationFailure ("Invalid regex in {0}: {1}" -f $Label, $_.Exception.Message)
        }
    }

    return @($regexList.ToArray())
}

# Formats a regex match snippet for diagnostics.
function Get-MatchPreview {
    param(
        [string] $Value
    )

    $singleLine = $Value.Replace("`r", ' ').Replace("`n", ' ').Trim()
    if ($singleLine.Length -le 80) {
        return $singleLine
    }

    return "{0}..." -f $singleLine.Substring(0, 80)
}

# Validates forbidden content patterns in scan-eligible files.
function Test-ForbiddenContentSet {
    param(
        [object[]] $FileEntries,
        [object[]] $RuleList,
        [System.Text.RegularExpressions.Regex[]] $AllowedRegexList
    )

    foreach ($fileEntry in $FileEntries) {
        $content = $null
        try {
            $content = Get-Content -Raw -LiteralPath $fileEntry.fullPath
        }
        catch {
            Add-ValidationWarning ("Skipping unreadable file during content scan: {0}" -f $fileEntry.relativePath)
            continue
        }

        foreach ($rule in $RuleList) {
            $matchList = @($rule.regex.Matches($content))
            if ($matchList.Count -eq 0) {
                continue
            }

            foreach ($matchItem in $matchList) {
                $isAllowed = $false
                foreach ($allowedRegex in $AllowedRegexList) {
                    if ($allowedRegex.IsMatch([string] $matchItem.Value)) {
                        $isAllowed = $true
                        break
                    }
                }

                if ($isAllowed) {
                    continue
                }

                $preview = Get-MatchPreview -Value ([string] $matchItem.Value)
                $lineNumber = [int] ($content.Substring(0, $matchItem.Index) -split "`n").Count
                $message = ("{0}:{1} matched '{2}' -> {3}" -f $fileEntry.relativePath, $lineNumber, $rule.id, $preview)

                if ($rule.severity -eq 'warning') {
                    Add-ValidationWarning $message
                }
                else {
                    Add-ValidationFailure $message
                }

                break
            }
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
if (-not (Test-Path -LiteralPath $resolvedBaselinePath -PathType Leaf)) {
    Add-ValidationFailure ("Security baseline file not found: {0}" -f $BaselinePath)
    Write-Output ''
    Write-Output 'Security baseline validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Files scanned: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$baseline = $null
try {
    $baseline = Get-Content -Raw -LiteralPath $resolvedBaselinePath | ConvertFrom-Json -Depth 200
}
catch {
    Add-ValidationFailure ("Invalid JSON in security baseline file: {0}" -f $_.Exception.Message)
}

if ($script:Failures.Count -gt 0 -or $null -eq $baseline) {
    Write-Output ''
    Write-Output 'Security baseline validation summary'
    Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-Output '  Files scanned: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$requiredFiles = Convert-ToStringArray -Value $baseline.requiredFiles
$requiredDirectories = Convert-ToStringArray -Value $baseline.requiredDirectories
$scanExtensions = Convert-ToStringArray -Value $baseline.scanExtensions
$excludedPathGlobs = Convert-ToStringArray -Value $baseline.excludedPathGlobs
$forbiddenPathGlobs = Convert-ToStringArray -Value $baseline.forbiddenPathGlobs
$allowedContentPatterns = Convert-ToStringArray -Value $baseline.allowedContentPatterns
$forbiddenContentPatterns = @($baseline.forbiddenContentPatterns)

Test-RequiredFileSet -Root $resolvedRepoRoot -RequiredFiles $requiredFiles
Test-RequiredDirectorySet -Root $resolvedRepoRoot -RequiredDirectories $requiredDirectories

$repositoryFiles = Get-RepositoryFileEntryList -Root $resolvedRepoRoot -ExcludedPathGlobs $excludedPathGlobs
Write-VerboseLog ("Repository files evaluated after exclusions: {0}" -f $repositoryFiles.Count)

Test-ForbiddenPathSet -FileEntries $repositoryFiles -ForbiddenPathGlobs $forbiddenPathGlobs

$scanFiles = Get-ContentScanFileEntryList -FileEntries $repositoryFiles -ScanExtensions $scanExtensions
Write-VerboseLog ("Repository files selected for content scan: {0}" -f $scanFiles.Count)

$patternRules = Get-ContentPatternRuleList -PatternObjects $forbiddenContentPatterns
$allowedRegexRules = Get-RegexList -PatternList $allowedContentPatterns -Label 'allowedContentPatterns'

if ($patternRules.Count -eq 0) {
    Add-ValidationWarning 'No forbiddenContentPatterns configured in security baseline.'
}
else {
    Test-ForbiddenContentSet -FileEntries $scanFiles -RuleList $patternRules -AllowedRegexList $allowedRegexRules
}

Write-Output ''
Write-Output 'Security baseline validation summary'
Write-Output ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-Output ("  Files scanned: {0}" -f $scanFiles.Count)
Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Output ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

Write-Output 'Security baseline validation passed.'
exit 0