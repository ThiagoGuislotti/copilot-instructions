<#
.SYNOPSIS
    Runtime tests for repository-managed global Git aliases.

.DESCRIPTION
    Verifies that the global `git trim-eof` alias can be configured against an
    isolated global Git config, points at the runtime-synced trim script, and
    successfully trims changed files in a temporary Git repository.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/git-global-aliases.tests.ps1

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

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$bootstrapScriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'
$setupScriptPath = Join-Path $resolvedRepoRoot 'scripts/git-hooks/setup-global-git-aliases.ps1'

try {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $globalGitConfigPath = Join-Path $tempRoot 'global.gitconfig'
    $runtimeGithubPath = Join-Path $tempRoot '.github'
    $runtimeCodexPath = Join-Path $tempRoot '.codex'
    $runtimeAgentsSkillsPath = Join-Path $tempRoot '.agents\skills'
    $runtimeCopilotSkillsPath = Join-Path $tempRoot '.copilot\skills'
    $gitRepoRoot = Join-Path $tempRoot 'git-repo'
    $changedFile = Join-Path $gitRepoRoot 'changed.cs'
    $originalGitConfigGlobal = $env:GIT_CONFIG_GLOBAL

    try {
        $env:GIT_CONFIG_GLOBAL = $globalGitConfigPath

        & $bootstrapScriptPath `
            -RepoRoot $resolvedRepoRoot `
            -TargetGithubPath $runtimeGithubPath `
            -TargetCodexPath $runtimeCodexPath `
            -TargetAgentsSkillsPath $runtimeAgentsSkillsPath `
            -TargetCopilotSkillsPath $runtimeCopilotSkillsPath | Out-Null
        Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'bootstrap must succeed for global alias runtime test.'

        & $setupScriptPath -RepoRoot $resolvedRepoRoot -TargetCodexPath $runtimeCodexPath | Out-Null
        Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'setup-global-git-aliases must configure aliases successfully.'

        $configuredAlias = & git config --global --get alias.trim-eof
        Assert-True (-not [string]::IsNullOrWhiteSpace([string] $configuredAlias)) 'Global trim-eof alias must be configured.'
        Assert-True ($configuredAlias -match 'trim-trailing-blank-lines\.ps1') 'Global trim-eof alias must point at the runtime-synced trim script.'

        New-Item -ItemType Directory -Path $gitRepoRoot -Force | Out-Null
        & git -C $gitRepoRoot init | Out-Null
        & git -C $gitRepoRoot config user.name 'Test User' | Out-Null
        & git -C $gitRepoRoot config user.email 'test@example.com' | Out-Null

        Write-TextFile -Path $changedFile -Content 'public sealed class Changed { }'
        & git -C $gitRepoRoot add changed.cs | Out-Null
        & git -C $gitRepoRoot commit -m 'initial' | Out-Null

        Write-TextFile -Path $changedFile -Content "public sealed class Changed { }`n`n"

        & git -C $gitRepoRoot trim-eof | Out-Null
        Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'git trim-eof must execute successfully.'
        Assert-Equal -Actual ([System.IO.File]::ReadAllText($changedFile)) -Expected 'public sealed class Changed { }' -Message 'git trim-eof must trim the changed tracked file.'

        & $setupScriptPath -RepoRoot $resolvedRepoRoot -TargetCodexPath $runtimeCodexPath -Uninstall | Out-Null
        Assert-Equal -Actual ([int] $LASTEXITCODE) -Expected 0 -Message 'setup-global-git-aliases -Uninstall must succeed.'
        $removedAlias = & git config --global --get alias.trim-eof 2>$null
        Assert-True ([string]::IsNullOrWhiteSpace([string] $removedAlias)) 'Global trim-eof alias must be removed by uninstall.'
    }
    finally {
        if ($null -eq $originalGitConfigGlobal) {
            Remove-Item Env:GIT_CONFIG_GLOBAL -ErrorAction SilentlyContinue
        }
        else {
            $env:GIT_CONFIG_GLOBAL = $originalGitConfigGlobal
        }

        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host '[OK] git global aliases tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] git global aliases tests failed: {0}" -f $_.Exception.Message)
    exit 1
}