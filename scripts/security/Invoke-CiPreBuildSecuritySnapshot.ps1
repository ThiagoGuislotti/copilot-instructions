<#
.SYNOPSIS
    Runs the warning-only pre-build security gate with stack-aware skip detection for CI.

.DESCRIPTION
    Detects whether the repository currently contains .NET, frontend, and Rust
    projects, then invokes `Invoke-PreBuildSecurityGate.ps1` with the narrowest
    required scope. This avoids duplicating stack detection logic across GitHub
    Actions workflows while preserving warning-only observability behavior.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER WarningOnly
    Runs the security gate in warning-only mode. Defaults to true.

.PARAMETER AllowMissingCargoAudit
    Allows the Rust audit prerequisite to be missing without failing execution.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/security/Invoke-CiPreBuildSecuritySnapshot.ps1 -RepoRoot . -WarningOnly:$true

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [bool] $WarningOnly = $true,
    [switch] $AllowMissingCargoAudit,
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
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$hasDotnet = @(
    Get-ChildItem -Path $resolvedRepoRoot -Recurse -File -Include *.sln, *.slnf -ErrorAction SilentlyContinue
).Count -gt 0
$hasFrontend = @(
    Get-ChildItem -Path $resolvedRepoRoot -Recurse -File -Filter package.json -ErrorAction SilentlyContinue
).Count -gt 0
$hasRust = @(
    Get-ChildItem -Path $resolvedRepoRoot -Recurse -File -Filter Cargo.toml -ErrorAction SilentlyContinue
).Count -gt 0

Write-VerboseLog ("Detected stacks: dotnet={0}; frontend={1}; rust={2}" -f $hasDotnet, $hasFrontend, $hasRust)

$gateScriptPath = Join-Path $resolvedRepoRoot 'scripts/security/Invoke-PreBuildSecurityGate.ps1'
if (-not (Test-Path -LiteralPath $gateScriptPath -PathType Leaf)) {
    throw "Security gate script not found: $gateScriptPath"
}

$gateArgs = @{
    RepoRoot = $resolvedRepoRoot
    WarningOnly = $WarningOnly
}

if ($AllowMissingCargoAudit) {
    $gateArgs.AllowMissingCargoAudit = $true
}
if (-not $hasDotnet) {
    $gateArgs.SkipDotnet = $true
}
if (-not $hasFrontend) {
    $gateArgs.SkipFrontend = $true
}
if (-not $hasRust) {
    $gateArgs.SkipRust = $true
}

& $gateScriptPath @gateArgs
$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
exit $exitCode