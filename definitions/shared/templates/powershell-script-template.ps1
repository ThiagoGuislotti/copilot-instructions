<#
.SYNOPSIS
    [SHORT_SCRIPT_SUMMARY]

.DESCRIPTION
    [DETAILED_SCRIPT_DESCRIPTION]

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER DryRun
    When set, prints intended actions without mutating files.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/[AREA]/[SCRIPT_NAME].ps1

.EXAMPLE
    pwsh -File scripts/[AREA]/[SCRIPT_NAME].ps1 -RepoRoot C:\work\repo -DryRun -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [switch] $DryRun,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:ChangeCount = 0
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers warning diagnostics.
function Add-TemplateWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Resolves a path from repo root.
function Resolve-RepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

# Resolves repository root from input and fallback candidates.
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
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Performs script-specific operation.
function Invoke-TemplateOperation {
    param(
        [string] $Root,
        [bool] $IsDryRun
    )

    $targetPath = Resolve-RepoPath -Root $Root -Path '[RELATIVE_TARGET_PATH]'
    Write-VerboseLog ("Target path: {0}" -f $targetPath)

    if ($IsDryRun) {
        Write-StyledOutput ("[INFO] Dry-run: would process '{0}'." -f $targetPath)
        return
    }

    if (-not (Test-Path -LiteralPath $targetPath)) {
        Add-TemplateWarning ("Target path not found: {0}" -f $targetPath)
        return
    }

    # TODO: implement script action.
    $script:ChangeCount++
    Write-StyledOutput ("[OK] Processed: {0}" -f $targetPath)
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

Invoke-TemplateOperation -Root $resolvedRepoRoot -IsDryRun:[bool] $DryRun

Write-StyledOutput ''
Write-StyledOutput '[INFO] Script summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Dry-run: {0}" -f [bool] $DryRun)
Write-StyledOutput ("  Changes: {0}" -f $script:ChangeCount)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)

exit 0