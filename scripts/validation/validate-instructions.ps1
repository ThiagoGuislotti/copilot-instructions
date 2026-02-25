<#
.SYNOPSIS
    Validates routing and documentation assets used by shared Copilot/Codex instructions.

.DESCRIPTION
    Performs static validation for repository instruction assets:
    - Required files existence
    - instruction-routing.catalog.yml path entries
    - JSON parsing for schema/manifest/snippets
    - Markdown link integrity for core docs and instruction folders

    Returns exit code 1 when failures are found, otherwise 0.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER Verbose
    Prints detailed diagnostics during validation.

.EXAMPLE
    pwsh -File scripts/validation/validate-instructions.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-instructions.ps1 -Verbose

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

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

function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-Host ("[FAIL] {0}" -f $Message) -ForegroundColor Red
}

function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-Host ("[WARN] {0}" -f $Message) -ForegroundColor Yellow
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

function Should-ValidateLinkTarget {
    param(
        [string] $Target
    )

    $value = $Target.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    if ($value.StartsWith('#')) { return $false }
    if ($value -match '^(https?|mailto|ftp):') { return $false }
    if ($value -match '^\[[A-Z0-9_\- ]+\]$') { return $false }
    if ($value -match '\$\{.+\}') { return $false }

    if ($value.StartsWith('./') -or $value.StartsWith('../') -or $value.StartsWith('/')) { return $true }
    if ($value -match '[/\\]') { return $true }
    if ($value -match '\.[A-Za-z0-9]{1,10}([#?].*)?$') { return $true }
    if ($value -match '^(\.github|\.codex|prompts|chatmodes|schemas|scripts|src|templates)/') { return $true }

    return $false
}

function Resolve-MarkdownTarget {
    param(
        [string] $SourceFilePath,
        [string] $Target,
        [string] $Root
    )

    $pathPart = $Target.Split('#')[0].Split('?')[0].Trim()
    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return $null
    }

    if ($pathPart.StartsWith('/')) {
        $relative = $pathPart.TrimStart('/', '\')
        return [System.IO.Path]::GetFullPath((Join-Path $Root $relative))
    }

    if ([System.IO.Path]::IsPathRooted($pathPart)) {
        return [System.IO.Path]::GetFullPath($pathPart)
    }

    $sourceDir = Split-Path -Parent $SourceFilePath
    return [System.IO.Path]::GetFullPath((Join-Path $sourceDir $pathPart))
}

function Get-MarkdownLinkTargets {
    param(
        [string] $Path
    )

    $content = Get-Content -Raw -LiteralPath $Path
    $matches = [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')
    $targets = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        $raw = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }

        if ($raw.StartsWith('<') -and $raw.EndsWith('>')) {
            $raw = $raw.TrimStart('<').TrimEnd('>')
        }

        $titleMatch = [regex]::Match($raw, '^(?<path>\S+)\s+(?:"[^"]*"|''[^'']*'')$')
        if ($titleMatch.Success) {
            $raw = $titleMatch.Groups['path'].Value
        }

        $targets.Add($raw) | Out-Null
    }

    return $targets
}

function Test-JsonFile {
    param(
        [string] $Root,
        [string] $Path
    )

    $absolute = Resolve-RepoPath -Root $Root -Path $Path
    if (-not (Test-Path -LiteralPath $absolute)) {
        Add-ValidationFailure "Missing JSON file: $Path"
        return $null
    }

    try {
        $json = Get-Content -Raw -LiteralPath $absolute | ConvertFrom-Json -Depth 100
        Write-Host ("[OK] JSON parse: {0}" -f $Path) -ForegroundColor Green
        return $json
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in {0} :: {1}" -f $Path, $_.Exception.Message)
        return $null
    }
}

function Test-RequiredFiles {
    param(
        [string] $Root,
        [string[]] $RequiredFiles
    )

    foreach ($required in $RequiredFiles) {
        $absolute = Resolve-RepoPath -Root $Root -Path $required
        if (-not (Test-Path -LiteralPath $absolute)) {
            Add-ValidationFailure "Required file not found: $required"
            continue
        }

        Write-Host ("[OK] Required file: {0}" -f $required) -ForegroundColor Green
    }
}

