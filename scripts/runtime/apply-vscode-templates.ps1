<#
.SYNOPSIS
    Applies versioned VS Code template files into active workspace settings files.

.DESCRIPTION
    Copies repository templates from `.vscode/settings.tamplate.jsonc` and
    `.vscode/mcp.tamplate.jsonc` into active files:
    - `.vscode/settings.json`
    - `.vscode/mcp.json`

    By default, existing target files are preserved. Use -Force to overwrite.

.PARAMETER RepoRoot
    Optional repository root. If omitted, script detects root from script location.

.PARAMETER VscodePath
    Optional path to the workspace `.vscode` folder. Defaults to `<RepoRoot>/.vscode`.

.PARAMETER Force
    Overwrites existing target files.

.PARAMETER SkipSettings
    Skips applying `settings.tamplate.jsonc`.

.PARAMETER SkipMcp
    Skips applying `mcp.tamplate.jsonc`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/apply-vscode-templates.ps1

.EXAMPLE
    pwsh -File scripts/runtime/apply-vscode-templates.ps1 -Force

.EXAMPLE
    pwsh -File scripts/runtime/apply-vscode-templates.ps1 -SkipMcp

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $VscodePath,
    [switch] $Force,
    [switch] $SkipSettings,
    [switch] $SkipMcp,
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
        Write-StyledOutput ("[VERBOSE:{0}] {1}" -f $Color, $Message)
    }
}

# Resolves repository root from input and fallback location candidates.
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

# Copies a template file to destination with optional overwrite control.
function Copy-TemplateFile {
    param(
        [string] $SourcePath,
        [string] $TargetPath,
        [switch] $Overwrite
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Template file not found: $SourcePath"
    }

    $targetExists = Test-Path -LiteralPath $TargetPath
    if ($targetExists -and (-not $Overwrite)) {
        Write-StyledOutput ("[SKIP] Target exists (use -Force): {0}" -f $TargetPath)
        return $false
    }

    $targetDirectory = Split-Path -Path $TargetPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    }

    Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
    Write-StyledOutput ("[OK] Applied template: {0} -> {1}" -f $SourcePath, $TargetPath)
    return $true
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
$resolvedVscodePath = if ([string]::IsNullOrWhiteSpace($VscodePath)) {
    Join-Path $resolvedRepoRoot '.vscode'
}
else {
    if ([System.IO.Path]::IsPathRooted($VscodePath)) {
        [System.IO.Path]::GetFullPath($VscodePath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $resolvedRepoRoot $VscodePath))
    }
}

if (-not (Test-Path -LiteralPath $resolvedVscodePath)) {
    throw "VS Code path not found: $resolvedVscodePath"
}

$applied = 0
$skipped = 0

if (-not $SkipSettings) {
    $settingsSource = Join-Path $resolvedVscodePath 'settings.tamplate.jsonc'
    $settingsTarget = Join-Path $resolvedVscodePath 'settings.json'
    if (Copy-TemplateFile -SourcePath $settingsSource -TargetPath $settingsTarget -Overwrite:$Force) {
        $applied++
    }
    else {
        $skipped++
    }
}
else {
    Write-VerboseColor 'Skipping settings template by request.' 'Yellow'
}

if (-not $SkipMcp) {
    $mcpSource = Join-Path $resolvedVscodePath 'mcp.tamplate.jsonc'
    $mcpTarget = Join-Path $resolvedVscodePath 'mcp.json'
    if (Copy-TemplateFile -SourcePath $mcpSource -TargetPath $mcpTarget -Overwrite:$Force) {
        $applied++
    }
    else {
        $skipped++
    }
}
else {
    Write-VerboseColor 'Skipping MCP template by request.' 'Yellow'
}

Write-StyledOutput ''
Write-StyledOutput 'VS Code template apply summary'
Write-StyledOutput ("  applied: {0}" -f $applied)
Write-StyledOutput ("  skipped: {0}" -f $skipped)

exit 0