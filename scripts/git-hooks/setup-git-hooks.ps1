[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $RepoRoot)) {
    throw "Repository root not found: $RepoRoot"
}

Set-Location $RepoRoot

$gitRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
    throw "Current folder is not a Git repository: $RepoRoot"
}

if ($Uninstall) {
    & git config --local --unset core.hooksPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No local core.hooksPath configured."
        exit 0
    }

    Write-Host "Removed local Git hook path (core.hooksPath)." -ForegroundColor Yellow
    exit 0
}

$hooksDirectory = Join-Path $RepoRoot ".githooks"
$preCommitHook = Join-Path $hooksDirectory "pre-commit"
$postCommitHook = Join-Path $hooksDirectory "post-commit"
$postMergeHook = Join-Path $hooksDirectory "post-merge"
$postCheckoutHook = Join-Path $hooksDirectory "post-checkout"

if (!(Test-Path $hooksDirectory)) {
    New-Item -ItemType Directory -Path $hooksDirectory -Force | Out-Null
}

if (!(Test-Path $preCommitHook)) {
    throw "Missing required hook file: $preCommitHook"
}

if (!(Test-Path $postCommitHook)) {
    throw "Missing required hook file: $postCommitHook"
}

if (!(Test-Path $postMergeHook)) {
    throw "Missing required hook file: $postMergeHook"
}

if (!(Test-Path $postCheckoutHook)) {
    throw "Missing required hook file: $postCheckoutHook"
}

& git config --local core.hooksPath ".githooks"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure local Git hook path."
}

if ($IsLinux -or $IsMacOS) {
    & chmod +x $preCommitHook
    & chmod +x $postCommitHook
    & chmod +x $postMergeHook
    & chmod +x $postCheckoutHook
}

$configuredPath = (& git config --local --get core.hooksPath)
Write-Host "Git hooks configured successfully." -ForegroundColor Green
Write-Host "  repo: $gitRoot"
Write-Host "  core.hooksPath: $configuredPath"
Write-Host "  pre-commit: .githooks/pre-commit (runs scripts/validation/validate-instructions.ps1)"
Write-Host "  post-commit: .githooks/post-commit (syncs ~/.github and ~/.codex via scripts/runtime/bootstrap.ps1)"
Write-Host "  post-merge: .githooks/post-merge (runs scripts/validation/validate-instructions.ps1)"
Write-Host "  post-checkout: .githooks/post-checkout (runs scripts/validation/validate-instructions.ps1)"
Write-Host "  skip sync (temporary): set CODEX_SKIP_POST_COMMIT_SYNC=1"
Write-Host "  optional MCP apply on manifest change: set CODEX_APPLY_MCP_ON_POST_COMMIT=1"
Write-Host "  MCP apply backup default: CODEX_BACKUP_MCP_CONFIG=1 (set 0 to disable backup)"