<#
.SYNOPSIS
    Validates README files against repository baseline standards.

.DESCRIPTION
    Loads `.github/governance/readme-standards.baseline.json` and validates README
    files for required sections and formatting contracts.

    Checks include:
    - Required section headers
    - Features section checkmark bullets
    - Markdown code fences
    - Table-of-contents anchor links
    - Horizontal separators
    - Optional introduction preamble behavior per file

    Exit code:
    - 0 when all validations pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Baseline JSON path. Defaults to `.github/governance/readme-standards.baseline.json`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-readme-standards.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-readme-standards.ps1 -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/readme-standards.baseline.json',
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
Initialize-ValidationState -VerboseEnabled $script:IsVerboseEnabled

# -------------------------------
# Helpers
# -------------------------------

# Resolves a path from repo root.

# Resolves repository root from input and fallbacks.

# Normalizes heading text for consistent matching.
function Convert-HeadingToKey {
    param(
        [string] $Heading
    )

    if ($null -eq $Heading) {
        return ''
    }

    return ($Heading -replace '\s+', ' ').Trim().ToLowerInvariant()
}

# Returns unique heading keys extracted from markdown content.
function Get-HeadingKeyList {
    param(
        [string] $Content
    )

    $headingMatches = [regex]::Matches($Content, '(?m)^#{1,6}\s+(?<title>[^\r\n#]+?)\s*$')
    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($match in $headingMatches) {
        $headingKey = Convert-HeadingToKey -Heading $match.Groups['title'].Value
        if (-not [string]::IsNullOrWhiteSpace($headingKey)) {
            $set.Add($headingKey) | Out-Null
        }
    }

    return $set
}

# Converts null/scalar/arrays to string arrays.
function Convert-ToStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return ,@()
    }

    if ($Value -is [string]) {
        return ,@([string] $Value)
    }

    return ,@($Value | ForEach-Object { [string] $_ })
}

# Extracts a section body by heading alternatives.
function Get-SectionBody {
    param(
        [string] $Content,
        [string[]] $HeadingOptions
    )

    foreach ($headingOption in $HeadingOptions) {
        $escaped = [regex]::Escape($headingOption.Trim())
        $pattern = "(?ims)^##\s+{0}\s*$\r?\n(?<body>.*?)(?=^##\s+|\z)" -f $escaped
        $match = [regex]::Match($Content, $pattern)
        if ($match.Success) {
            return $match.Groups['body'].Value
        }
    }

    return $null
}

