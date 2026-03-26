<#
.SYNOPSIS
    Configures global Git aliases for repository-owned helper tools.

.DESCRIPTION
    Registers manual global Git aliases that point at runtime-synced helper
    scripts under the local Codex shared-scripts path.

    Current aliases:
    - `trim-eof` -> runs the runtime-synced trim script in `-GitChangedOnly`
      mode so changed files can be normalized manually before `git add`

    This script does not install any automatic cleanup hook.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script detects root from script location.

.PARAMETER TargetCodexPath
    Optional Codex runtime root. Defaults to `<user-home>/.codex`.

.PARAMETER Uninstall
    Removes the managed global aliases instead of configuring them.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-global-git-aliases.ps1

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-global-git-aliases.ps1 -Uninstall

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git.
#>

param(
    [string] $RepoRoot,
    [string] $TargetCodexPath,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths')
$script:IsVerboseEnabled = [bool] $Verbose

# Validates that a required command exists in PATH.
function Assert-CommandAvailable {
    param(
        [string] $CommandName
    )

    if ($null -eq (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw ("Required command not found: {0}" -f $CommandName)
    }
}

# Builds the managed global Git alias map for the current platform/runtime.
function Get-ManagedGlobalGitAliases {
    param(
        [string] $CodexRuntimeRoot
    )

    $sharedScriptsPath = Join-Path $CodexRuntimeRoot 'shared-scripts'
    $trimScriptPath = Join-Path (Join-Path $sharedScriptsPath 'maintenance') 'trim-trailing-blank-lines.ps1'

    if (-not (Test-Path -LiteralPath $trimScriptPath -PathType Leaf)) {
        throw ("Missing runtime-synced trim script: {0}. Run scripts/runtime/bootstrap.ps1 first." -f $trimScriptPath)
    }

    $trimScriptShellPath = $trimScriptPath.Replace('\', '/')
    $trimAliasCommand = ('!pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ''{0}'' -GitChangedOnly' -f $trimScriptShellPath)

    return [ordered]@{
        'trim-eof' = $trimAliasCommand
    }
}

$null = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Assert-CommandAvailable -CommandName 'git'
Start-ExecutionSession `
    -Name 'setup-global-git-aliases' `
    -Metadata ([ordered]@{
            'Uninstall' = [bool] $Uninstall
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

if ([string]::IsNullOrWhiteSpace($TargetCodexPath)) {
    $TargetCodexPath = Resolve-CodexRuntimePath
}

$aliasMap = Get-ManagedGlobalGitAliases -CodexRuntimeRoot $TargetCodexPath

if ($Uninstall) {
    foreach ($aliasName in $aliasMap.Keys) {
        & git config --global --unset-all ("alias.{0}" -f $aliasName) 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-StyledOutput ("Removed global Git alias: git {0}" -f $aliasName)
        }
        else {
            Write-StyledOutput ("Global Git alias not configured: git {0}" -f $aliasName)
        }
    }

    Complete-ExecutionSession -Name 'setup-global-git-aliases' -Status 'passed' -Summary ([ordered]@{
            'Alias count' = $aliasMap.Count
            'Operation' = 'uninstall'
        }) | Out-Null
    exit 0
}

foreach ($aliasName in $aliasMap.Keys) {
    & git config --global ("alias.{0}" -f $aliasName) $aliasMap[$aliasName]
    if ($LASTEXITCODE -ne 0) {
        throw ("Failed to configure global Git alias: git {0}" -f $aliasName)
    }
}

Write-StyledOutput 'Global Git aliases configured successfully.'
foreach ($aliasName in $aliasMap.Keys) {
    Write-StyledOutput ("  git {0}" -f $aliasName)
    Write-StyledOutput ("    {0}" -f (& git config --global --get ("alias.{0}" -f $aliasName)))
}
Write-StyledOutput '  usage: run `git trim-eof` manually before `git add` when you want to normalize changed files.'
Complete-ExecutionSession -Name 'setup-global-git-aliases' -Status 'passed' -Summary ([ordered]@{
        'Alias count' = $aliasMap.Count
        'Codex runtime root' = $TargetCodexPath
    }) | Out-Null

exit 0