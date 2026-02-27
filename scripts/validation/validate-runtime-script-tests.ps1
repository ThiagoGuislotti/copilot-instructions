<#
.SYNOPSIS
    Runs automated tests for critical runtime scripts.

.DESCRIPTION
    Executes Pester test suites under `scripts/tests/pester` that validate
    contracts and smoke behavior for critical runtime scripts.

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when warning-only is disabled and test failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER WarningOnly
    When true (default), failures are emitted as warnings.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-runtime-script-tests.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Pester 5+ (optional in warning-only mode).
#>

param(
    [string] $RepoRoot,
    [bool] $WarningOnly = $true,
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
$script:IsWarningOnly = [bool] $WarningOnly
$script:Failures = New-Object System.Collections.Generic.List[string]
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

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    if ($script:IsWarningOnly) {
        $script:Warnings.Add($Message) | Out-Null
        Write-StyledOutput ("[WARN] {0}" -f $Message)
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$testPath = Join-Path $resolvedRepoRoot 'scripts/tests/pester'
if (-not (Test-Path -LiteralPath $testPath -PathType Container)) {
    Add-ValidationFailure ("Pester test path not found: {0}" -f $testPath)
}

$pesterModule = Get-Module -ListAvailable -Name 'Pester' | Sort-Object Version -Descending | Select-Object -First 1
$skipReason = $null
if ($null -eq $pesterModule) {
    if ($script:IsWarningOnly) {
        $skipReason = 'Pester module not found; runtime script tests skipped.'
        Write-StyledOutput ("[INFO] {0}" -f $skipReason)
    }
    else {
        Add-ValidationFailure 'Pester module not found. Install Pester 5+.'
    }
}
elseif ([int]$pesterModule.Version.Major -lt 5) {
    if ($script:IsWarningOnly) {
        $skipReason = ("Pester version {0} detected; runtime tests require 5+. Tests skipped." -f $pesterModule.Version)
        Write-StyledOutput ("[INFO] {0}" -f $skipReason)
    }
    else {
        Add-ValidationFailure ("Unsupported Pester version {0}. Install Pester 5+." -f $pesterModule.Version)
    }
}

$passCount = 0
$failCount = 0
$skipCount = 0

if (($null -ne $pesterModule) -and ([int]$pesterModule.Version.Major -ge 5) -and (Test-Path -LiteralPath $testPath -PathType Container)) {
    Write-VerboseLog ("Running Pester tests in: {0}" -f $testPath)

    try {
        Import-Module -Name $pesterModule.Path -Force -ErrorAction Stop
        $pesterCommand = Get-Command -Name 'Invoke-Pester' -ErrorAction Stop
        $supportsCI = $pesterCommand.Parameters.ContainsKey('CI')
        if ($supportsCI) {
            $pesterResult = Invoke-Pester -Path $testPath -CI -PassThru
        }
        else {
            $pesterResult = Invoke-Pester -Path $testPath -PassThru
        }

        if ($null -ne $pesterResult) {
            $passCount = [int] $pesterResult.PassedCount
            $failCount = [int] $pesterResult.FailedCount
            $skipCount = [int] $pesterResult.SkippedCount
        }

        if ($failCount -gt 0) {
            Add-ValidationFailure ("Runtime script tests failed: {0}" -f $failCount)
        }
    }
    catch {
        Add-ValidationFailure ("Pester execution failed: {0}" -f $_.Exception.Message)
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Runtime script test validation summary'
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Passed tests: {0}" -f $passCount)
Write-StyledOutput ("  Failed tests: {0}" -f $failCount)
Write-StyledOutput ("  Skipped tests: {0}" -f $skipCount)
if (-not [string]::IsNullOrWhiteSpace($skipReason)) {
    Write-StyledOutput ("  Skip reason: {0}" -f $skipReason)
}
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

if ($script:Failures.Count -gt 0 -or $script:Warnings.Count -gt 0) {
    Write-StyledOutput 'Runtime script test validation completed with warnings.'
}
else {
    Write-StyledOutput 'Runtime script test validation passed.'
}

exit 0