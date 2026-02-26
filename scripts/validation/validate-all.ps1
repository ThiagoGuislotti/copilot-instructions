<#
.SYNOPSIS
    Runs the complete validation suite for the instruction and agent system.

.DESCRIPTION
    Executes all repository validation scripts in deterministic order and outputs
    an aggregate summary with per-check status.

    Included checks:
    - validate-instructions
    - validate-policy
    - validate-security-baseline
    - validate-agent-orchestration
    - validate-agent-skill-alignment
    - validate-routing-coverage
    - validate-readme-standards
    - validate-powershell-standards
    - validate-dotnet-standards
    - validate-architecture-boundaries
    - validate-instruction-metadata
    - validate-release-governance
    - validate-release-provenance

    Exit code:
    - 0 when every check passes
    - 1 when any check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER IncludeAllPowershellScripts
    Passes -IncludeAllScripts to validate-powershell-standards.

.PARAMETER StrictPowershellStandards
    Passes -Strict to validate-powershell-standards.

.PARAMETER SkipPSScriptAnalyzer
    Passes -SkipScriptAnalyzer to validate-powershell-standards.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1 -IncludeAllPowershellScripts -StrictPowershellStandards

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [switch] $IncludeAllPowershellScripts,
    [switch] $StrictPowershellStandards,
    [switch] $SkipPSScriptAnalyzer,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE] {0}" -f $Message)
    }
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

# Resolves repository root from input and fallbacks.
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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Executes a validation script and returns a status record.
function Invoke-ValidationScript {
    param(
        [string] $Root,
        [string] $Name,
        [string] $RelativeScriptPath,
        [hashtable] $Arguments
    )

    $startedAt = Get-Date
    $resolvedScriptPath = Resolve-RepoPath -Root $Root -Path $RelativeScriptPath
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if (-not (Test-Path -LiteralPath $resolvedScriptPath -PathType Leaf)) {
        $errorMessage = "Script not found: $RelativeScriptPath"
        Write-Output ("[FAIL] {0}: {1}" -f $Name, $errorMessage)
    }
    else {
        Write-Output ("[RUN] {0}" -f $Name)
        try {
            & $resolvedScriptPath @Arguments | Out-Host
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            if ($exitCode -eq 0) {
                $status = 'passed'
                Write-Output ("[OK] {0}" -f $Name)
            }
            else {
                Write-Output ("[FAIL] {0} (exit code {1})" -f $Name, $exitCode)
            }
        }
        catch {
            $exitCode = 1
            $errorMessage = $_.Exception.Message
            Write-Output ("[FAIL] {0} (exception: {1})" -f $Name, $errorMessage)
        }
    }

    $finishedAt = Get-Date
    return [pscustomobject]@{
        name = $Name
        script = $RelativeScriptPath
        status = $status
        exitCode = $exitCode
        durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
        error = $errorMessage
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$checkDefinitions = New-Object System.Collections.Generic.List[object]

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-instructions'
    script = 'scripts/validation/validate-instructions.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-policy'
    script = 'scripts/validation/validate-policy.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-security-baseline'
    script = 'scripts/validation/validate-security-baseline.ps1'
    args = @{
        RepoRoot = $resolvedRepoRoot
        WarningOnly = $true
    }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-agent-orchestration'
    script = 'scripts/validation/validate-agent-orchestration.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-agent-skill-alignment'
    script = 'scripts/validation/validate-agent-skill-alignment.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-routing-coverage'
    script = 'scripts/validation/validate-routing-coverage.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-readme-standards'
    script = 'scripts/validation/validate-readme-standards.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$powershellArgs = @{ RepoRoot = $resolvedRepoRoot }
if ($IncludeAllPowershellScripts) {
    $powershellArgs.IncludeAllScripts = $true
}
if ($StrictPowershellStandards) {
    $powershellArgs.Strict = $true
}
if ($SkipPSScriptAnalyzer) {
    $powershellArgs.SkipScriptAnalyzer = $true
}

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-powershell-standards'
    script = 'scripts/validation/validate-powershell-standards.ps1'
    args = $powershellArgs
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-dotnet-standards'
    script = 'scripts/validation/validate-dotnet-standards.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-architecture-boundaries'
    script = 'scripts/validation/validate-architecture-boundaries.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-instruction-metadata'
    script = 'scripts/validation/validate-instruction-metadata.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-release-governance'
    script = 'scripts/validation/validate-release-governance.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}) | Out-Null

$checkDefinitions.Add([pscustomobject]@{
    name = 'validate-release-provenance'
    script = 'scripts/validation/validate-release-provenance.ps1'
    args = @{
        RepoRoot = $resolvedRepoRoot
        WarningOnly = $true
    }
}) | Out-Null

$results = New-Object System.Collections.Generic.List[object]
foreach ($checkDefinition in $checkDefinitions) {
    $result = Invoke-ValidationScript -Root $resolvedRepoRoot -Name $checkDefinition.name -RelativeScriptPath $checkDefinition.script -Arguments $checkDefinition.args
    $results.Add($result) | Out-Null
}

$passed = @($results | Where-Object { $_.status -eq 'passed' }).Count
$failed = @($results | Where-Object { $_.status -ne 'passed' }).Count

Write-Output ''
Write-Output 'Validation suite summary'
Write-Output ("  Total checks: {0}" -f $results.Count)
Write-Output ("  Passed: {0}" -f $passed)
Write-Output ("  Failed: {0}" -f $failed)

if ($failed -gt 0) {
    Write-Output ''
    Write-Output 'Failed checks'
    foreach ($failedResult in ($results | Where-Object { $_.status -ne 'passed' })) {
        $errorDetail = if ([string]::IsNullOrWhiteSpace([string] $failedResult.error)) { '' } else { " :: $($failedResult.error)" }
        Write-Output ("  - {0} (exit {1}){2}" -f $failedResult.name, $failedResult.exitCode, $errorDetail)
    }

    exit 1
}

Write-Output 'All validation checks passed.'
exit 0