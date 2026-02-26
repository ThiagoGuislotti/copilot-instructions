<#
.SYNOPSIS
    Configures local Git hooks for instruction/policy validation and runtime sync workflows.

.DESCRIPTION
    Sets `core.hooksPath` to `.githooks` for this repository and verifies required hook files:
    - pre-commit
    - post-commit
    - post-merge
    - post-checkout

    On Linux/macOS, marks hook scripts as executable.

    When `-Uninstall` is used, removes local `core.hooksPath` configuration.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script detects root from script location.

.PARAMETER Uninstall
    Removes local `core.hooksPath` configuration instead of setting it.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1 -RepoRoot C:\repo\copilot-instructions

.EXAMPLE
    pwsh -File scripts/git-hooks/setup-git-hooks.ps1 -Uninstall

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git.
#>

param(
    [string] $RepoRoot,
    [switch] $Uninstall,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE:{0}] {1}" -f $Color, $Message)
    }
}

# Resolves the repository root using explicit and fallback location candidates.
function Resolve-RepositoryRoot {
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
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

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

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
Assert-CommandAvailable -CommandName 'git'

$gitRoot = (& git -C $resolvedRepoRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
    throw ("Current folder is not a Git repository: {0}" -f $resolvedRepoRoot)
}

if ($Uninstall) {
    & git -C $resolvedRepoRoot config --local --unset core.hooksPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'No local core.hooksPath configured.'
        exit 0
    }

    Write-Output 'Removed local Git hook path (core.hooksPath).'
    exit 0
}

$hooksDirectory = Join-Path $resolvedRepoRoot '.githooks'
if (-not (Test-Path -LiteralPath $hooksDirectory -PathType Container)) {
    throw ("Missing hook directory: {0}" -f $hooksDirectory)
}

$requiredHooks = @(
    'pre-commit',
    'post-commit',
    'post-merge',
    'post-checkout'
)

$hookPaths = New-Object System.Collections.Generic.List[string]
foreach ($hookName in $requiredHooks) {
    $hookPath = Join-Path $hooksDirectory $hookName
    Assert-PathPresent -Path $hookPath -Label ("hook file '{0}'" -f $hookName)
    $hookPaths.Add($hookPath) | Out-Null
}

& git -C $resolvedRepoRoot config --local core.hooksPath '.githooks'
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to configure local Git hook path.'
}

Invoke-HookExecutabilityUpdate -HookPaths $hookPaths.ToArray()

$configuredPath = (& git -C $resolvedRepoRoot config --local --get core.hooksPath 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($configuredPath)) {
    throw 'Could not read configured core.hooksPath.'
}

Write-Output 'Git hooks configured successfully.'
Write-Output ("  repo: {0}" -f $gitRoot)
Write-Output ("  core.hooksPath: {0}" -f $configuredPath)
Write-Output '  pre-commit: .githooks/pre-commit (runs validate-all with profile=dev, warning-only, best effort)'
Write-Output '  post-commit: .githooks/post-commit (syncs ~/.github and ~/.codex via scripts/runtime/bootstrap.ps1)'
Write-Output '  post-merge: .githooks/post-merge (runs validate-all with profile=release, warning-only, best effort)'
Write-Output '  post-checkout: .githooks/post-checkout (runs validate-all with profile=dev, warning-only, best effort)'
Write-Output '  skip sync (temporary): set CODEX_SKIP_POST_COMMIT_SYNC=1'
Write-Output '  optional MCP apply on manifest change: set CODEX_APPLY_MCP_ON_POST_COMMIT=1'
Write-Output '  MCP apply backup default: CODEX_BACKUP_MCP_CONFIG=1 (set 0 to disable backup)'

exit 0