# Validates required section list for a README file.
function Test-RequiredSectionSet {
    param(
        [string] $FilePath,
        [System.Collections.Generic.HashSet[string]] $HeadingKeys,
        [string[]] $RequiredSections
    )

    foreach ($requiredSection in $RequiredSections) {
        $alternatives = @(
            ($requiredSection -split '\|' |
                ForEach-Object { Convert-HeadingToKey -Heading $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        )

        if ($alternatives.Count -eq 0) {
            Add-ValidationWarning ("Invalid requiredSections entry in baseline for {0}: '{1}'" -f $FilePath, $requiredSection)
            continue
        }

        $isPresent = $false
        foreach ($candidate in $alternatives) {
            if ($HeadingKeys.Contains($candidate)) {
                $isPresent = $true
                break
            }
        }

        if (-not $isPresent) {
            Add-ValidationFailure ("Missing required section '{0}' in {1}" -f $requiredSection, $FilePath)
        }
    }
}

# Validates optional introduction preamble behavior.
function Test-IntroductionPreamble {
    param(
        [string] $FilePath,
        [string] $Content,
        [bool] $AllowIntroductionPreamble
    )

    if ($AllowIntroductionPreamble) {
        return
    }

    $firstContentLine = $null
    foreach ($line in ($Content -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $firstContentLine = $line.Trim()
            break
        }
    }

    if ($null -eq $firstContentLine) {
        Add-ValidationFailure ("README file is empty: {0}" -f $FilePath)
        return
    }

    if ($firstContentLine -notmatch '^#\s+') {
        Add-ValidationFailure ("README must start with heading when preamble is disabled: {0}" -f $FilePath)
    }
}

# Runs global markdown checks for the README content.
function Test-GlobalFormattingRuleSet {
    param(
        [string] $FilePath,
        [string] $Content,
        [hashtable] $GlobalRules,
        [System.Collections.Generic.HashSet[string]] $HeadingKeys
    )

    if ([bool] $GlobalRules.requireCodeFences) {
        $fenceCount = [regex]::Matches($Content, '```').Count
        if ($fenceCount -lt 2) {
            Add-ValidationFailure ("README must include at least one fenced code block: {0}" -f $FilePath)
        }
    }

    if ([bool] $GlobalRules.requireHorizontalSeparators) {
        $separatorCount = [regex]::Matches($Content, '(?m)^\s*---\s*$').Count
        if ($separatorCount -lt 1) {
            Add-ValidationFailure ("README must include at least one horizontal separator (---): {0}" -f $FilePath)
        }
    }

    if ([bool] $GlobalRules.requireFeaturesCheckmarks) {
        $featureHeadings = @('Features')
        $featureHeadingPresent = $false
        foreach ($featureHeading in $featureHeadings) {
            if ($HeadingKeys.Contains((Convert-HeadingToKey -Heading $featureHeading))) {
                $featureHeadingPresent = $true
                break
            }
        }

        if ($featureHeadingPresent) {
            $featureBody = Get-SectionBody -Content $Content -HeadingOptions $featureHeadings
            if ($null -eq $featureBody -or $featureBody -notmatch '(?m)^\s*[-*]\s+\u2705\s+') {
                Add-ValidationFailure ("Features section must include checkmark bullet items: {0}" -f $FilePath)
            }
        }
    }

    if ([bool] $GlobalRules.requireTocLinks) {
        $tocHeadings = @('Table of Contents', 'Contents')
        $tocBody = Get-SectionBody -Content $Content -HeadingOptions $tocHeadings
        if ($null -eq $tocBody) {
            Add-ValidationFailure ("README must include Table of Contents/Contents section: {0}" -f $FilePath)
        }
        elseif ($tocBody -notmatch '(?m)^\s*[-*]\s+\[[^\]]+\]\(#.+\)') {
            Add-ValidationFailure ("Table of Contents must include markdown anchor links: {0}" -f $FilePath)
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
    Add-ValidationFailure ("Baseline file not found: {0}" -f $BaselinePath)
    Write-StyledOutput ''
    Write-StyledOutput 'README standards validation summary'
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
    Write-StyledOutput 'README standards validation summary'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

if ($null -eq $baseline.global) {
    Add-ValidationFailure ("Baseline missing 'global' section: {0}" -f $BaselinePath)
}

$fileEntries = @($baseline.files)
if ($fileEntries.Count -eq 0) {
    Add-ValidationFailure ("Baseline must define at least one file entry: {0}" -f $BaselinePath)
}

$filesChecked = 0
foreach ($fileEntry in $fileEntries) {
    $relativePath = [string] $fileEntry.path
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        Add-ValidationFailure ("Baseline has file entry with empty path: {0}" -f $BaselinePath)
        continue
    }

    $resolvedFilePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $relativePath
    if (-not (Test-Path -LiteralPath $resolvedFilePath -PathType Leaf)) {
        Add-ValidationFailure ("README file not found: {0}" -f $relativePath)
        continue
    }

    $filesChecked++
    $content = Get-Content -Raw -LiteralPath $resolvedFilePath
    $headingKeys = Get-HeadingKeyList -Content $content
    $requiredSections = Convert-ToStringArray -Value $fileEntry.requiredSections
    $allowIntroductionPreamble = [bool] $fileEntry.allowIntroductionPreamble

    Test-RequiredSectionSet -FilePath $relativePath -HeadingKeys $headingKeys -RequiredSections $requiredSections
    Test-IntroductionPreamble -FilePath $relativePath -Content $content -AllowIntroductionPreamble $allowIntroductionPreamble

    $globalRules = @{
        requireFeaturesCheckmarks = [bool] $baseline.global.requireFeaturesCheckmarks
        requireCodeFences = [bool] $baseline.global.requireCodeFences
        requireTocLinks = [bool] $baseline.global.requireTocLinks
        requireHorizontalSeparators = [bool] $baseline.global.requireHorizontalSeparators
    }

    Test-GlobalFormattingRuleSet -FilePath $relativePath -Content $content -GlobalRules $globalRules -HeadingKeys $headingKeys
    Write-VerboseLog ("Validated README: {0}" -f $relativePath)
}

Write-StyledOutput ''
Write-StyledOutput 'README standards validation summary'
Write-StyledOutput ("  Files checked: {0}" -f $filesChecked)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'README standards validation passed.'
exit 0