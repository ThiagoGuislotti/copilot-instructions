<#
.SYNOPSIS
    Validates architecture boundary contracts based on a governance baseline.

.DESCRIPTION
    Loads `.github/governance/architecture-boundaries.baseline.json` and enforces
    boundary rules against versioned files.

    Rule model:
    - files: file paths and/or wildcard patterns
    - requiredPatterns: regex patterns that must be present
    - forbiddenPatterns: regex patterns that must be absent
    - allowedPatterns: optional regex exceptions for forbidden matches
    - severity: failure or warning

    Exit code:
    - 0 when all failure-level checks pass
    - 1 when any failure-level check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Baseline JSON path. Defaults to `.github/governance/architecture-boundaries.baseline.json`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-architecture-boundaries.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/architecture-boundaries.baseline.json',
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
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:FileChecks = 0

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
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

# Resolves repository root from input and fallbacks.
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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Converts absolute path into repository-relative path with slash separators.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return ([System.IO.Path]::GetRelativePath($Root, $Path)).Replace('\', '/')
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

# Returns repository files used for rule wildcard matching.
function Get-RepositoryFileList {
    param(
        [string] $Root
    )

    $result = New-Object System.Collections.Generic.List[object]

    Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]'
    } | ForEach-Object {
        $result.Add([pscustomobject]@{
            absolutePath = $_.FullName
            relativePath = Convert-ToRelativePath -Root $Root -Path $_.FullName
        }) | Out-Null
    }

    return $result
}

# Indicates whether a path pattern contains wildcard characters.
function Test-PatternWildcard {
    param(
        [string] $Pattern
    )

    return ($Pattern -match '[\*\?\[]')
}

# Resolves baseline file patterns into concrete repository file paths.
function Get-RuleFileMatchList {
    param(
        [string] $Root,
        [object[]] $RepositoryFiles,
        [string[]] $RuleFilePatterns,
        [string] $RuleId
    )

    $fileSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($pattern in $RuleFilePatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        $normalizedPattern = $pattern.Replace('\', '/')
        if (Test-PatternWildcard -Pattern $normalizedPattern) {
            $matchedAny = $false
            foreach ($file in $RepositoryFiles) {
                if ($file.relativePath -like $normalizedPattern) {
                    $fileSet.Add($file.absolutePath) | Out-Null
                    $matchedAny = $true
                }
            }

            if (-not $matchedAny) {
                Add-ValidationWarning ("Boundary rule '{0}' pattern matched no files: {1}" -f $RuleId, $pattern)
            }
            continue
        }

        $absolutePath = Resolve-RepoPath -Root $Root -Path $pattern
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            Add-ValidationWarning ("Boundary rule '{0}' references missing file: {1}" -f $RuleId, $pattern)
            continue
        }

        $fileSet.Add($absolutePath) | Out-Null
    }

    return @($fileSet)
}

# Returns line number from content index for diagnostics.
function Get-LineNumberFromIndex {
    param(
        [string] $Content,
        [int] $Index
    )

    if ($Index -lt 0) {
        return 0
    }

    $prefix = $Content.Substring(0, [Math]::Min($Index, $Content.Length))
    return ([regex]::Matches($prefix, "`r?`n").Count + 1)
}

# Registers a rule finding with severity mapping.
function Add-RuleIssue {
    param(
        [string] $Severity,
        [string] $Message
    )

    if ($Severity -eq 'warning') {
        Add-ValidationWarning -Message $Message
        return
    }

    Add-ValidationFailure -Message $Message
}

