<#
.SYNOPSIS
    Runtime tests for repository-owned Super Agent worktree isolation helpers.

.DESCRIPTION
    Validates the worktree creation helper and confirms isolated worktrees are
    discoverable through Git after creation.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/super-agent-worktree.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot
)

$ErrorActionPreference = 'Stop'

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths')
# Fails the current runtime test when the supplied condition is false.
function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) {
        throw $Message
    }
}

$resolvedRepoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path } else { (Resolve-Path $RepoRoot).Path }
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/new-super-agent-worktree.ps1'
$tempRoot = Join-Path $env:TEMP ('worktree-test-' + [guid]::NewGuid().ToString('N'))
$repoPath = Join-Path $tempRoot 'repo'

try {
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    & git -C $repoPath init | Out-Null
    & git -C $repoPath config user.email 'super-agent-test@example.invalid' | Out-Null
    & git -C $repoPath config user.name 'Super Agent Test' | Out-Null
    & git -C $repoPath config core.hooksPath '.git-hooks-disabled' | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repoPath '.git-hooks-disabled') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $repoPath 'README.md') -Value '# temp repo' -Encoding UTF8 -NoNewline
    & git -C $repoPath add README.md | Out-Null
    & git -C $repoPath commit -m 'init' | Out-Null

    $previewJson = & $scriptPath -RepoRoot $repoPath -WorktreeName 'Feature Planning' -PreviewOnly
    $preview = $previewJson | ConvertFrom-Json -Depth 50
    Assert-True ($preview.branchName -eq 'super/feature-planning') 'Preview should derive a deterministic branch name.'
    Assert-True ($preview.worktreePath -match 'feature-planning') 'Preview should derive a slugged worktree path.'

    $resultJson = & $scriptPath -RepoRoot $repoPath -WorktreeName 'Feature Planning'
    $result = $resultJson | ConvertFrom-Json -Depth 50
    Assert-True ([bool] $result.created) 'Worktree creation should report success.'
    Assert-True (Test-Path -LiteralPath ([string] $result.worktreePath) -PathType Container) 'Worktree path should exist after creation.'

    $worktreeList = @(git -C $repoPath worktree list --porcelain) -join "`n"
    $normalizedWorktreeList = $worktreeList -replace '\\', '/'
    $normalizedReportedPath = ([string] $result.worktreePath) -replace '\\', '/'
    Assert-True ($normalizedWorktreeList -match [regex]::Escape($normalizedReportedPath)) 'git worktree list should include the created worktree.'

    Write-Host '[OK] super-agent worktree tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] super-agent worktree tests failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}