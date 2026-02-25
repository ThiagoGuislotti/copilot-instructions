<#
.SYNOPSIS
    Syncs repository-managed .github and .codex assets into the local runtime folders.

.DESCRIPTION
    Detects the repository root and copies shared assets to:
    - $env:USERPROFILE\.github
    - $env:USERPROFILE\.codex\skills
    - $env:USERPROFILE\.codex\shared-mcp
    - $env:USERPROFILE\.codex\shared-scripts

    When -ApplyMcpConfig is specified, applies MCP servers from the shared manifest
    into the local Codex config.toml file.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script detects root from the script location.

.PARAMETER TargetGithubPath
    Target path for .github runtime assets. Defaults to $env:USERPROFILE\.github.

.PARAMETER TargetCodexPath
    Target path for .codex runtime assets. Defaults to $env:USERPROFILE\.codex.

.PARAMETER Mirror
    Mirrors target folders (removes files not present in source) when supported by the sync mode.

.PARAMETER ApplyMcpConfig
    Applies mcp_servers blocks from .codex/mcp/servers.manifest.json into target config.toml.

.PARAMETER BackupConfig
    Creates backup before applying MCP config (used with -ApplyMcpConfig).

.PARAMETER Verbose
    Shows detailed sync diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/bootstrap.ps1

.EXAMPLE
    pwsh -File scripts/runtime/bootstrap.ps1 -Mirror

.EXAMPLE
    pwsh -File scripts/runtime/bootstrap.ps1 -ApplyMcpConfig -BackupConfig

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+, robocopy (Windows, recommended).
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath = "$env:USERPROFILE\.github",
    [string] $TargetCodexPath = "$env:USERPROFILE\.codex",
    [switch] $Mirror,
    [switch] $ApplyMcpConfig,
    [switch] $BackupConfig,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent

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

function Assert-PathExists {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("Missing {0}: {1}" -f $Label, $Path)
    }
}

function Invoke-FallbackSync {
    param(
        [string] $Source,
        [string] $Destination,
        [switch] $MirrorMode
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    if ($MirrorMode -and (Test-Path -LiteralPath $Destination)) {
        Get-ChildItem -LiteralPath $Destination -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $sourceItems = Get-ChildItem -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    foreach ($item in $sourceItems) {
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Invoke-DirectorySync {
    param(
        [string] $Source,
        [string] $Destination,
        [switch] $MirrorMode
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-VerboseColor ("Skipping missing source: {0}" -f $Source) 'Yellow'
        return
    }

    $robocopyCmd = Get-Command robocopy -ErrorAction SilentlyContinue
    if ($null -ne $robocopyCmd) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null

        $mode = if ($MirrorMode) { '/MIR' } else { '/E' }
        $args = @(
            $Source,
            $Destination,
            $mode,
            '/R:2',
            '/W:1',
            '/NFL',
            '/NDL',
            '/NJH',
            '/NJS'
        )

        & robocopy @args | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed for '$Source' -> '$Destination' (exit code: $LASTEXITCODE)"
        }

        Write-VerboseColor ("Synced with robocopy: {0} -> {1}" -f $Source, $Destination) 'Gray'
        return
    }

    Write-VerboseColor 'robocopy not found; using Copy-Item fallback sync.' 'Yellow'
    Invoke-FallbackSync -Source $Source -Destination $Destination -MirrorMode:$MirrorMode
    Write-VerboseColor ("Synced with fallback copy: {0} -> {1}" -f $Source, $Destination) 'Gray'
}

function Invoke-McpConfigApply {
    param(
        [string] $ResolvedRepoRoot,
        [string] $CodexPath,
        [switch] $CreateBackup
    )

    $syncScript = Join-Path $ResolvedRepoRoot '.codex\scripts\sync-mcp-to-codex-config.ps1'
    $manifest = Join-Path $ResolvedRepoRoot '.codex\mcp\servers.manifest.json'
    $targetConfig = Join-Path $CodexPath 'config.toml'

    Assert-PathExists -Path $syncScript -Label 'MCP sync script'
    Assert-PathExists -Path $manifest -Label 'MCP manifest'
    Assert-PathExists -Path $targetConfig -Label 'target Codex config'

    $syncArgs = @{
        ManifestPath = $manifest
        TargetConfigPath = $targetConfig
    }

    if ($CreateBackup) {
        $syncArgs.CreateBackup = $true
    }

    & $syncScript @syncArgs
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot

$sourceGithub = Join-Path $resolvedRepoRoot '.github'
$sourceCodex = Join-Path $resolvedRepoRoot '.codex'

Assert-PathExists -Path $sourceGithub -Label 'source .github folder'
Assert-PathExists -Path $sourceCodex -Label 'source .codex folder'

Invoke-DirectorySync -Source $sourceGithub -Destination $TargetGithubPath -MirrorMode:$Mirror
Invoke-DirectorySync -Source (Join-Path $sourceCodex 'skills') -Destination (Join-Path $TargetCodexPath 'skills') -MirrorMode:$Mirror
Invoke-DirectorySync -Source (Join-Path $sourceCodex 'mcp') -Destination (Join-Path $TargetCodexPath 'shared-mcp') -MirrorMode:$Mirror
Invoke-DirectorySync -Source (Join-Path $sourceCodex 'scripts') -Destination (Join-Path $TargetCodexPath 'shared-scripts') -MirrorMode:$Mirror

$sharedReadme = Join-Path $sourceCodex 'README.md'
if (Test-Path -LiteralPath $sharedReadme) {
    New-Item -ItemType Directory -Path $TargetCodexPath -Force | Out-Null
    Copy-Item -LiteralPath $sharedReadme -Destination (Join-Path $TargetCodexPath 'README.shared.md') -Force
}

Write-Host 'Sync complete.' -ForegroundColor Green
Write-Host ("  .github -> {0}" -f $TargetGithubPath)
Write-Host ("  .codex/skills -> {0}" -f (Join-Path $TargetCodexPath 'skills'))
Write-Host ("  .codex/mcp -> {0}" -f (Join-Path $TargetCodexPath 'shared-mcp'))
Write-Host ("  .codex/scripts -> {0}" -f (Join-Path $TargetCodexPath 'shared-scripts'))

if ($ApplyMcpConfig) {
    Invoke-McpConfigApply -ResolvedRepoRoot $resolvedRepoRoot -CodexPath $TargetCodexPath -CreateBackup:$BackupConfig
}