# Executes one boundary rule against matched files.
function Test-BoundaryRule {
    param(
        [string] $Root,
        [object] $Rule,
        [object[]] $RepositoryFiles
    )

    $ruleId = [string] $Rule.id
    if ([string]::IsNullOrWhiteSpace($ruleId)) {
        $ruleId = 'unnamed-rule'
    }

    $severity = ([string] $Rule.severity).Trim().ToLowerInvariant()
    if ($severity -ne 'warning') {
        $severity = 'failure'
    }

    $ruleFiles = Get-RuleFileMatchList -Root $Root -RepositoryFiles $RepositoryFiles -RuleFilePatterns (Convert-ToStringArray -Value $Rule.files) -RuleId $ruleId
    if ($ruleFiles.Count -eq 0) {
        Add-ValidationWarning ("Boundary rule '{0}' has no files to evaluate." -f $ruleId)
        return
    }

    $requiredPatterns = Convert-ToStringArray -Value $Rule.requiredPatterns
    $forbiddenPatterns = Convert-ToStringArray -Value $Rule.forbiddenPatterns
    $allowedPatterns = Convert-ToStringArray -Value $Rule.allowedPatterns

    foreach ($filePath in $ruleFiles) {
        $script:FileChecks++
        $relativePath = Convert-ToRelativePath -Root $Root -Path $filePath
        $content = Get-Content -Raw -LiteralPath $filePath

        foreach ($requiredPattern in $requiredPatterns) {
            if ([string]::IsNullOrWhiteSpace($requiredPattern)) {
                continue
            }

            if ($content -notmatch $requiredPattern) {
                Add-RuleIssue -Severity $severity -Message ("Boundary rule '{0}' missing required pattern in {1}: {2}" -f $ruleId, $relativePath, $requiredPattern)
            }
        }

        foreach ($forbiddenPattern in $forbiddenPatterns) {
            if ([string]::IsNullOrWhiteSpace($forbiddenPattern)) {
                continue
            }

            $regexMatches = [regex]::Matches($content, $forbiddenPattern)
            foreach ($match in $regexMatches) {
                $isAllowed = $false
                foreach ($allowedPattern in $allowedPatterns) {
                    if (-not [string]::IsNullOrWhiteSpace($allowedPattern) -and $match.Value -match $allowedPattern) {
                        $isAllowed = $true
                        break
                    }
                }

                if ($isAllowed) {
                    continue
                }

                $line = Get-LineNumberFromIndex -Content $content -Index $match.Index
                Add-RuleIssue -Severity $severity -Message ("Boundary rule '{0}' forbidden pattern in {1}:{2} :: {3}" -f $ruleId, $relativePath, $line, $forbiddenPattern)
            }
        }

        Write-VerboseLog ("Boundary rule '{0}' checked file: {1}" -f $ruleId, $relativePath)
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
if (-not (Test-Path -LiteralPath $resolvedBaselinePath -PathType Leaf)) {
    Add-ValidationFailure ("Baseline file not found: {0}" -f $BaselinePath)
    Write-StyledOutput ''
    Write-StyledOutput 'Architecture boundary validation summary'
    Write-StyledOutput ("  Rules checked: 0")
    Write-StyledOutput ("  File checks: 0")
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$baseline = $null
try {
    $baseline = Get-Content -Raw -LiteralPath $resolvedBaselinePath | ConvertFrom-Json -Depth 100
}
catch {
    Add-ValidationFailure ("Invalid JSON in baseline file {0}: {1}" -f $BaselinePath, $_.Exception.Message)
    Write-StyledOutput ''
    Write-StyledOutput 'Architecture boundary validation summary'
    Write-StyledOutput ("  Rules checked: 0")
    Write-StyledOutput ("  File checks: 0")
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$rules = @($baseline.rules)
if ($rules.Count -eq 0) {
    Add-ValidationFailure ("Baseline must include at least one rule: {0}" -f $BaselinePath)
}

$repositoryFiles = Get-RepositoryFileList -Root $resolvedRepoRoot

foreach ($rule in $rules) {
    Test-BoundaryRule -Root $resolvedRepoRoot -Rule $rule -RepositoryFiles $repositoryFiles
}

Write-StyledOutput ''
Write-StyledOutput 'Architecture boundary validation summary'
Write-StyledOutput ("  Rules checked: {0}" -f $rules.Count)
Write-StyledOutput ("  File checks: {0}" -f $script:FileChecks)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'Architecture boundary validation passed.'
exit 0