function Test-CatalogPaths {
    param(
        [string] $Root,
        [string] $CatalogRelativePath
    )

    $catalogPath = Resolve-RepoPath -Root $Root -Path $CatalogRelativePath
    if (-not (Test-Path -LiteralPath $catalogPath)) {
        return
    }

    $catalogLines = Get-Content -LiteralPath $catalogPath
    $catalogPaths = New-Object System.Collections.Generic.List[string]

    foreach ($line in $catalogLines) {
        $pathMatch = [regex]::Match($line, '^\s*-\s*path:\s*(?<value>.+?)\s*$')
        if (-not $pathMatch.Success) {
            $pathMatch = [regex]::Match($line, '^\s*path:\s*(?<value>.+?)\s*$')
        }

        if (-not $pathMatch.Success) {
            continue
        }

        $pathValue = $pathMatch.Groups['value'].Value.Trim().Trim("'").Trim('"')
        if (-not [string]::IsNullOrWhiteSpace($pathValue)) {
            $catalogPaths.Add($pathValue) | Out-Null
        }
    }

    if ($catalogPaths.Count -eq 0) {
        Add-ValidationFailure 'No path entries found in instruction-routing.catalog.yml'
        return
    }

    $catalogDir = Split-Path -Parent $catalogPath
    foreach ($entry in ($catalogPaths | Select-Object -Unique)) {
        $absolute = $null
        if ([System.IO.Path]::IsPathRooted($entry)) {
            $absolute = [System.IO.Path]::GetFullPath($entry)
        }
        else {
            $absolute = [System.IO.Path]::GetFullPath((Join-Path $catalogDir $entry))
        }

        if (-not (Test-Path -LiteralPath $absolute)) {
            Add-ValidationFailure ("Catalog path not found: {0}" -f $entry)
        }
    }

    Write-Host ("[OK] Catalog paths checked: {0}" -f $catalogPaths.Count) -ForegroundColor Green
}

function Get-MarkdownFilesForValidation {
    param(
        [string] $Root
    )

    $markdownFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    $explicitMarkdown = @(
        'README.md',
        'scripts/README.md',
        '.github/AGENTS.md',
        '.github/copilot-instructions.md',
        '.codex/README.md',
        '.codex/mcp/README.md',
        '.codex/scripts/README.md',
        '.codex/skills/README.md'
    )

    foreach ($relative in $explicitMarkdown) {
        $absolute = Resolve-RepoPath -Root $Root -Path $relative
        if (Test-Path -LiteralPath $absolute) {
            $markdownFiles.Add($absolute) | Out-Null
        }
        else {
            Add-ValidationWarning "Skipping missing markdown file in set: $relative"
        }
    }

    $markdownFolders = @(
        '.github/instructions',
        '.github/chatmodes',
        '.github/prompts',
        '.codex/skills'
    )

    foreach ($folder in $markdownFolders) {
        $absoluteFolder = Resolve-RepoPath -Root $Root -Path $folder
        if (-not (Test-Path -LiteralPath $absoluteFolder)) {
            Add-ValidationWarning "Skipping missing markdown folder: $folder"
            continue
        }

        Get-ChildItem -LiteralPath $absoluteFolder -Recurse -File -Filter '*.md' | ForEach-Object {
            $markdownFiles.Add($_.FullName) | Out-Null
        }
    }

    return $markdownFiles
}

function Test-MarkdownLinks {
    param(
        [string] $Root,
        [System.Collections.Generic.HashSet[string]] $MarkdownFiles
    )

    $checkedLinks = 0

    foreach ($file in ($MarkdownFiles | Sort-Object)) {
        foreach ($target in (Get-MarkdownLinkTargets -Path $file)) {
            if (-not (Should-ValidateLinkTarget -Target $target)) {
                continue
            }

            $checkedLinks++
            $resolved = Resolve-MarkdownTarget -SourceFilePath $file -Target $target -Root $Root
            if ($null -eq $resolved -or -not (Test-Path -LiteralPath $resolved)) {
                $relativeFile = [System.IO.Path]::GetRelativePath($Root, $file)
                Add-ValidationFailure ("Broken markdown link in {0} -> {1}" -f $relativeFile, $target)
            }
        }
    }

    return $checkedLinks
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot

$requiredFiles = @(
    '.github/AGENTS.md',
    '.github/copilot-instructions.md',
    '.github/instruction-routing.catalog.yml',
    '.github/prompts/route-instructions.prompt.md',
    '.github/schemas/instruction-routing.catalog.schema.json'
)

Test-RequiredFiles -Root $resolvedRepoRoot -RequiredFiles $requiredFiles
Test-CatalogPaths -Root $resolvedRepoRoot -CatalogRelativePath '.github/instruction-routing.catalog.yml'

$schema = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/schemas/instruction-routing.catalog.schema.json'
if ($null -ne $schema) {
    foreach ($property in @('$schema', 'title', 'type', 'properties')) {
        if ($null -eq $schema.$property) {
            Add-ValidationFailure ("Schema missing expected property: {0}" -f $property)
        }
    }
}

$manifest = Test-JsonFile -Root $resolvedRepoRoot -Path '.codex/mcp/servers.manifest.json'
if ($null -ne $manifest) {
    if ($null -eq $manifest.servers -or @($manifest.servers).Count -eq 0) {
        Add-ValidationFailure 'MCP manifest must contain at least one server.'
    }
}

[void](Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/snippets/codex-cli.code-snippets')
[void](Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/snippets/copilot.code-snippets')

$markdownFiles = Get-MarkdownFilesForValidation -Root $resolvedRepoRoot
$checkedLinks = Test-MarkdownLinks -Root $resolvedRepoRoot -MarkdownFiles $markdownFiles

Write-Host ''
Write-Host 'Validation summary' -ForegroundColor Cyan
Write-Host ("  Markdown files checked: {0}" -f $markdownFiles.Count)
Write-Host ("  Markdown links checked: {0}" -f $checkedLinks)
Write-Host ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Host ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-Host 'All instruction validations passed.' -ForegroundColor Green
exit 0
