<#
.SYNOPSIS
    Runs automated tests for critical runtime scripts.

.DESCRIPTION
    Executes runtime test scripts under `scripts/tests/runtime` that validate
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
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [bool] $WarningOnly = $true,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $script:IsVerboseEnabled

# Replays captured test output only when detailed diagnostics are required.
function Write-TestOutput {
    param(
        [object[]] $Items
    )

    if ($null -eq $Items) {
        return
    }

    foreach ($item in $Items) {
        $text = [string] $item
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        Write-StyledOutput $text
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$testPath = Join-Path $resolvedRepoRoot 'scripts/tests/runtime'
if (-not (Test-Path -LiteralPath $testPath -PathType Container)) {
    Add-ValidationFailure ("Runtime test path not found: {0}" -f $testPath)
}

$passCount = 0
$failCount = 0
$skipCount = 0

if (Test-Path -LiteralPath $testPath -PathType Container) {
    $testScripts = @(
        Get-ChildItem -LiteralPath $testPath -Filter '*.ps1' -File
    )
    if ($testScripts.Count -eq 0) {
        Add-ValidationFailure ("No runtime test scripts found in: {0}" -f $testPath)
    }
    else {
        Write-VerboseLog ("Running runtime tests in: {0}" -f $testPath)
        foreach ($testScript in $testScripts) {
            Write-StyledOutput ("[RUN] runtime test: {0}" -f $testScript.Name)
            $capturedOutput = @()
            try {
                $capturedOutput = @(& $testScript.FullName -RepoRoot $resolvedRepoRoot *>&1)
                $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
                if ($exitCode -eq 0) {
                    $passCount++
                    if ($script:IsVerboseEnabled) {
                        Write-TestOutput -Items $capturedOutput
                    }
                    Write-StyledOutput ("[OK] runtime test: {0}" -f $testScript.Name)
                }
                else {
                    $failCount++
                    Write-TestOutput -Items $capturedOutput
                    Add-ValidationFailure ("Runtime test failed: {0} (exit code {1})" -f $testScript.Name, $exitCode)
                }
            }
            catch {
                $failCount++
                if ($null -ne $capturedOutput) {
                    Write-TestOutput -Items $capturedOutput
                }
                Add-ValidationFailure ("Runtime test failed: {0} ({1})" -f $testScript.Name, $_.Exception.Message)
            }
        }
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Runtime script test validation summary'
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Passed tests: {0}" -f $passCount)
Write-StyledOutput ("  Failed tests: {0}" -f $failCount)
Write-StyledOutput ("  Skipped tests: {0}" -f $skipCount)
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