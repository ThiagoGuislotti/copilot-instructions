<#
.SYNOPSIS
    Configures repository-local or machine-global Git hooks for the repository-owned hook runtime.

.DESCRIPTION
    Local-repo scope sets `core.hooksPath=.githooks` for this repository and
    verifies the repository-owned hook files:
    - pre-commit
    - post-commit
    - post-merge
    - post-checkout

    Global scope sets `git config --global core.hooksPath` to a managed
    directory under `%USERPROFILE%\.codex\git-hooks` and installs a shared
    `pre-commit` hook there for EOF hygiene across repositories.

    The effective EOF hygiene mode itself is still resolved from the versioned
    mode catalog and the persisted local/global mode selection.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script detects root from script location.

.PARAMETER EofHygieneMode
    EOF hygiene mode for this clone/worktree or the machine, depending on the
    selected scope. Supported values are defined in
    `.github/governance/git-hook-eof-modes.json`.

.PARAMETER EofHygieneScope
    Scope for persisting the EOF hygiene mode selection. Supported values are
    defined in `.github/governance/git-hook-eof-modes.json`.

.PARAMETER Uninstall
    Removes the selected local or global `core.hooksPath` configuration instead
    of setting it.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope local-repo

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope global

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1 -Uninstall -EofHygieneScope global

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git.
#>

param(
    [string] $RepoRoot,
    [string] $EofHygieneMode,
    [string] $EofHygieneScope,
    [switch] $Uninstall,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'git-hook-eof-settings')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

# Validates that a required command is available in the current environment.
function Assert-CommandAvailable {
    param(
        [string] $CommandName
    )

    if ($null -eq (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw ("Required command not found: {0}" -f $CommandName)
    }
}

# Validates that a required file path exists before execution continues.
function Assert-PathPresent {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw ("Missing {0}: {1}" -f $Label, $Path)
    }
}

# Applies executable permission to hook files on Unix-like systems.
function Invoke-HookExecutabilityUpdate {
    param(
        [string[]] $HookPaths
    )

    if (-not ($IsLinux -or $IsMacOS)) {
        return
    }

    foreach ($hookPath in $HookPaths) {
        & chmod +x $hookPath
        if ($LASTEXITCODE -ne 0) {
            throw ("Failed to set executable permission: {0}" -f $hookPath)
        }
    }
}

# Converts a Windows path to a shell-safe absolute path with forward slashes.
function Convert-ToShellPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    return ([System.IO.Path]::GetFullPath($Path)).Replace('\', '/')
}

# Resolves the managed local hook file list.
function Get-ManagedLocalHookPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $hooksDirectory = Join-Path $ResolvedRepoRoot '.githooks'
    if (-not (Test-Path -LiteralPath $hooksDirectory -PathType Container)) {
        throw ("Missing hook directory: {0}" -f $hooksDirectory)
    }

    $hookNames = @('pre-commit', 'post-commit', 'post-merge', 'post-checkout')
    $hookPaths = New-Object System.Collections.Generic.List[string]
    foreach ($hookName in $hookNames) {
        $hookPath = Join-Path $hooksDirectory $hookName
        Assert-PathPresent -Path $hookPath -Label ("hook file '{0}'" -f $hookName)
        $hookPaths.Add($hookPath) | Out-Null
    }

    return [pscustomobject]@{
        HooksDirectory = $hooksDirectory
        HookPaths = @($hookPaths)
    }
}

# Resolves the managed global Git hook support paths.
function Get-ManagedGlobalGitHookPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceRepoRoot
    )

    $globalHooksPath = Resolve-CodexGitHooksPath
    $runtimeGithubPath = Resolve-GithubRuntimePath
    $runtimeRunnerPath = Join-Path (Join-Path (Join-Path $runtimeGithubPath 'scripts') 'git-hooks') 'invoke-pre-commit-eof-hygiene.ps1'
    $runtimeCatalogPath = Join-Path (Join-Path $runtimeGithubPath 'governance') 'git-hook-eof-modes.json'
    $runtimeTrimScriptPath = Join-Path (Join-Path (Resolve-CodexSharedScriptsPath) 'maintenance') 'trim-trailing-blank-lines.ps1'

    $repoRunnerPath = Join-Path (Join-Path (Join-Path $SourceRepoRoot 'scripts') 'git-hooks') 'invoke-pre-commit-eof-hygiene.ps1'
    $repoCatalogPath = Join-Path (Join-Path $SourceRepoRoot '.github') 'governance/git-hook-eof-modes.json'
    $repoTrimScriptPath = Join-Path (Join-Path (Join-Path $SourceRepoRoot 'scripts') 'maintenance') 'trim-trailing-blank-lines.ps1'

    return [pscustomobject]@{
        GlobalHooksPath = $globalHooksPath
        RunnerPath = if (Test-Path -LiteralPath $runtimeRunnerPath -PathType Leaf) { $runtimeRunnerPath } else { $repoRunnerPath }
        CatalogPath = if (Test-Path -LiteralPath $runtimeCatalogPath -PathType Leaf) { $runtimeCatalogPath } else { $repoCatalogPath }
        TrimScriptPath = if (Test-Path -LiteralPath $runtimeTrimScriptPath -PathType Leaf) { $runtimeTrimScriptPath } else { $repoTrimScriptPath }
    }
}

