<#
.SYNOPSIS
    Runtime tests for local Git hook EOF hygiene mode handling.

.DESCRIPTION
    Verifies that:
    - local Git hook setup persists the selected EOF hygiene mode per clone/worktree
    - global Git hook setup persists the selected mode once for reuse across repositories
    - `manual` mode leaves staged files untouched during pre-commit
    - `autofix` trims and re-stages safe staged files during pre-commit
    - `autofix` blocks when a file has both staged and unstaged changes
    - local settings override the inherited global mode

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/git-hook-eof-hygiene.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git.
#>

param(
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
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
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

# Fails the current test when the actual and expected values differ.
function Assert-Equal {
    param(
        [object] $Actual,
        [object] $Expected,
        [string] $Message
    )

    if ($Actual -ne $Expected) {
        throw ("{0} Expected='{1}' Actual='{2}'" -f $Message, $Expected, $Actual)
    }
}

# Writes deterministic UTF-8 test content to disk.
function Write-TextFile {
    param(
        [string] $Path,
        [string] $Content
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# Initializes a deterministic temporary git repository for runtime tests.
function Initialize-GitRepository {
    param(
        [string] $Path
    )

    & git -C $Path init | Out-Null
    & git -C $Path config user.name 'Test User' | Out-Null
    & git -C $Path config user.email 'test@example.com' | Out-Null
}

# Copies a versioned repository file into a temporary test repository.
function Copy-RepoFile {
    param(
        [string] $SourceRepoRoot,
        [string] $TargetRepoRoot,
        [string] $RelativePath
    )

    $sourcePath = Join-Path $SourceRepoRoot $RelativePath
    $targetPath = Join-Path $TargetRepoRoot $RelativePath
    $targetParent = Split-Path -Path $targetPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}

# Creates a minimal repository layout able to execute the local EOF hook runner.
function New-MinimalHookTestRepository {
    param(
        [string] $SourceRepoRoot,
        [string] $TargetRepoRoot
    )

    New-Item -ItemType Directory -Path $TargetRepoRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $TargetRepoRoot '.github') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $TargetRepoRoot '.codex') -Force | Out-Null

    foreach ($relativePath in @(
        '.github\governance\git-hook-eof-modes.json',
        'scripts\common\common-bootstrap.ps1',
        'scripts\common\console-style.ps1',
        'scripts\common\repository-paths.ps1',
        'scripts\common\git-hook-eof-settings.ps1',
        'scripts\maintenance\trim-trailing-blank-lines.ps1',
        'scripts\git-hooks\setup-git-hooks.ps1',
        'scripts\git-hooks\invoke-pre-commit-eof-hygiene.ps1'
    )) {
        Copy-RepoFile -SourceRepoRoot $SourceRepoRoot -TargetRepoRoot $TargetRepoRoot -RelativePath $relativePath
    }

    $hooksRoot = Join-Path $TargetRepoRoot '.githooks'
    New-Item -ItemType Directory -Path $hooksRoot -Force | Out-Null
    foreach ($hookName in @('pre-commit', 'post-commit', 'post-merge', 'post-checkout')) {
        Set-Content -LiteralPath (Join-Path $hooksRoot $hookName) -Value "#!/usr/bin/env sh`nexit 0`n" -NoNewline
    }

    Initialize-GitRepository -Path $TargetRepoRoot
}

# Executes a PowerShell script as a child process and returns exit code plus output.
function Invoke-PowerShellScript {
    param(
        [string] $ScriptPath,
        [string[]] $Arguments = @()
    )

    $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    $output = & $pwshPath -NoLogo -NoProfile -File $ScriptPath @Arguments 2>&1
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$setupScriptPath = Join-Path $resolvedRepoRoot 'scripts/git-hooks/setup-git-hooks.ps1'
$runnerScriptPath = Join-Path $resolvedRepoRoot 'scripts/git-hooks/invoke-pre-commit-eof-hygiene.ps1'

try {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $previousGlobalSettingsOverride = $env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH
    $previousGlobalHooksPathOverride = $env:CODEX_GIT_HOOKS_PATH
    $previousGitConfigGlobal = $env:GIT_CONFIG_GLOBAL
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'global') -Force | Out-Null
    $env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH = Join-Path $tempRoot 'global\git-hook-eof-settings.json'
    $env:CODEX_GIT_HOOKS_PATH = Join-Path $tempRoot 'global-hooks'
    $env:GIT_CONFIG_GLOBAL = Join-Path $tempRoot 'global\.gitconfig'
    try {
        $manualRepoRoot = Join-Path $tempRoot 'manual-repo'
        New-MinimalHookTestRepository -SourceRepoRoot $resolvedRepoRoot -TargetRepoRoot $manualRepoRoot

        $manualSetup = Invoke-PowerShellScript -ScriptPath $setupScriptPath -Arguments @('-RepoRoot', $manualRepoRoot, '-EofHygieneMode', 'manual')
        Assert-Equal -Actual $manualSetup.ExitCode -Expected 0 -Message 'setup-git-hooks must succeed for manual mode.'

        $manualSettingsPath = Join-Path $manualRepoRoot '.git\codex-hook-eof-settings.json'
        $manualSettings = Get-Content -Raw -LiteralPath $manualSettingsPath | ConvertFrom-Json -Depth 20
        Assert-Equal -Actual $manualSettings.selectedMode -Expected 'manual' -Message 'Manual mode setup must persist the selected local EOF mode.'

        $manualFile = Join-Path $manualRepoRoot 'manual.cs'
        Write-TextFile -Path $manualFile -Content 'public sealed class Manual { }'
        & git -C $manualRepoRoot add manual.cs | Out-Null
        & git -C $manualRepoRoot commit -m 'initial' | Out-Null

        Write-TextFile -Path $manualFile -Content "public sealed class Manual { public int Value => 1; }`n`n"
        & git -C $manualRepoRoot add manual.cs | Out-Null

        $manualRun = Invoke-PowerShellScript -ScriptPath $runnerScriptPath -Arguments @('-RepoRoot', $manualRepoRoot)
        Assert-Equal -Actual $manualRun.ExitCode -Expected 0 -Message 'Manual mode must allow pre-commit to continue.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($manualFile)) -Expected "public sealed class Manual { public int Value => 1; }`n`n" -Message 'Manual mode must not trim staged files automatically.'

        $autofixRepoRoot = Join-Path $tempRoot 'autofix-repo'
        New-MinimalHookTestRepository -SourceRepoRoot $resolvedRepoRoot -TargetRepoRoot $autofixRepoRoot

        $autofixSetup = Invoke-PowerShellScript -ScriptPath $setupScriptPath -Arguments @('-RepoRoot', $autofixRepoRoot, '-EofHygieneMode', 'autofix')
        Assert-Equal -Actual $autofixSetup.ExitCode -Expected 0 -Message 'setup-git-hooks must succeed for autofix mode.'

        $autofixSettingsPath = Join-Path $autofixRepoRoot '.git\codex-hook-eof-settings.json'
        $autofixSettings = Get-Content -Raw -LiteralPath $autofixSettingsPath | ConvertFrom-Json -Depth 20
        Assert-Equal -Actual $autofixSettings.selectedMode -Expected 'autofix' -Message 'Autofix mode setup must persist the selected local EOF mode.'

        $autofixFile = Join-Path $autofixRepoRoot 'autofix.cs'
        Write-TextFile -Path $autofixFile -Content 'public sealed class Autofix { }'
        & git -C $autofixRepoRoot add autofix.cs | Out-Null
        & git -C $autofixRepoRoot commit -m 'initial' | Out-Null

        Write-TextFile -Path $autofixFile -Content "public sealed class Autofix { public int Value => 1; }`n`n"
        & git -C $autofixRepoRoot add autofix.cs | Out-Null

        $autofixRun = Invoke-PowerShellScript -ScriptPath $runnerScriptPath -Arguments @('-RepoRoot', $autofixRepoRoot)
        Assert-Equal -Actual $autofixRun.ExitCode -Expected 0 -Message 'Autofix mode must allow safe staged-file trimming.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($autofixFile)) -Expected 'public sealed class Autofix { public int Value => 1; }' -Message 'Autofix mode must trim trailing EOF blank lines from safe staged files.'
        Assert-True -Condition ((@($autofixRun.Output) -join "`n") -match 'EOF autofix completed') -Message 'Autofix mode should report successful staged-file cleanup.'
        Assert-True -Condition ((@(& git -C $autofixRepoRoot diff --cached --name-only)) -contains 'autofix.cs') -Message 'Autofix mode must re-stage the trimmed file.'

        $mixedRepoRoot = Join-Path $tempRoot 'mixed-repo'
        New-MinimalHookTestRepository -SourceRepoRoot $resolvedRepoRoot -TargetRepoRoot $mixedRepoRoot

        $mixedSetup = Invoke-PowerShellScript -ScriptPath $setupScriptPath -Arguments @('-RepoRoot', $mixedRepoRoot, '-EofHygieneMode', 'autofix')
        Assert-Equal -Actual $mixedSetup.ExitCode -Expected 0 -Message 'setup-git-hooks must succeed for mixed-stage autofix test.'

        $mixedFile = Join-Path $mixedRepoRoot 'mixed.cs'
        Write-TextFile -Path $mixedFile -Content 'public sealed class Mixed { }'
        & git -C $mixedRepoRoot add mixed.cs | Out-Null
        & git -C $mixedRepoRoot commit -m 'initial' | Out-Null

        Write-TextFile -Path $mixedFile -Content "public sealed class Mixed { public int StagedValue => 1; }`n`n"
        & git -C $mixedRepoRoot add mixed.cs | Out-Null
        Write-TextFile -Path $mixedFile -Content "public sealed class Mixed { public int UnstagedValue => 2; }`n`n"

        $mixedRun = Invoke-PowerShellScript -ScriptPath $runnerScriptPath -Arguments @('-RepoRoot', $mixedRepoRoot)
        Assert-Equal -Actual $mixedRun.ExitCode -Expected 1 -Message 'Autofix mode must block when a file has mixed staged and unstaged changes.'
        Assert-True -Condition ((@($mixedRun.Output) -join "`n") -match 'EOF autofix blocked') -Message 'Autofix mode must explain the mixed-stage block clearly.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($mixedFile)) -Expected "public sealed class Mixed { public int UnstagedValue => 2; }`n`n" -Message 'Mixed-stage block must not rewrite the working tree file.'

        $globalRepoRoot = Join-Path $tempRoot 'global-repo'
        New-MinimalHookTestRepository -SourceRepoRoot $resolvedRepoRoot -TargetRepoRoot $globalRepoRoot

        $globalSetup = Invoke-PowerShellScript -ScriptPath $setupScriptPath -Arguments @('-RepoRoot', $globalRepoRoot, '-EofHygieneMode', 'autofix', '-EofHygieneScope', 'global')
        Assert-Equal -Actual $globalSetup.ExitCode -Expected 0 -Message 'setup-git-hooks must succeed for global autofix mode.'

        $globalSettingsPath = $env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH
        $globalSettings = Get-Content -Raw -LiteralPath $globalSettingsPath | ConvertFrom-Json -Depth 20
        Assert-Equal -Actual $globalSettings.selectedMode -Expected 'autofix' -Message 'Global mode setup must persist the selected EOF mode.'
        Assert-Equal -Actual $globalSettings.selectedScope -Expected 'global' -Message 'Global mode setup must persist the selected EOF scope.'
        Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $globalRepoRoot '.git\codex-hook-eof-settings.json') -PathType Leaf)) -Message 'Global mode setup must not leave a local override file behind.'
        $globalConfiguredHooksPath = (& git config --global --get core.hooksPath 2>$null)
        Assert-Equal -Actual ([System.IO.Path]::GetFullPath($globalConfiguredHooksPath.Trim())) -Expected ([System.IO.Path]::GetFullPath($env:CODEX_GIT_HOOKS_PATH)) -Message 'Global mode setup must configure global core.hooksPath to the managed global hooks path.'
        $globalLocalConfiguredHooksPath = (& git -C $globalRepoRoot config --local --get core.hooksPath 2>$null)
        Assert-True -Condition ([string]::IsNullOrWhiteSpace([string] $globalLocalConfiguredHooksPath)) -Message 'Global mode setup must not leave a local core.hooksPath override behind.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env:CODEX_GIT_HOOKS_PATH 'pre-commit') -PathType Leaf) -Message 'Global mode setup must install a managed pre-commit hook in the global hooks path.'

        $globalFile = Join-Path $globalRepoRoot 'global.cs'
        Write-TextFile -Path $globalFile -Content 'public sealed class GlobalMode { }'
        & git -C $globalRepoRoot add global.cs | Out-Null
        & git -C $globalRepoRoot commit -m 'initial' | Out-Null

        Write-TextFile -Path $globalFile -Content "public sealed class GlobalMode { public int Value => 1; }`n`n"
        & git -C $globalRepoRoot add global.cs | Out-Null

        $globalRun = Invoke-PowerShellScript -ScriptPath $runnerScriptPath -Arguments @('-RepoRoot', $globalRepoRoot)
        Assert-Equal -Actual $globalRun.ExitCode -Expected 0 -Message 'Global autofix mode must apply to the repository that configured it.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($globalFile)) -Expected 'public sealed class GlobalMode { public int Value => 1; }' -Message 'Global autofix mode must trim staged files for repositories without local overrides.'

        $inheritRepoRoot = Join-Path $tempRoot 'inherit-repo'
        New-MinimalHookTestRepository -SourceRepoRoot $resolvedRepoRoot -TargetRepoRoot $inheritRepoRoot
        $inheritSetup = Invoke-PowerShellScript -ScriptPath $setupScriptPath -Arguments @('-RepoRoot', $inheritRepoRoot)
        Assert-Equal -Actual $inheritSetup.ExitCode -Expected 0 -Message 'setup-git-hooks must succeed for inherited-global mode test.'

        $inheritFile = Join-Path $inheritRepoRoot 'inherit.cs'
        Write-TextFile -Path $inheritFile -Content 'public sealed class InheritMode { }'
        & git -C $inheritRepoRoot add inherit.cs | Out-Null
        & git -C $inheritRepoRoot commit -m 'initial' | Out-Null

        Write-TextFile -Path $inheritFile -Content "public sealed class InheritMode { public int Value => 1; }`n`n"
        & git -C $inheritRepoRoot add inherit.cs | Out-Null

        $inheritRun = Invoke-PowerShellScript -ScriptPath $runnerScriptPath -Arguments @('-RepoRoot', $inheritRepoRoot)
        Assert-Equal -Actual $inheritRun.ExitCode -Expected 0 -Message 'Repositories without local overrides must inherit the global autofix mode.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($inheritFile)) -Expected 'public sealed class InheritMode { public int Value => 1; }' -Message 'Inherited global autofix mode must trim staged files.'

        $overrideSetup = Invoke-PowerShellScript -ScriptPath $setupScriptPath -Arguments @('-RepoRoot', $inheritRepoRoot, '-EofHygieneMode', 'manual', '-EofHygieneScope', 'local-repo')
        Assert-Equal -Actual $overrideSetup.ExitCode -Expected 0 -Message 'setup-git-hooks must allow a local override on top of global settings.'

        Write-TextFile -Path $inheritFile -Content "public sealed class InheritMode { public int LocalOverride => 2; }`n`n"
        & git -C $inheritRepoRoot add inherit.cs | Out-Null

        $overrideRun = Invoke-PowerShellScript -ScriptPath $runnerScriptPath -Arguments @('-RepoRoot', $inheritRepoRoot)
        Assert-Equal -Actual $overrideRun.ExitCode -Expected 0 -Message 'Local manual override must still allow pre-commit to continue.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($inheritFile)) -Expected "public sealed class InheritMode { public int LocalOverride => 2; }`n`n" -Message 'Local override must win over the inherited global autofix mode.'
    }
    finally {
        if ([string]::IsNullOrWhiteSpace($previousGlobalSettingsOverride)) {
            Remove-Item Env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH -ErrorAction SilentlyContinue
        }
        else {
            $env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH = $previousGlobalSettingsOverride
        }

        if ([string]::IsNullOrWhiteSpace($previousGlobalHooksPathOverride)) {
            Remove-Item Env:CODEX_GIT_HOOKS_PATH -ErrorAction SilentlyContinue
        }
        else {
            $env:CODEX_GIT_HOOKS_PATH = $previousGlobalHooksPathOverride
        }

        if ([string]::IsNullOrWhiteSpace($previousGitConfigGlobal)) {
            Remove-Item Env:GIT_CONFIG_GLOBAL -ErrorAction SilentlyContinue
        }
        else {
            $env:GIT_CONFIG_GLOBAL = $previousGitConfigGlobal
        }

        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host '[OK] git hook EOF hygiene tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] git hook EOF hygiene tests failed: {0}" -f $_.Exception.Message)
    exit 1
}