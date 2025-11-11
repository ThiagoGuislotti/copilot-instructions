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
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent

# -------------------------------
# Helpers
# -------------------------------
function Set-CorrectWorkingDirectory {
    param (
        [string] $StartPath
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($StartPath)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $StartPath).Path
        }
        catch {
            Write-Warning ("Unable to resolve path '{0}': {1}" -f $StartPath, $_.Exception.Message)
        }
    }

    if ($script:ScriptRoot) {
        $candidates += $script:ScriptRoot
    }
    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($i = 0; $i -lt 5 -and $current; $i++) {
            $hasSln = Test-Path (Join-Path -Path $current -ChildPath 'NetToolsKit.sln')
            $hasLayout = (Test-Path (Join-Path -Path $current -ChildPath 'src')) -and (Test-Path (Join-Path -Path $current -ChildPath '.github'))

            if ($hasSln -or $hasLayout) {
                Set-Location -Path $current
                Write-Host ("Solution root found: {0}" -f $PWD) -ForegroundColor Green
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw "Could not find solution root."
}

function Write-VerboseColor {
    param (
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($Verbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

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
$repoRoot = Set-CorrectWorkingDirectory -StartPath $Path
$targetPath = Get-TargetPath -RequestedPath $Path -RepoRoot $repoRoot

Write-Host ("Scanning from: {0}" -f $targetPath) -ForegroundColor Blue

$artifactNames = @(
    '.build',
    '.deployment',
    'bin',
    'obj'
)

$directories = Get-ChildItem -Path $targetPath -Recurse -Directory |
    Where-Object { $artifactNames -contains $_.Name }

Write-Host ("Directories found: {0}" -f $directories.Count) -ForegroundColor Yellow

if ($directories.Count -eq 0) {
    Write-Host "No build artifacts found." -ForegroundColor Green
    exit 0
}

if ($DryRun) {
    Write-Host "Dry run mode. The following directories would be removed:" -ForegroundColor Cyan
    $directories | ForEach-Object { Write-Host $_.FullName }
    exit 0
}

if (-not (Confirm-Deletion -Prompt "Delete the listed directories?" -SkipPrompt:$Force)) {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
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

Write-Host "Cleanup completed." -ForegroundColor Green
