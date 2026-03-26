<#
.SYNOPSIS
    Runtime tests for the versioned planning workspace structure.

.DESCRIPTION
    Validates the planning workspace contract by executing the repository
    planning structure validator in enforced mode.

.PARAMETER RepoRoot
    Optional repository root. If omitted, uses the current location.

.EXAMPLE
    pwsh -File scripts/tests/runtime/planning-structure.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
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
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$validationScriptPath = Join-Path $resolvedRepoRoot 'scripts/validation/validate-planning-structure.ps1'

& $validationScriptPath -RepoRoot $resolvedRepoRoot -WarningOnly:$false | Out-Null
$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }

if ($exitCode -ne 0) {
    Write-Host '[FAIL] planning structure tests failed.'
    exit 1
}

Write-Host '[OK] planning structure tests passed.'
exit 0