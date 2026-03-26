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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

# -------------------------------
# Helpers
# -------------------------------
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