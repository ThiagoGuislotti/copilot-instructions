[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$TargetGithubPath = "$env:USERPROFILE\.github",
    [string]$TargetCodexPath = "$env:USERPROFILE\.codex",
    [switch]$Mirror,
    [switch]$ApplyMcpConfig,
    [switch]$BackupConfig
)

$ErrorActionPreference = "Stop"

function Invoke-RobocopySync {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [switch]$Mirror
    )

    if (!(Test-Path $Source)) {
        return
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $mode = if ($Mirror) { "/MIR" } else { "/E" }
    $args = @(
        $Source,
        $Destination,
        $mode,
        "/R:2",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS"
    )

    & robocopy @args | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed for '$Source' -> '$Destination' (exit code: $LASTEXITCODE)"
    }
}

$sourceGithub = Join-Path $RepoRoot ".github"
$sourceCodex = Join-Path $RepoRoot ".codex"

if (!(Test-Path $sourceGithub)) {
    throw "Missing source folder: $sourceGithub"
}

if (!(Test-Path $sourceCodex)) {
    throw "Missing source folder: $sourceCodex"
}

Invoke-RobocopySync -Source $sourceGithub -Destination $TargetGithubPath -Mirror:$Mirror
Invoke-RobocopySync -Source (Join-Path $sourceCodex "skills") -Destination (Join-Path $TargetCodexPath "skills") -Mirror:$Mirror
Invoke-RobocopySync -Source (Join-Path $sourceCodex "mcp") -Destination (Join-Path $TargetCodexPath "shared-mcp") -Mirror:$Mirror
Invoke-RobocopySync -Source (Join-Path $sourceCodex "scripts") -Destination (Join-Path $TargetCodexPath "shared-scripts") -Mirror:$Mirror

$sharedReadme = Join-Path $sourceCodex "README.md"
if (Test-Path $sharedReadme) {
    New-Item -ItemType Directory -Path $TargetCodexPath -Force | Out-Null
    Copy-Item $sharedReadme (Join-Path $TargetCodexPath "README.shared.md") -Force
}

Write-Host "Sync complete."
Write-Host "  .github -> $TargetGithubPath"
Write-Host "  .codex/skills -> $(Join-Path $TargetCodexPath 'skills')"
Write-Host "  .codex/mcp -> $(Join-Path $TargetCodexPath 'shared-mcp')"
Write-Host "  .codex/scripts -> $(Join-Path $TargetCodexPath 'shared-scripts')"

if ($ApplyMcpConfig) {
    $syncScript = Join-Path $RepoRoot ".codex\scripts\sync-mcp-to-codex-config.ps1"
    $manifest = Join-Path $RepoRoot ".codex\mcp\servers.manifest.json"
    $targetConfig = Join-Path $TargetCodexPath "config.toml"

    if (!(Test-Path $syncScript)) {
        throw "Missing script: $syncScript"
    }

    if (!(Test-Path $targetConfig)) {
        throw "Target config not found: $targetConfig"
    }

    $args = @{
        ManifestPath = $manifest
        TargetConfigPath = $targetConfig
    }
    if ($BackupConfig) {
        $args.CreateBackup = $true
    }

    & $syncScript @args
}
