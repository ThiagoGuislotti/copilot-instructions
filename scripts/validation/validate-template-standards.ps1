<#
.SYNOPSIS
    Validates shared template standards against the repository baseline.

.DESCRIPTION
    Loads `.github/governance/template-standards.baseline.json` and validates
    shared template assets under `.github/templates`.

    Checks include:
    - Required template files existence
    - Generic file hygiene for templates (non-empty content, no trailing whitespace)
    - Required and forbidden content patterns per template
    - Required repository path references used by templates

    Exit code:
    - 0 when all required checks pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Baseline JSON path. Defaults to `.github/governance/template-standards.baseline.json`.

.PARAMETER TemplateDirectory
    Template directory relative path. Defaults to `.github/templates`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-template-standards.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-template-standards.ps1 -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/template-standards.baseline.json',
    [string] $TemplateDirectory = '.github/templates',
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

# Resolves a path from repo root.

# Resolves repository root from input and fallbacks.

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

# Converts absolute path into relative display path when possible.
function Convert-ToDisplayPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    try {
        $relativePath = [System.IO.Path]::GetRelativePath($Root, $Path)
        if (-not $relativePath.StartsWith('..')) {
            return $relativePath
        }
    }
    catch {
        Write-VerboseLog ("Could not convert template path to repository-relative form: {0}" -f $Path)
    }

    return $Path
}

# Returns an object property value when present; otherwise null.
function Get-ObjectPropertyValue {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject -or [string]::IsNullOrWhiteSpace($PropertyName)) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Validates file content is not empty and has no trailing whitespace.
function Test-GenericTemplateFile {
    param(
        [string] $DisplayPath,
        [string] $Content,
        [string[]] $Lines
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        Add-ValidationFailure ("Template file is empty: {0}" -f $DisplayPath)
        return
    }

    $lineNumber = 0
    foreach ($line in $Lines) {
        $lineNumber++
        if ($line -match '\s+$') {
            Add-ValidationFailure ("Template contains trailing whitespace: {0}:{1}" -f $DisplayPath, $lineNumber)
        }
    }
}

# Validates required regex pattern list in template content.
function Test-RequiredPatternSet {
    param(
        [string] $DisplayPath,
        [string] $Content,
        [string[]] $RequiredPatterns
    )

    foreach ($requiredPattern in $RequiredPatterns) {
        if ($Content -notmatch $requiredPattern) {
            Add-ValidationFailure ("Template missing required pattern '{0}': {1}" -f $requiredPattern, $DisplayPath)
        }
    }
}

# Validates forbidden regex pattern list in template content.
function Test-ForbiddenPatternSet {
    param(
        [string] $DisplayPath,
        [string] $Content,
        [string[]] $ForbiddenPatterns
    )

    foreach ($forbiddenPattern in $ForbiddenPatterns) {
        if ($Content -match $forbiddenPattern) {
            Add-ValidationFailure ("Template contains forbidden pattern '{0}': {1}" -f $forbiddenPattern, $DisplayPath)
        }
    }
}

# Validates required repository path references declared for a template.
function Test-PathReferenceSet {
    param(
        [string] $Root,
        [string] $DisplayPath,
        [string[]] $PathReferences
    )

    foreach ($pathReference in $PathReferences) {
        $resolvedReference = Resolve-RepoPath -Root $Root -Path $pathReference
        if (-not (Test-Path -LiteralPath $resolvedReference)) {
            Add-ValidationFailure ("Template references missing path '{0}': {1}" -f $pathReference, $DisplayPath)
        }
    }
}

# Reads and parses baseline JSON.
function Read-BaselineDocument {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Template baseline file not found: {0}" -f $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in template baseline {0}: {1}" -f $Path, $_.Exception.Message)
        return $null
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$resolvedTemplateDirectory = Resolve-RepoPath -Root $resolvedRepoRoot -Path $TemplateDirectory

