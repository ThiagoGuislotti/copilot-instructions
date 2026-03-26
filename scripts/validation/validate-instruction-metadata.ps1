<#
.SYNOPSIS
    Validates metadata frontmatter across instructions, prompts, and chat modes.

.DESCRIPTION
    Performs deterministic checks for metadata consistency in `.github` authoring assets.

    Checks include:
    - Required frontmatter blocks
    - Required keys by file type
    - Allowed values for key fields (for example, instruction priority)
    - Basic sanity checks for applyTo patterns and tools lists

    Exit code:
    - 0 when all required checks pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-instruction-metadata.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
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

# Extracts YAML-like frontmatter block from markdown text.
function Get-FrontmatterBlock {
    param(
        [string[]] $Lines
    )

    if ($Lines.Count -lt 3) {
        return $null
    }

    if ($Lines[0].Trim() -ne '---') {
        return $null
    }

    $endIndex = -1
    for ($i = 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq '---') {
            $endIndex = $i
            break
        }
    }

    if ($endIndex -lt 1) {
        return $null
    }

    return [pscustomobject]@{
        startLine = 1
        endLine = $endIndex + 1
        text = ($Lines[1..($endIndex - 1)] -join "`n")
    }
}

# Converts frontmatter text to key/value map.
function Convert-FrontmatterToMap {
    param(
        [string] $FrontmatterText
    )

    $result = @{}
    foreach ($line in ($FrontmatterText -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('#')) {
            continue
        }

        $match = [regex]::Match($line, '^\s*(?<key>[A-Za-z0-9_-]+)\s*:\s*(?<value>.*)\s*$')
        if (-not $match.Success) {
            continue
        }

        $key = $match.Groups['key'].Value
        $value = $match.Groups['value'].Value.Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $result[$key] = $value
    }

    return $result
}

# Parses list-like frontmatter values and returns item count.
function Get-FrontmatterListItemCount {
    param(
        [string] $RawValue
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return 0
    }

    $value = $RawValue.Trim()
    if ($value.StartsWith('[') -and $value.EndsWith(']')) {
        $inner = $value.Substring(1, $value.Length - 2)
        $items = @(
            $inner -split ',' |
                ForEach-Object { $_.Trim().Trim('"', "'") } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        return $items.Count
    }

    return 1
}

# Validates metadata rules for instruction files.
function Test-InstructionMetadataEntry {
    param(
        [string] $RelativePath,
        [hashtable] $Map
    )

    foreach ($requiredKey in @('applyTo', 'priority')) {
        if (-not $Map.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace([string] $Map[$requiredKey])) {
            Add-ValidationFailure ("Instruction metadata missing key '{0}': {1}" -f $requiredKey, $RelativePath)
        }
    }

    if ($Map.ContainsKey('priority')) {
        $priority = [string] $Map['priority']
        if ($priority -notin @('low', 'medium', 'high')) {
            Add-ValidationFailure ("Instruction priority must be low|medium|high: {0} ({1})" -f $RelativePath, $priority)
        }
    }

    if ($Map.ContainsKey('applyTo')) {
        $applyTo = [string] $Map['applyTo']
        if ($applyTo -match '^[A-Za-z]:\\') {
            Add-ValidationFailure ("Instruction applyTo should not use absolute paths: {0}" -f $RelativePath)
        }

        if ($applyTo -eq '**/*' -or $applyTo -eq '**/*.*') {
            Add-ValidationWarning ("Instruction applyTo is very broad; prefer specific globs when possible: {0}" -f $RelativePath)
        }
    }
}

# Validates metadata rules for prompt files.
function Test-PromptMetadataEntry {
    param(
        [string] $RelativePath,
        [hashtable] $Map
    )

    foreach ($requiredKey in @('description', 'mode', 'tools')) {
        if (-not $Map.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace([string] $Map[$requiredKey])) {
            Add-ValidationFailure ("Prompt metadata missing key '{0}': {1}" -f $requiredKey, $RelativePath)
        }
    }

    if ($Map.ContainsKey('tools')) {
        $toolCount = Get-FrontmatterListItemCount -RawValue ([string] $Map['tools'])
        if ($toolCount -lt 1) {
            Add-ValidationFailure ("Prompt tools list must include at least one entry: {0}" -f $RelativePath)
        }
    }
}

# Validates metadata rules for chat mode files.
function Test-ChatModeMetadataEntry {
    param(
        [string] $RelativePath,
        [hashtable] $Map
    )

    foreach ($requiredKey in @('description', 'tools')) {
        if (-not $Map.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace([string] $Map[$requiredKey])) {
            Add-ValidationFailure ("Chat mode metadata missing key '{0}': {1}" -f $requiredKey, $RelativePath)
        }
    }

    if ($Map.ContainsKey('tools')) {
        $toolCount = Get-FrontmatterListItemCount -RawValue ([string] $Map['tools'])
        if ($toolCount -lt 1) {
            Add-ValidationFailure ("Chat mode tools list must include at least one entry: {0}" -f $RelativePath)
        }
    }
}

# Executes metadata validation for one markdown file.
function Test-MetadataFile {
    param(
        [string] $Root,
        [string] $FilePath,
        [ValidateSet('instruction', 'prompt', 'chatmode')] [string] $Type
    )

    $relativePath = Convert-ToRelativePath -Root $Root -Path $FilePath
    $lines = @(Get-Content -LiteralPath $FilePath)
    $frontmatter = Get-FrontmatterBlock -Lines $lines

    if ($null -eq $frontmatter) {
        Add-ValidationFailure ("Missing frontmatter block in {0}: {1}" -f $Type, $relativePath)
        return
    }

    $map = Convert-FrontmatterToMap -FrontmatterText $frontmatter.text

    switch ($Type) {
        'instruction' { Test-InstructionMetadataEntry -RelativePath $relativePath -Map $map }
        'prompt' { Test-PromptMetadataEntry -RelativePath $relativePath -Map $map }
        'chatmode' { Test-ChatModeMetadataEntry -RelativePath $relativePath -Map $map }
    }

    Write-VerboseLog ("Validated metadata: {0}" -f $relativePath)
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$instructionFiles = @(
    Get-ChildItem -LiteralPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/instructions') -File -Filter '*.md' | Sort-Object Name
)
$promptFiles = @(
    Get-ChildItem -LiteralPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/prompts') -File -Filter '*.prompt.md' | Sort-Object Name
)
$chatModeFiles = @(
    Get-ChildItem -LiteralPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/chatmodes') -File -Filter '*.chatmode.md' | Sort-Object Name
)

foreach ($file in $instructionFiles) {
    Test-MetadataFile -Root $resolvedRepoRoot -FilePath $file.FullName -Type 'instruction'
}

foreach ($file in $promptFiles) {
    Test-MetadataFile -Root $resolvedRepoRoot -FilePath $file.FullName -Type 'prompt'
}

foreach ($file in $chatModeFiles) {
    Test-MetadataFile -Root $resolvedRepoRoot -FilePath $file.FullName -Type 'chatmode'
}

Write-StyledOutput ''
Write-StyledOutput 'Instruction metadata validation summary'
Write-StyledOutput ("  Instruction files: {0}" -f $instructionFiles.Count)
Write-StyledOutput ("  Prompt files: {0}" -f $promptFiles.Count)
Write-StyledOutput ("  Chat mode files: {0}" -f $chatModeFiles.Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'Instruction metadata validation passed.'
exit 0