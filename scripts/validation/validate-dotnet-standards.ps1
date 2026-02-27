<#
.SYNOPSIS
    Validates .NET template standards used by instruction assets.

.DESCRIPTION
    Performs deterministic checks for C# templates under `.github/templates`.

    Checks include:
    - Required template files existence
    - Required placeholder tokens per template
    - Basic C# template conventions (namespace placeholder, XML summary)
    - Whitespace hygiene (no tabs, no trailing spaces)

    Exit code:
    - 0 when all required checks pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER TemplateDirectory
    Template directory relative path. Defaults to `.github/templates`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-dotnet-standards.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TemplateDirectory = '.github/templates',
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

# Converts absolute path into repository-relative path.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return [System.IO.Path]::GetRelativePath($Root, $Path)
}

# Validates required template files exist.
function Test-RequiredTemplateFile {
    param(
        [string] $Root,
        [string] $RelativePath
    )

    $absolutePath = Resolve-RepoPath -Root $Root -Path $RelativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        Add-ValidationFailure ("Required .NET template not found: {0}" -f $RelativePath)
        return $null
    }

    return $absolutePath
}

# Validates required pattern list in template content.
function Test-TemplatePatternSet {
    param(
        [string] $RelativePath,
        [string] $Content,
        [string[]] $RequiredPatterns
    )

    foreach ($requiredPattern in $RequiredPatterns) {
        if ($Content -notmatch $requiredPattern) {
            Add-ValidationFailure ("Template missing required pattern '{0}': {1}" -f $requiredPattern, $RelativePath)
        }
    }
}

# Validates whitespace hygiene for a C# template file.
function Test-TemplateWhitespace {
    param(
        [string] $RelativePath,
        [string[]] $Lines
    )

    $lineNumber = 0
    foreach ($line in $Lines) {
        $lineNumber++

        if ($line -match "`t") {
            Add-ValidationFailure ("Template contains tab character: {0}:{1}" -f $RelativePath, $lineNumber)
        }

        if ($line -match '\s+$') {
            Add-ValidationFailure ("Template contains trailing whitespace: {0}:{1}" -f $RelativePath, $lineNumber)
        }
    }
}

# Validates baseline C# template conventions.
function Test-TemplateConventionSet {
    param(
        [string] $RelativePath,
        [string] $Content
    )

    if ($Content -notmatch '\[Namespace\]') {
        Add-ValidationFailure ("Template missing [Namespace] placeholder: {0}" -f $RelativePath)
    }

    if ($Content -notmatch '<summary>') {
        Add-ValidationWarning ("Template missing XML <summary> section: {0}" -f $RelativePath)
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedTemplateDirectory = Resolve-RepoPath -Root $resolvedRepoRoot -Path $TemplateDirectory
if (-not (Test-Path -LiteralPath $resolvedTemplateDirectory -PathType Container)) {
    Add-ValidationFailure ("Template directory not found: {0}" -f $TemplateDirectory)
    Write-StyledOutput ''
    Write-StyledOutput 'Dotnet standards validation summary'
    Write-StyledOutput ("  Templates checked: 0")
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$requiredTemplateMap = [ordered]@{
    '.github/templates/dotnet-class-template.cs' = @(
        'public\s+class\s+\[ClassName\]',
        'namespace\s+\[Namespace\]'
    )
    '.github/templates/dotnet-interface-template.cs' = @(
        'public\s+interface\s+\[InterfaceName\]',
        'namespace\s+\[Namespace\]'
    )
    '.github/templates/dotnet-unit-test-template.cs' = @(
        '\[TEST_CLASS\]',
        '(\[Fact\]|\[Test\]|\[Theory\])'
    )
    '.github/templates/dotnet-integration-test-template.cs' = @(
        'IMediator',
        '\[Test\]'
    )
}

foreach ($requiredTemplatePath in $requiredTemplateMap.Keys) {
    $absolutePath = Test-RequiredTemplateFile -Root $resolvedRepoRoot -RelativePath $requiredTemplatePath
    if ($null -eq $absolutePath) {
        continue
    }

    $relativePath = Convert-ToRelativePath -Root $resolvedRepoRoot -Path $absolutePath
    $content = Get-Content -Raw -LiteralPath $absolutePath

    Test-TemplatePatternSet -RelativePath $relativePath -Content $content -RequiredPatterns $requiredTemplateMap[$requiredTemplatePath]
}

$allTemplateFiles = @(Get-ChildItem -LiteralPath $resolvedTemplateDirectory -File -Filter '*.cs' | Sort-Object Name)
foreach ($templateFile in $allTemplateFiles) {
    $relativePath = Convert-ToRelativePath -Root $resolvedRepoRoot -Path $templateFile.FullName
    $content = Get-Content -Raw -LiteralPath $templateFile.FullName
    $lines = @(Get-Content -LiteralPath $templateFile.FullName)

    Test-TemplateConventionSet -RelativePath $relativePath -Content $content
    Test-TemplateWhitespace -RelativePath $relativePath -Lines $lines
    Write-VerboseLog ("Validated template: {0}" -f $relativePath)
}

Write-StyledOutput ''
Write-StyledOutput 'Dotnet standards validation summary'
Write-StyledOutput ("  Templates checked: {0}" -f $allTemplateFiles.Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'Dotnet standards validation passed.'
exit 0