# Builds the managed global pre-commit shell hook content.
function Get-ManagedGlobalPreCommitHookContent {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RunnerPath,
        [Parameter(Mandatory = $true)]
        [string] $CatalogPath,
        [Parameter(Mandatory = $true)]
        [string] $TrimScriptPath
    )

    $runnerShellPath = Convert-ToShellPath -Path $RunnerPath
    $catalogShellPath = Convert-ToShellPath -Path $CatalogPath
    $trimShellPath = Convert-ToShellPath -Path $TrimScriptPath

    return (@'
#!/usr/bin/env sh
set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

export CODEX_GIT_HOOK_EOF_CATALOG_PATH='{1}'
export CODEX_GIT_HOOK_EOF_TRIM_SCRIPT_PATH='{2}'

if command -v pwsh >/dev/null 2>&1; then
  if ! pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File '{0}' -RepoRoot "$REPO_ROOT"; then
    echo "[pre-commit] Error: EOF hygiene hook failed." >&2
    exit 1
  fi
  exit 0
fi

if command -v powershell >/dev/null 2>&1; then
  if ! powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File '{0}' -RepoRoot "$REPO_ROOT"; then
    echo "[pre-commit] Error: EOF hygiene hook failed." >&2
    exit 1
  fi
  exit 0
fi

echo "[pre-commit] Warning: PowerShell not found. EOF hygiene skipped." >&2
exit 0
'@ -f $runnerShellPath, $catalogShellPath, $trimShellPath)
}

# Writes the managed global pre-commit hook into the configured global hooks path.
function Install-ManagedGlobalGitHooks {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceRepoRoot
    )

    $managedPaths = Get-ManagedGlobalGitHookPaths -SourceRepoRoot $SourceRepoRoot
    Assert-PathPresent -Path $managedPaths.RunnerPath -Label 'managed global pre-commit runner'
    Assert-PathPresent -Path $managedPaths.CatalogPath -Label 'managed global EOF mode catalog'
    Assert-PathPresent -Path $managedPaths.TrimScriptPath -Label 'managed global trim script'

    New-Item -ItemType Directory -Path $managedPaths.GlobalHooksPath -Force | Out-Null
    $preCommitPath = Join-Path $managedPaths.GlobalHooksPath 'pre-commit'
    [System.IO.File]::WriteAllText($preCommitPath, (Get-ManagedGlobalPreCommitHookContent -RunnerPath $managedPaths.RunnerPath -CatalogPath $managedPaths.CatalogPath -TrimScriptPath $managedPaths.TrimScriptPath), [System.Text.UTF8Encoding]::new($false))
    Invoke-HookExecutabilityUpdate -HookPaths @($preCommitPath)

    return [pscustomobject]@{
        GlobalHooksPath = $managedPaths.GlobalHooksPath
        PreCommitPath = $preCommitPath
        RunnerPath = $managedPaths.RunnerPath
        CatalogPath = $managedPaths.CatalogPath
        TrimScriptPath = $managedPaths.TrimScriptPath
    }
}

