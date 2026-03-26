<#
.SYNOPSIS
    Renders the repository-managed VS Code settings template into the global user profile.

.DESCRIPTION
    Uses `.vscode/settings.tamplate.jsonc` as the source of truth for the global
    VS Code `settings.json` file.

    Behavior:
    - reads the versioned template from the repository
    - renders runtime placeholders such as `%USERPROFILE%`
    - writes the rendered result to the global VS Code user profile
    - updates the target only when content changed
    - optionally creates a timestamped backup before overwriting

.PARAMETER RepoRoot
    Optional repository root. If omitted, script detects a root containing .github and .codex.

.PARAMETER WorkspaceVscodePath
    Optional path to repository `.vscode` folder. Defaults to `<RepoRoot>/.vscode`.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user folder path. Default is OS-specific:
    - Windows: `%APPDATA%\Code\User`
    - macOS: `~/Library/Application Support/Code/User`
    - Linux: `$XDG_CONFIG_HOME/Code/User` or `~/.config/Code/User`

.PARAMETER CreateBackup
    Creates a timestamped backup of the current global `settings.json` before overwriting.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-settings.ps1

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-settings.ps1 -CreateBackup

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $WorkspaceVscodePath,
    [string] $GlobalVscodeUserPath,
    [switch] $CreateBackup,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../shared-scripts/common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
# Resolves workspace .vscode folder path.
function Resolve-WorkspaceVscodePath {
    param(
        [string] $ResolvedRepoRoot,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot '.vscode'
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Resolves VS Code global user folder path with OS-aware defaults.
function Resolve-GlobalVscodeUserPath {
    param(
        [string] $RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath -PathType Container) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }

        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    $homePath = Resolve-UserHomePath
    $candidates = @()

    if ($IsWindows) {
        if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
            $candidates += (Join-Path $env:APPDATA 'Code\User')
        }
        $candidates += (Join-Path $homePath 'AppData\Roaming\Code\User')
    }
    elseif ($IsMacOS) {
        $candidates += (Join-Path $homePath 'Library/Application Support/Code/User')
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
            $candidates += (Join-Path $env:XDG_CONFIG_HOME 'Code/User')
        }
        $candidates += (Join-Path $homePath '.config/Code/User')
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($candidates.Count -gt 0) {
        return [System.IO.Path]::GetFullPath($candidates[0])
    }

    throw 'Could not resolve VS Code global user path.'
}

# Returns true when normalized text contents match.
function Test-TextContentMatch {
    param(
        [string] $ExpectedContent,
        [string] $TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return $false
    }

    $targetContent = Get-Content -Raw -LiteralPath $TargetPath
    $normalizedExpected = $ExpectedContent.Replace("`r`n", "`n")
    $normalizedTarget = $targetContent.Replace("`r`n", "`n")
    return [string]::Equals($normalizedExpected, $normalizedTarget, [System.StringComparison]::Ordinal)
}

# Renders template placeholders into runtime-safe text.
function Get-RenderedSettingsTemplate {
    param(
        [string] $TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
        throw "Settings template not found: $TemplatePath"
    }

    $templateContent = Get-Content -Raw -LiteralPath $TemplatePath
    $userHome = Resolve-UserHomePath
    $escapedUserHome = $userHome.Replace('\', '\\')

    return $templateContent.Replace('%USERPROFILE%', $escapedUserHome)
}

# Creates a timestamped backup for the existing settings file.
function New-SettingsBackup {
    param(
        [string] $TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return $null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = '{0}.{1}.bak' -f $TargetPath, $timestamp
    Copy-Item -LiteralPath $TargetPath -Destination $backupPath -Force
    return $backupPath
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$renderScriptPath = Join-Path $resolvedRepoRoot 'scripts\runtime\render-vscode-workspace-surfaces.ps1'
if (-not (Test-Path -LiteralPath $renderScriptPath -PathType Leaf)) {
    throw "Missing VS Code workspace renderer: $renderScriptPath"
}
& $renderScriptPath -RepoRoot $resolvedRepoRoot -Verbose:$script:IsVerboseEnabled | Out-Null
$renderExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
if ($renderExitCode -ne 0) {
    throw ("VS Code workspace render failed before settings sync. ExitCode={0}" -f $renderExitCode)
}

$resolvedWorkspaceVscodePath = Resolve-WorkspaceVscodePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $WorkspaceVscodePath
$resolvedGlobalVscodeUserPath = Resolve-GlobalVscodeUserPath -RequestedPath $GlobalVscodeUserPath
$sourceTemplatePath = Join-Path $resolvedWorkspaceVscodePath 'settings.tamplate.jsonc'
$targetSettingsPath = Join-Path $resolvedGlobalVscodeUserPath 'settings.json'

New-Item -ItemType Directory -Path $resolvedGlobalVscodeUserPath -Force | Out-Null

$renderedContent = Get-RenderedSettingsTemplate -TemplatePath $sourceTemplatePath
if (Test-TextContentMatch -ExpectedContent $renderedContent -TargetPath $targetSettingsPath) {
    Write-StyledOutput ("[SKIP] Global settings already aligned: {0}" -f $targetSettingsPath)
    Write-StyledOutput ''
    Write-StyledOutput 'VS Code global settings sync summary'
    Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
    Write-StyledOutput ("  Source template: {0}" -f $sourceTemplatePath)
    Write-StyledOutput ("  Target settings: {0}" -f $targetSettingsPath)
    Write-StyledOutput '  Updated: 0'
    Write-StyledOutput '  Skipped: 1'
    exit 0
}

$backupPath = $null
if ($CreateBackup) {
    $backupPath = New-SettingsBackup -TargetPath $targetSettingsPath
}

Set-Content -LiteralPath $targetSettingsPath -Value $renderedContent -Encoding UTF8
Write-StyledOutput ("[OK] Global settings synchronized: {0}" -f $targetSettingsPath)

Write-StyledOutput ''
Write-StyledOutput 'VS Code global settings sync summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Source template: {0}" -f $sourceTemplatePath)
Write-StyledOutput ("  Target settings: {0}" -f $targetSettingsPath)
if ($null -ne $backupPath) {
    Write-StyledOutput ("  Backup: {0}" -f $backupPath)
}
Write-StyledOutput '  Updated: 1'
Write-StyledOutput '  Skipped: 0'

exit 0