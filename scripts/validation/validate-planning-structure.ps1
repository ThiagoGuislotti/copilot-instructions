<#
.SYNOPSIS
    Validates the versioned planning workspace structure under planning/.

.DESCRIPTION
    Enforces the repository contract for versioned planning artifacts under
    `planning/`, including required documentation entry points, required
    top-level directories, on-demand planning subdirectories, and absence of
    legacy `.temp/planning` drift.

.PARAMETER RepoRoot
    Repository root used to resolve the planning workspace structure.

.PARAMETER WarningOnly
    When true, structural failures are emitted as warnings and exit code remains 0.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [bool] $WarningOnly = $true,
    [switch] $Verbose
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
Start-ExecutionSession `
    -Name 'validate-planning-structure' `
    -Metadata ([ordered]@{
            'Warning-only mode' = [bool] $WarningOnly
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

# Records either a failure or a warning based on the selected validation mode.
function Add-ValidationMessage {
    param(
        [string] $Message,
        [System.Collections.Generic.List[string]] $Warnings,
        [System.Collections.Generic.List[string]] $Failures,
        [bool] $WarningOnlyMode
    )

    if ($WarningOnlyMode) {
        $Warnings.Add($Message) | Out-Null
        Write-ValidationOutput ("[WARN] {0}" -f $Message)
    }
    else {
        $Failures.Add($Message) | Out-Null
        Write-ValidationOutput ("[FAIL] {0}" -f $Message)
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$warnings = New-Object System.Collections.Generic.List[string]
$failures = New-Object System.Collections.Generic.List[string]

$requiredFiles = @(
    'planning/README.md',
    'planning/specs/README.md'
)

foreach ($relativePath in $requiredFiles) {
    $absolutePath = Join-Path $resolvedRepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        Add-ValidationMessage -Message ("Missing required planning file: {0}" -f $relativePath) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
    }
}

$requiredDirectories = @(
    'planning',
    'planning/specs'
)

foreach ($relativePath in $requiredDirectories) {
    $absolutePath = Join-Path $resolvedRepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Container)) {
        Add-ValidationMessage -Message ("Missing required planning directory: {0}" -f $relativePath) -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
    }
}

$onDemandDirectories = @(
    'planning/active',
    'planning/completed',
    'planning/specs/active',
    'planning/specs/completed'
)

foreach ($relativePath in $onDemandDirectories) {
    $absolutePath = Join-Path $resolvedRepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Container)) {
        Write-ValidationOutput ("[INFO] Optional planning directory will be created on demand: {0}" -f $relativePath)
    }
}

$legacyPlanningPath = Join-Path $resolvedRepoRoot '.temp/planning'
if (Test-Path -LiteralPath $legacyPlanningPath) {
    Add-ValidationMessage -Message 'Legacy planning workspace found under .temp/planning. Move versioned planning artifacts to planning/.' -Warnings $warnings -Failures $failures -WarningOnlyMode $WarningOnly
}

Write-ValidationOutput ''
Write-ValidationOutput 'Planning structure validation summary'
Write-ValidationOutput ("  Warnings: {0}" -f $warnings.Count)
Write-ValidationOutput ("  Failures: {0}" -f $failures.Count)

$sessionStatus = if ($failures.Count -gt 0) { 'failed' } elseif ($warnings.Count -gt 0) { 'warning' } else { 'passed' }
Complete-ExecutionSession -Name 'validate-planning-structure' -Status $sessionStatus -Summary ([ordered]@{
        'Warnings' = $warnings.Count
        'Failures' = $failures.Count
    }) | Out-Null

if ($failures.Count -gt 0) {
    exit 1
}

Write-ValidationOutput 'Planning workspace validation passed.'
exit 0