# Removes the managed global hook path when it is configured by this repository runtime.
function Uninstall-ManagedGlobalGitHooks {
    $managedGlobalHooksPath = Resolve-CodexGitHooksPath
    $currentGlobalHooksPath = (& git config --global --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($currentGlobalHooksPath)) {
        $resolvedCurrentGlobalHooksPath = [System.IO.Path]::GetFullPath($currentGlobalHooksPath.Trim())
        $resolvedManagedGlobalHooksPath = [System.IO.Path]::GetFullPath($managedGlobalHooksPath)
        if ($resolvedCurrentGlobalHooksPath -ieq $resolvedManagedGlobalHooksPath) {
            & git config --global --unset core.hooksPath 2>$null
        }
    }

    if (Test-Path -LiteralPath $managedGlobalHooksPath -PathType Container) {
        Remove-Item -LiteralPath $managedGlobalHooksPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    return $managedGlobalHooksPath
}

# -------------------------------
# Main execution
# -------------------------------
$sourceRepoRoot = Resolve-RepositoryRoot -RequestedRoot $null
$resolvedRepoRoot = Resolve-ExplicitOrGitRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
Assert-CommandAvailable -CommandName 'git'
Start-ExecutionSession `
    -Name 'setup-git-hooks' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Requested scope' = $(if ([string]::IsNullOrWhiteSpace($EofHygieneScope)) { 'default(local-repo)' } else { $EofHygieneScope })
            'Requested mode' = $(if ([string]::IsNullOrWhiteSpace($EofHygieneMode)) { 'inherit' } else { $EofHygieneMode })
            'Uninstall' = [bool] $Uninstall
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

$gitRoot = (& git -C $resolvedRepoRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
    throw ("Current folder is not a Git repository: {0}" -f $resolvedRepoRoot)
}

$resolvedScope = if (-not [string]::IsNullOrWhiteSpace($EofHygieneScope)) {
    Resolve-GitHookEofScope -ResolvedRepoRoot $resolvedRepoRoot -ScopeName $EofHygieneScope
}
else {
    Resolve-GitHookEofScope -ResolvedRepoRoot $resolvedRepoRoot -ScopeName 'local-repo'
}

if ($Uninstall) {
    if ($resolvedScope.Name -eq 'global') {
        $removedGlobalHooksPath = Uninstall-ManagedGlobalGitHooks
        $removedSettingsPath = Remove-GitHookEofModeSelection -ResolvedRepoRoot $resolvedRepoRoot -ScopeName $resolvedScope.Name
        Write-StyledOutput 'Removed managed global Git hook path (core.hooksPath).'
        Write-StyledOutput ("  global core.hooksPath: {0}" -f $removedGlobalHooksPath)
        Write-StyledOutput ("  removed EOF hook settings ({0}): {1}" -f $resolvedScope.Name, $removedSettingsPath)
        Complete-ExecutionSession -Name 'setup-git-hooks' -Status 'passed' -Summary ([ordered]@{
                'Scope' = $resolvedScope.Name
                'Operation' = 'uninstall'
            }) | Out-Null
        exit 0
    }

    & git -C $resolvedRepoRoot config --local --unset core.hooksPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-StyledOutput 'No local core.hooksPath configured.'
        $removedSettingsPath = Remove-GitHookEofModeSelection -ResolvedRepoRoot $resolvedRepoRoot -ScopeName $resolvedScope.Name
        if (Test-Path -LiteralPath $removedSettingsPath -PathType Leaf) {
            Write-StyledOutput ("Warning: could not remove local EOF hook settings: {0}" -f $removedSettingsPath)
        }
        Complete-ExecutionSession -Name 'setup-git-hooks' -Status 'passed' -Summary ([ordered]@{
                'Scope' = $resolvedScope.Name
                'Operation' = 'uninstall'
            }) | Out-Null
        exit 0
    }

    $removedSettingsPath = Remove-GitHookEofModeSelection -ResolvedRepoRoot $resolvedRepoRoot -ScopeName $resolvedScope.Name
    Write-StyledOutput 'Removed local Git hook path (core.hooksPath).'
    Write-StyledOutput ("  removed EOF hook settings ({0}): {1}" -f $resolvedScope.Name, $removedSettingsPath)
    Complete-ExecutionSession -Name 'setup-git-hooks' -Status 'passed' -Summary ([ordered]@{
            'Scope' = $resolvedScope.Name
            'Operation' = 'uninstall'
        }) | Out-Null
    exit 0
}

$effectiveEofSelection = Get-EffectiveGitHookEofMode -ResolvedRepoRoot $resolvedRepoRoot
$shouldPersistEofSelection = (-not [string]::IsNullOrWhiteSpace($EofHygieneMode)) -or (-not [string]::IsNullOrWhiteSpace($EofHygieneScope))
$eofModeSelection = if ($shouldPersistEofSelection) {
    $targetModeName = if (-not [string]::IsNullOrWhiteSpace($EofHygieneMode)) { $EofHygieneMode } else { $effectiveEofSelection.Name }
    $selection = Set-GitHookEofModeSelection -ResolvedRepoRoot $resolvedRepoRoot -ModeName $targetModeName -ScopeName $resolvedScope.Name
    if ($selection.Scope.Name -eq 'global') {
        Remove-GitHookEofModeSelection -ResolvedRepoRoot $resolvedRepoRoot -ScopeName 'local-repo' | Out-Null
    }

    $selection
}
else {
    [pscustomobject]@{
        Mode = (Resolve-GitHookEofMode -ResolvedRepoRoot $resolvedRepoRoot -ModeName $effectiveEofSelection.Name)
        Scope = (Resolve-GitHookEofScope -ResolvedRepoRoot $resolvedRepoRoot -ScopeName $effectiveEofSelection.Scope)
        SettingsPath = $effectiveEofSelection.SettingsPath
        Source = $effectiveEofSelection.Source
    }
}

$configuredPath = $null
$preCommitDescription = $null
if ($eofModeSelection.Scope.Name -eq 'global') {
    $globalHookInstall = Install-ManagedGlobalGitHooks -SourceRepoRoot $sourceRepoRoot
    & git -C $resolvedRepoRoot config --local --unset core.hooksPath 2>$null
    & git config --global core.hooksPath $globalHookInstall.GlobalHooksPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to configure global Git hook path.'
    }

    $configuredPath = (& git config --global --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($configuredPath)) {
        throw 'Could not read configured global core.hooksPath.'
    }

    $preCommitDescription = ("{0} (EOF mode={1}; scope={2}; global managed hook)" -f $globalHookInstall.PreCommitPath, $eofModeSelection.Mode.Name, $eofModeSelection.Scope.Name)
}
else {
    $localHooks = Get-ManagedLocalHookPaths -ResolvedRepoRoot $resolvedRepoRoot
    & git -C $resolvedRepoRoot config --local core.hooksPath '.githooks'
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to configure local Git hook path.'
    }

    Invoke-HookExecutabilityUpdate -HookPaths $localHooks.HookPaths
    $configuredPath = (& git -C $resolvedRepoRoot config --local --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($configuredPath)) {
        throw 'Could not read configured local core.hooksPath.'
    }

    $preCommitDescription = (".githooks/pre-commit (EOF mode={0}; scope={1}; runs validate-all with profile=dev, warning-only, best effort)" -f $eofModeSelection.Mode.Name, $eofModeSelection.Scope.Name)
}

Write-StyledOutput 'Git hooks configured successfully.'
Write-StyledOutput ("  repo: {0}" -f $gitRoot)
Write-StyledOutput ("  core.hooksPath ({0}): {1}" -f $eofModeSelection.Scope.Name, $configuredPath)
Write-StyledOutput ("  pre-commit: {0}" -f $preCommitDescription)
if ($null -ne $eofModeSelection.SettingsPath) {
    Write-StyledOutput ("  EOF hook settings ({0}): {1}" -f $eofModeSelection.Scope.Name, $eofModeSelection.SettingsPath)
}
else {
    Write-StyledOutput ("  EOF hook settings source: {0}" -f $eofModeSelection.Source)
}

if ($eofModeSelection.Scope.Name -eq 'local-repo') {
    Write-StyledOutput '  post-commit: .githooks/post-commit (syncs effective runtime targets via scripts/runtime/bootstrap.ps1)'
    Write-StyledOutput '  post-merge: .githooks/post-merge (runs validate-all with profile=release, warning-only, best effort)'
    Write-StyledOutput '  post-checkout: .githooks/post-checkout (runs validate-all with profile=dev, warning-only, best effort)'
}
else {
    Write-StyledOutput '  post-commit/post-merge/post-checkout: not installed in global mode'
    Write-StyledOutput '  local repositories can still override the global hook path with `core.hooksPath=.githooks`'
}

Write-StyledOutput '  skip sync (temporary): set CODEX_SKIP_POST_COMMIT_SYNC=1'
Write-StyledOutput '  optional MCP apply on canonical MCP runtime changes: set CODEX_APPLY_MCP_ON_POST_COMMIT=1'
Write-StyledOutput '  MCP apply backup default: CODEX_BACKUP_MCP_CONFIG=1 (set 0 to disable backup)'
Complete-ExecutionSession -Name 'setup-git-hooks' -Status 'passed' -Summary ([ordered]@{
        'Scope' = $eofModeSelection.Scope.Name
        'Mode' = $eofModeSelection.Mode.Name
        'Configured path' = $configuredPath
    }) | Out-Null

exit 0