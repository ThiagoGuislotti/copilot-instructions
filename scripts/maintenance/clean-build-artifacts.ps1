<#
.SYNOPSIS
    Resets build output directories (.build, .deployment, bin, obj) to keep the repository clean between builds.

.DESCRIPTION
    Discovers the solution root automatically (Set-CorrectWorkingDirectory) and scans from there or an optional -Path.
    The script identifies the most common build output folders and deletes them after a safety confirmation.
    Key capabilities:
        - Dry-run preview that lists every directory matched before performing any deletion.
        - Interactive confirmation prompt with optional -Force override for unattended pipelines.
        - Verbose logging that highlights each Remove-Item invocation so you can audit cleanups.
        - Smart root detection that tolerates nested execution (e.g., running from scripts/ or tools/).

.PARAMETER Path
    Root directory to clean. Defaults to the detected repository root when omitted.

.PARAMETER DryRun
    Shows which directories would be deleted without touching the filesystem.

.PARAMETER Force
    Skips the confirmation prompt. Combine with DryRun $false for automated workflows.

.PARAMETER Verbose
    Emits color-coded diagnostics for each folder considered and every deletion attempt.

.EXAMPLE
    # Clean the repository root and confirm interactively.
    pwsh -File scripts/maintenance/clean-build-artifacts.ps1

.EXAMPLE
    # Preview all .build/.deployment/bin/obj folders before deleting anything.
    pwsh -File scripts/maintenance/clean-build-artifacts.ps1 -DryRun

.EXAMPLE
    # Clean a nested path (useful when targeting only one module) and skip prompts.
    pwsh -File scripts/maintenance/clean-build-artifacts.ps1 -Path "src/NetToolsKit.OpenApi" -Force

.EXAMPLE
    # Combine dry run with verbose output to audit the discovery logic.
    pwsh -File scripts/maintenance/clean-build-artifacts.ps1 -DryRun -Verbose

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+, Git optional (for root detection via git rev-parse).
    Safety: this script deletes directories recursively; always validate the dry-run output before forcing deletion.
#>

param (
    [string] $Path,
    [switch] $DryRun,
    [switch] $Force,
    [switch] $Verbose
)

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
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

# -------------------------------
# Helpers
# -------------------------------
# Prompts for deletion confirmation when interactive safeguards are enabled.
function Confirm-Deletion {
    param (
        [string] $Prompt,
        [switch] $SkipPrompt
    )

    if ($SkipPrompt) {
        return $true
    }

    $answer = Read-Host ("{0} [y/N]" -f $Prompt)
    return $answer -match '^[yY](?:es)?$'
}

# Builds an absolute target path from repository-relative or absolute input.
function Get-TargetPath {
    param (
        [string] $RequestedPath,
        [string] $RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $RepoRoot
    }

    if (-not (Test-Path -LiteralPath $RequestedPath)) {
        throw "Path '$RequestedPath' does not exist."
    }

    return (Resolve-Path -LiteralPath $RequestedPath).Path
}

# -------------------------------
# Main execution
# -------------------------------
$repoRoot = Resolve-SolutionOrLayoutRoot -RequestedRoot $Path -StartPath (Get-Location).Path
Set-Location -Path $repoRoot
$targetPath = Get-TargetPath -RequestedPath $Path -RepoRoot $repoRoot

Write-ColorLine -Message ("Solution root found: {0}" -f $repoRoot) -Color 'Blue'
Write-ColorLine -Message ("Scanning from: {0}" -f $targetPath) -Color 'Blue'

$artifactNames = @(
    '.build',
    '.deployment',
    'bin',
    'obj'
)

$directories = Get-ChildItem -Path $targetPath -Recurse -Directory |
    Where-Object { $artifactNames -contains $_.Name }

Write-ColorLine -Message ("Directories found: {0}" -f $directories.Count) -Color 'Yellow'

if ($directories.Count -eq 0) {
    Write-ColorLine -Message 'No build artifacts found.' -Color 'Green'
    exit 0
}

if ($DryRun) {
    Write-ColorLine -Message 'Dry run mode. The following directories would be removed:' -Color 'Yellow'
    $directories | ForEach-Object { Write-StyledOutput $_.FullName }
    exit 0
}

if (-not (Confirm-Deletion -Prompt "Delete the listed directories?" -SkipPrompt:$Force)) {
    Write-ColorLine -Message 'Operation cancelled by user.' -Color 'Yellow'
    exit 0
}

foreach ($dir in $directories) {
    try {
        Write-VerboseColor ("Removing {0}" -f $dir.FullName) 'Green'
        Remove-Item -LiteralPath $dir.FullName -Recurse -Force
    }
    catch {
        Write-VerboseColor ("ERROR removing {0}: {1}" -f $dir.FullName, $_.Exception.Message) 'Red'
    }
}

Write-ColorLine -Message 'Cleanup completed.' -Color 'Green'