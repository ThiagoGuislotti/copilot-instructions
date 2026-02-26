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

# Registers a validation warning.
function Add-ValidationWarning {
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
    Add-ValidationWarning ("Audit ledger not found (optional): {0}" -f $LedgerPath)
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
    Add-ValidationWarning ("Audit ledger has no entries: {0}" -f $LedgerPath)
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