if (-not (Test-Path -LiteralPath $resolvedTemplateDirectory -PathType Container)) {
    Add-ValidationFailure ("Template directory not found: {0}" -f $TemplateDirectory)
    Write-StyledOutput ''
    Write-StyledOutput 'Template standards validation summary'
    Write-StyledOutput '  Templates checked: 0'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$baselineDocument = Read-BaselineDocument -Path $resolvedBaselinePath
if ($null -eq $baselineDocument) {
    Write-StyledOutput ''
    Write-StyledOutput 'Template standards validation summary'
    Write-StyledOutput '  Templates checked: 0'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$requiredFiles = Convert-ToStringArray -Value $baselineDocument.requiredFiles
$templateRules = @($baselineDocument.templateRules)

foreach ($requiredFile in $requiredFiles) {
    $resolvedRequiredFile = Resolve-RepoPath -Root $resolvedRepoRoot -Path $requiredFile
    if (-not (Test-Path -LiteralPath $resolvedRequiredFile -PathType Leaf)) {
        Add-ValidationFailure ("Required template not found: {0}" -f $requiredFile)
    }
    else {
        Write-StyledOutput ("[OK] Required template: {0}" -f $requiredFile)
    }
}

$templateFiles = @(
    Get-ChildItem -LiteralPath $resolvedTemplateDirectory -File -Recurse |
        Sort-Object FullName
)

foreach ($templateFile in $templateFiles) {
    $displayPath = Convert-ToDisplayPath -Root $resolvedRepoRoot -Path $templateFile.FullName
    $content = Get-Content -Raw -LiteralPath $templateFile.FullName
    $lines = @(
        if ([string]::IsNullOrEmpty($content)) {
            @()
        }
        else {
            Get-Content -LiteralPath $templateFile.FullName
        }
    )

    Test-GenericTemplateFile -DisplayPath $displayPath -Content $content -Lines $lines
    Write-VerboseLog ("Validated generic template hygiene: {0}" -f $displayPath)
}

foreach ($rule in $templateRules) {
    $rulePath = [string] $rule.path
    if ([string]::IsNullOrWhiteSpace($rulePath)) {
        Add-ValidationFailure ('Template rule entry contains empty path.')
        continue
    }

    $resolvedRulePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $rulePath
    $displayPath = Convert-ToDisplayPath -Root $resolvedRepoRoot -Path $resolvedRulePath
    if (-not (Test-Path -LiteralPath $resolvedRulePath -PathType Leaf)) {
        Add-ValidationFailure ("Template rule path not found: {0}" -f $rulePath)
        continue
    }

    $content = Get-Content -Raw -LiteralPath $resolvedRulePath
    $requiredPatterns = Convert-ToStringArray -Value (Get-ObjectPropertyValue -InputObject $rule -PropertyName 'requiredPatterns')
    $forbiddenPatterns = Convert-ToStringArray -Value (Get-ObjectPropertyValue -InputObject $rule -PropertyName 'forbiddenPatterns')
    $pathReferences = Convert-ToStringArray -Value (Get-ObjectPropertyValue -InputObject $rule -PropertyName 'requiredPathReferences')

    Test-RequiredPatternSet -DisplayPath $displayPath -Content $content -RequiredPatterns $requiredPatterns
    Test-ForbiddenPatternSet -DisplayPath $displayPath -Content $content -ForbiddenPatterns $forbiddenPatterns
    Test-PathReferenceSet -Root $resolvedRepoRoot -DisplayPath $displayPath -PathReferences $pathReferences
    Write-VerboseLog ("Validated template rule set: {0}" -f $displayPath)
}

Write-StyledOutput ''
Write-StyledOutput 'Template standards validation summary'
Write-StyledOutput ("  Templates checked: {0}" -f $templateFiles.Count)
Write-StyledOutput ("  Rules checked: {0}" -f $templateRules.Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'Template standards validation passed.'
exit 0