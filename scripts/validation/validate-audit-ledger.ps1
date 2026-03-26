<#
.SYNOPSIS
    Validates the append-only validation ledger hash chain.

.DESCRIPTION
    Verifies entries in `.temp/audit/validation-ledger.jsonl` by recomputing:
    - payload hash
    - chained entry hash using previous hash

    Contract:
    - payloadHash = SHA256(payloadJson)
    - entryHash = SHA256(prevHash + "|" + payloadHash)

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when enforcing mode is enabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER LedgerPath
    Ledger path relative to repository root.

.PARAMETER WarningOnly
    When true (default), findings are emitted as warnings and do not fail execution.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-audit-ledger.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-audit-ledger.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $LedgerPath = '.temp/audit/validation-ledger.jsonl',
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

# Resolves a path from repo root.

# Returns lowercase SHA256 hash for input text.
function Get-StringSha256Hash {
    param(
        [string] $Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedLedgerPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $LedgerPath
if (-not (Test-Path -LiteralPath $resolvedLedgerPath -PathType Leaf)) {
    Write-StyledOutput ("[INFO] Audit ledger not found (optional): {0}" -f $LedgerPath)
    Write-StyledOutput ''
    Write-StyledOutput 'Audit ledger validation summary'
    Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-StyledOutput '  Entries checked: 0'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 0
}

$lines = @(Get-Content -LiteralPath $resolvedLedgerPath)
if ($lines.Count -eq 0) {
    Write-StyledOutput ("[INFO] Audit ledger has no entries yet: {0}" -f $LedgerPath)
}

$entriesChecked = 0
$previousEntryHash = ('0' * 64)

for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = [string] $lines[$index]
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $entryObject = $null
    try {
        $entryObject = $line | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ValidationFailure ("Ledger line {0} is not valid JSON." -f ($index + 1))
        continue
    }

    $payloadJson = [string] $entryObject.payloadJson
    $payloadHash = [string] $entryObject.payloadHash
    $prevHash = [string] $entryObject.prevHash
    $entryHash = [string] $entryObject.entryHash

    if ([string]::IsNullOrWhiteSpace($payloadJson) -or [string]::IsNullOrWhiteSpace($payloadHash) -or [string]::IsNullOrWhiteSpace($prevHash) -or [string]::IsNullOrWhiteSpace($entryHash)) {
        Add-ValidationFailure ("Ledger line {0} is missing required hash fields." -f ($index + 1))
        continue
    }

    if ($prevHash -ne $previousEntryHash) {
        Add-ValidationFailure ("Ledger chain break at line {0}: expected prevHash {1} but found {2}." -f ($index + 1), $previousEntryHash, $prevHash)
        $previousEntryHash = $entryHash
        $entriesChecked++
        continue
    }

    $computedPayloadHash = Get-StringSha256Hash -Text $payloadJson
    if ($computedPayloadHash -ne $payloadHash) {
        Add-ValidationFailure ("Ledger payload hash mismatch at line {0}." -f ($index + 1))
    }

    $computedEntryHash = Get-StringSha256Hash -Text ("{0}|{1}" -f $prevHash, $payloadHash)
    if ($computedEntryHash -ne $entryHash) {
        Add-ValidationFailure ("Ledger entry hash mismatch at line {0}." -f ($index + 1))
    }

    $previousEntryHash = $entryHash
    $entriesChecked++
}

Write-StyledOutput ''
Write-StyledOutput 'Audit ledger validation summary'
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Entries checked: {0}" -f $entriesChecked)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

Write-StyledOutput 'Audit ledger validation passed.'
exit 0