<#
.SYNOPSIS
    Creates a deterministic git worktree for isolated Super Agent execution.

.DESCRIPTION
    Uses repository-owned defaults to create a Windows-safe worktree outside the
    main checkout without destructive cleanup behavior.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected with Git when omitted.

.PARAMETER WorktreeName
    Human-readable workstream name used to derive the slug and default branch.

.PARAMETER BranchName
    Optional branch name override. Defaults to `super/<slug>`.

.PARAMETER WorktreeRoot
    Optional parent directory where new worktrees are created.

.PARAMETER BaseRef
    Base Git ref used when creating a new branch.

.PARAMETER PreviewOnly
    Emits the planned JSON payload without creating the worktree.

.PARAMETER DetailedOutput
    Enables verbose diagnostics.

.EXAMPLE
    pwsh -File .\scripts\runtime\new-super-agent-worktree.ps1 -RepoRoot . -WorktreeName "Parallel Refactor" -PreviewOnly

.NOTES
    The script never prunes or removes worktrees automatically.
#>

[CmdletBinding()]
param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $WorktreeName,
    [string] $BranchName,
    [string] $WorktreeRoot,
    [string] $BaseRef = 'HEAD',
    [switch] $PreviewOnly,
    [switch] $DetailedOutput
)

Set-StrictMode -Version Latest
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
$script:IsVerboseEnabled = [bool] $DetailedOutput

$script:IsDetailedOutputEnabled = [bool] $DetailedOutput
# Converts a human-readable worktree name into a deterministic slug.
function Convert-ToSlug {
    param([string] $Value)

    $slug = ($Value ?? '').ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'WorktreeName must contain at least one alphanumeric character.'
    }

    return $slug
}

$resolvedRepoRoot = Resolve-ExplicitOrGitRoot -RequestedRoot $RepoRoot
$repoName = Split-Path -Path $resolvedRepoRoot -Leaf
$slug = Convert-ToSlug -Value $WorktreeName
$effectiveBranchName = if ([string]::IsNullOrWhiteSpace($BranchName)) { "super/$slug" } else { $BranchName.Trim() }
$effectiveWorktreeRoot = if ([string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    Join-Path (Split-Path -Path $resolvedRepoRoot -Parent) 'worktrees'
}
else {
    [System.IO.Path]::GetFullPath($WorktreeRoot)
}
$worktreePath = Join-Path $effectiveWorktreeRoot ("{0}-{1}" -f $repoName, $slug)

if (Test-Path -LiteralPath $worktreePath) {
    throw ("Worktree path already exists: {0}" -f $worktreePath)
}

$branchExists = $false
& git -C $resolvedRepoRoot rev-parse --verify --quiet ("refs/heads/{0}" -f $effectiveBranchName) *> $null
if ($LASTEXITCODE -eq 0) {
    $branchExists = $true
}

$gitArgs = @('worktree', 'add')
$gitArgs += '--quiet'
if (-not $branchExists) {
    $gitArgs += '-b'
    $gitArgs += $effectiveBranchName
    $gitArgs += $worktreePath
    $gitArgs += $BaseRef
}
else {
    $gitArgs += $worktreePath
    $gitArgs += $effectiveBranchName
}

$result = [ordered]@{
    repoRoot = $resolvedRepoRoot
    repoName = $repoName
    worktreeName = $WorktreeName
    worktreeSlug = $slug
    branchName = $effectiveBranchName
    branchAlreadyExists = $branchExists
    baseRef = $BaseRef
    worktreeRoot = $effectiveWorktreeRoot
    worktreePath = $worktreePath
    previewOnly = [bool] $PreviewOnly
    command = @('git', '-C', $resolvedRepoRoot) + $gitArgs
    notes = @(
        'No destructive Git cleanup is performed automatically.',
        'Worktree root is kept outside the main checkout by default.'
    )
}

if ($PreviewOnly) {
    $result | ConvertTo-Json -Depth 20
    exit 0
}

New-Item -ItemType Directory -Path $effectiveWorktreeRoot -Force | Out-Null
Write-VerboseLog ("Creating worktree at {0}" -f $worktreePath)
$null = & git -C $resolvedRepoRoot @gitArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw ("git worktree add failed for {0}" -f $worktreePath)
}

$result['created'] = $true
$result | ConvertTo-Json -Depth 20
exit 0