<#
.SYNOPSIS
    Runs the complete validation suite for the instruction and agent system.

.DESCRIPTION
    Executes repository validation scripts in deterministic order, supports
    governance profiles, and writes append-only hash-chained ledger evidence.

    Included checks:
    - validate-instructions
    - validate-policy
    - validate-security-baseline
    - validate-shared-script-checksums
    - validate-agent-orchestration
    - validate-agent-skill-alignment
    - validate-agent-permissions
    - validate-planning-structure
    - validate-routing-coverage
    - validate-authoritative-source-policy
    - validate-instruction-architecture
    - validate-readme-standards
    - validate-template-standards
    - validate-workspace-efficiency
    - validate-compatibility-lifecycle-policy
    - validate-powershell-standards
    - validate-agent-hooks
    - validate-shell-hooks
    - validate-runtime-script-tests
    - validate-warning-baseline
    - validate-dotnet-standards
    - validate-architecture-boundaries
    - validate-instruction-metadata
    - validate-supply-chain
    - validate-release-governance
    - validate-release-provenance
    - validate-audit-ledger

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when warning-only is disabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER ValidationProfile
    Validation profile id from `.github/governance/validation-profiles.json`.
    Defaults to profile file's `defaultProfile` when omitted.

.PARAMETER ValidationProfilesPath
    Validation profile definition path relative to repository root.

.PARAMETER IncludeAllPowershellScripts
    Passes -IncludeAllScripts to validate-powershell-standards.

.PARAMETER StrictPowershellStandards
    Passes -Strict to validate-powershell-standards.

.PARAMETER SkipPSScriptAnalyzer
    Passes -SkipScriptAnalyzer to validate-powershell-standards.

.PARAMETER WarningOnly
    Global warning-only mode. Default true.

.PARAMETER WriteLedger
    When true (default), appends run evidence to hash-chained validation ledger.

.PARAMETER LedgerPath
    Validation ledger path relative to repository root.

.PARAMETER OutputPath
    Validation report output path relative to repository root.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1 -ValidationProfile release

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1 -WarningOnly:$false -ValidationProfile enforced

.NOTES
    Version: 2.2
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ValidationProfile,
    [string] $ValidationProfilesPath = '.github/governance/validation-profiles.json',
    [switch] $IncludeAllPowershellScripts,
    [switch] $StrictPowershellStandards,
    [switch] $SkipPSScriptAnalyzer,
    [object] $WarningOnly = $true,
    [bool] $WriteLedger = $true,
    [string] $LedgerPath = '.temp/audit/validation-ledger.jsonl',
    [string] $OutputPath = '.temp/audit/validate-all.latest.json',
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
Initialize-ValidationState -VerboseEnabled $script:IsVerboseEnabled
$script:SuiteStartedAt = Get-Date

# Registers script-level warning diagnostics.
function Initialize-SuiteWarningList {
    $restoredWarnings = New-Object System.Collections.Generic.List[string]
    $sourceWarnings = @()

    if ($null -ne $script:Warnings) {
        if ($script:Warnings -is [System.Collections.Generic.List[string]]) {
            $sourceWarnings = @($script:Warnings.ToArray())
        }
        else {
            $sourceWarnings = @($script:Warnings)
        }
    }

    foreach ($item in $sourceWarnings) {
        $text = [string] $item
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $restoredWarnings.Add($text) | Out-Null
        }
    }

    $script:Warnings = $restoredWarnings
}

# Returns suite warning count safely under strict mode.
function Get-SuiteWarningCount {
    Initialize-SuiteWarningList
    return $script:Warnings.Count
}

# Registers script-level warning diagnostics.
function Add-SuiteWarning {
    param(
        [string] $Message
    )

    Initialize-SuiteWarningList
    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Normalizes external boolean-like inputs so shell hooks and older wrappers can
# pass string values such as "true" without tripping PowerShell parameter binding.
function Convert-ToBooleanValue {
    param(
        [object] $Value,
        [string] $ParameterName,
        [bool] $DefaultValue
    )

    if ($null -eq $Value) {
        return $DefaultValue
    }

    if ($Value -is [bool]) {
        return [bool] $Value
    }

    if ($Value -is [string]) {
        $normalized = $Value.Trim().ToLowerInvariant()
        switch ($normalized) {
            '' { return $DefaultValue }
            '1' { return $true }
            'true' { return $true }
            'yes' { return $true }
            'on' { return $true }
            '0' { return $false }
            'false' { return $false }
            'no' { return $false }
            'off' { return $false }
            default {
                throw ("Invalid boolean value for parameter '{0}': {1}" -f $ParameterName, $Value)
            }
        }
    }

    if (($Value -is [byte]) -or ($Value -is [int16]) -or ($Value -is [int]) -or ($Value -is [long])) {
        if ([long] $Value -eq 1) {
            return $true
        }

        if ([long] $Value -eq 0) {
            return $false
        }

        throw ("Invalid numeric boolean value for parameter '{0}': {1}" -f $ParameterName, $Value)
    }

    try {
        return [System.Convert]::ToBoolean($Value)
    }
    catch {
        throw ("Invalid boolean value for parameter '{0}': {1}" -f $ParameterName, $Value)
    }
}

# Resolves a path from repo root.

# Reads and parses JSON from file path.
function Read-JsonFile {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-SuiteWarning ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-SuiteWarning ("Invalid JSON in {0}: {1}" -f $Label, $_.Exception.Message)
        return $null
    }
}

# Creates a hashtable clone from input hashtable.
function Copy-Hashtable {
    param(
        [hashtable] $Source
    )

    $target = @{}
    foreach ($key in $Source.Keys) {
        $target[$key] = $Source[$key]
    }
    return $target
}

# Converts arbitrary object to hashtable map using direct properties.
function Convert-ToHashtable {
    param(
        [object] $Value
    )

    $map = @{}
    if ($null -eq $Value) {
        return $map
    }

    if ($Value -is [hashtable]) {
        foreach ($key in $Value.Keys) {
            $map[[string] $key] = $Value[$key]
        }
        return $map
    }

    foreach ($property in $Value.PSObject.Properties) {
        $map[[string] $property.Name] = $property.Value
    }

    return $map
}

# Determines whether script command supports a named parameter.
function Test-ScriptSupportsParameter {
    param(
        [string] $ScriptPath,
        [string] $ParameterName
    )

    try {
        $commandInfo = Get-Command -Name $ScriptPath -ErrorAction Stop
        return $commandInfo.Parameters.ContainsKey($ParameterName)
    }
    catch {
        return $false
    }
}

# Gets git state metadata.
function Get-GitState {
    param(
        [string] $Root
    )

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        return [ordered]@{
            available = $false
            branch = $null
            commit = $null
            isDirty = $null
        }
    }

    $branch = (& git -C $Root rev-parse --abbrev-ref HEAD 2>$null)
    $commit = (& git -C $Root rev-parse HEAD 2>$null)
    $statusLines = (& git -C $Root status --porcelain 2>$null)
    $isDirty = -not [string]::IsNullOrWhiteSpace(($statusLines -join ''))

    return [ordered]@{
        available = $true
        branch = if ([string]::IsNullOrWhiteSpace($branch)) { $null } else { $branch }
        commit = if ([string]::IsNullOrWhiteSpace($commit)) { $null } else { $commit }
        isDirty = $isDirty
    }
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

# Validates the local ledger chain so stale local corruption can be archived before checks run.
function Test-ValidationLedgerChain {
    param(
        [string] $ResolvedLedgerPath
    )

    if (-not (Test-Path -LiteralPath $ResolvedLedgerPath -PathType Leaf)) {
        return [pscustomobject]@{
            isValid = $true
            reason = $null
        }
    }

    $lines = @(Get-Content -LiteralPath $ResolvedLedgerPath)
    $previousEntryHash = ('0' * 64)
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = [string] $lines[$index]
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $entryObject = $line | ConvertFrom-Json -Depth 200
        }
        catch {
            return [pscustomobject]@{
                isValid = $false
                reason = ("line {0} is not valid JSON" -f ($index + 1))
            }
        }

        $payloadJson = [string] $entryObject.payloadJson
        $payloadHash = [string] $entryObject.payloadHash
        $prevHash = [string] $entryObject.prevHash
        $entryHash = [string] $entryObject.entryHash

        if ([string]::IsNullOrWhiteSpace($payloadJson) -or [string]::IsNullOrWhiteSpace($payloadHash) -or [string]::IsNullOrWhiteSpace($prevHash) -or [string]::IsNullOrWhiteSpace($entryHash)) {
            return [pscustomobject]@{
                isValid = $false
                reason = ("line {0} is missing required hash fields" -f ($index + 1))
            }
        }

        if ($prevHash -ne $previousEntryHash) {
            return [pscustomobject]@{
                isValid = $false
                reason = ("chain break at line {0}" -f ($index + 1))
            }
        }

        $computedPayloadHash = Get-StringSha256Hash -Text $payloadJson
        if ($computedPayloadHash -ne $payloadHash) {
            return [pscustomobject]@{
                isValid = $false
                reason = ("payload hash mismatch at line {0}" -f ($index + 1))
            }
        }

        $computedEntryHash = Get-StringSha256Hash -Text ("{0}|{1}" -f $prevHash, $payloadHash)
        if ($computedEntryHash -ne $entryHash) {
            return [pscustomobject]@{
                isValid = $false
                reason = ("entry hash mismatch at line {0}" -f ($index + 1))
            }
        }

        $previousEntryHash = $entryHash
    }

    return [pscustomobject]@{
        isValid = $true
        reason = $null
    }
}

# Archives a broken local validation ledger so future runs start a fresh chain.
function Repair-ValidationLedgerIfNeeded {
    param(
        [string] $Root,
        [string] $TargetLedgerPath
    )

    $resolvedLedgerPath = Resolve-RepoPath -Root $Root -Path $TargetLedgerPath
    if (-not (Test-Path -LiteralPath $resolvedLedgerPath -PathType Leaf)) {
        return $null
    }

    $ledgerHealth = Test-ValidationLedgerChain -ResolvedLedgerPath $resolvedLedgerPath
    if ($ledgerHealth.isValid) {
        return $null
    }

    $ledgerDirectory = Split-Path -Path $resolvedLedgerPath -Parent
    $ledgerBaseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedLedgerPath)
    $ledgerExtension = [System.IO.Path]::GetExtension($resolvedLedgerPath)
    $timestampToken = Get-Date -Format 'yyyyMMdd-HHmmss'
    $archivePath = Join-Path $ledgerDirectory ("{0}.broken-{1}{2}" -f $ledgerBaseName, $timestampToken, $ledgerExtension)

    Move-Item -LiteralPath $resolvedLedgerPath -Destination $archivePath -Force

    $latestLedgerPath = Resolve-RepoPath -Root $Root -Path '.temp/audit/validation-ledger.latest.json'
    if (Test-Path -LiteralPath $latestLedgerPath -PathType Leaf) {
        $latestArchivePath = Join-Path (Split-Path -Path $latestLedgerPath -Parent) ("validation-ledger.latest.broken-{0}.json" -f $timestampToken)
        Move-Item -LiteralPath $latestLedgerPath -Destination $latestArchivePath -Force
    }

    Write-StyledOutput ("[INFO] Archived broken validation ledger and starting a new chain: {0} ({1})" -f [System.IO.Path]::GetRelativePath($Root, $archivePath), $ledgerHealth.reason)

    return [pscustomobject]@{
        archivedLedgerPath = $archivePath
        reason = $ledgerHealth.reason
    }
}

# Gets selected validation profile object.
function Get-ValidationProfile {
    param(
        [string] $ProfilesFilePath,
        [string] $ProfileId
    )

    $profilesDocument = Read-JsonFile -Path $ProfilesFilePath -Label 'validation profiles'
    if ($null -eq $profilesDocument) {
        return $null
    }

    $selectedProfileId = if ([string]::IsNullOrWhiteSpace($ProfileId)) {
        [string] $profilesDocument.defaultProfile
    }
    else {
        $ProfileId
    }

    $profiles = @($profilesDocument.profiles)
    foreach ($profileItem in $profiles) {
        if ([string] $profileItem.id -eq $selectedProfileId) {
            return $profileItem
        }
    }

    Add-SuiteWarning ("Validation profile not found: {0}" -f $selectedProfileId)
    return $null
}

# Writes a hash-chained ledger entry for this validation run.
function Write-ValidationLedgerEntry {
    param(
        [string] $Root,
        [string] $TargetLedgerPath,
        [string] $ProfileId,
        [bool] $IsWarningOnly,
        [object[]] $ResultList
    )

    $resolvedLedgerPath = Resolve-RepoPath -Root $Root -Path $TargetLedgerPath
    $ledgerParent = Split-Path -Path $resolvedLedgerPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($ledgerParent)) {
        New-Item -ItemType Directory -Path $ledgerParent -Force | Out-Null
    }

    $previousHash = ('0' * 64)
    if (Test-Path -LiteralPath $resolvedLedgerPath -PathType Leaf) {
        $existingLines = @(Get-Content -LiteralPath $resolvedLedgerPath)
        for ($index = $existingLines.Count - 1; $index -ge 0; $index--) {
            $line = [string] $existingLines[$index]
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            try {
                $entry = $line | ConvertFrom-Json -Depth 200
                $candidateHash = [string] $entry.entryHash
                if (-not [string]::IsNullOrWhiteSpace($candidateHash)) {
                    $previousHash = $candidateHash
                    break
                }
            }
            catch {
                Add-SuiteWarning 'Could not parse previous ledger line; chain will continue from zero-hash.'
                break
            }
        }
    }

    $gitState = Get-GitState -Root $Root
    $summary = [ordered]@{
        totalChecks = $ResultList.Count
        passed = @($ResultList | Where-Object { $_.status -eq 'passed' }).Count
        warnings = @($ResultList | Where-Object { $_.status -eq 'warning' }).Count
        failed = @($ResultList | Where-Object { $_.status -eq 'failed' }).Count
    }

    $payload = [ordered]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToString('o')
        profile = $ProfileId
        warningOnly = $IsWarningOnly
        git = $gitState
        summary = $summary
        checks = @($ResultList | ForEach-Object {
            [ordered]@{
                name = $_.name
                status = $_.status
                exitCode = $_.exitCode
                durationMs = $_.durationMs
            }
        })
    }

    $payloadJson = $payload | ConvertTo-Json -Depth 100 -Compress
    $payloadHash = Get-StringSha256Hash -Text $payloadJson
    $entryHash = Get-StringSha256Hash -Text ("{0}|{1}" -f $previousHash, $payloadHash)

    $ledgerEntry = [ordered]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToString('o')
        profile = $ProfileId
        warningOnly = $IsWarningOnly
        prevHash = $previousHash
        payloadHash = $payloadHash
        entryHash = $entryHash
        payloadJson = $payloadJson
    }

    Add-Content -LiteralPath $resolvedLedgerPath -Value ($ledgerEntry | ConvertTo-Json -Depth 100 -Compress)

    $latestPath = Resolve-RepoPath -Root $Root -Path '.temp/audit/validation-ledger.latest.json'
    $latestParent = Split-Path -Path $latestPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($latestParent)) {
        New-Item -ItemType Directory -Path $latestParent -Force | Out-Null
    }
    Set-Content -LiteralPath $latestPath -Value ($ledgerEntry | ConvertTo-Json -Depth 100)

    Write-StyledOutput ("[OK] Validation ledger entry appended: {0}" -f [System.IO.Path]::GetRelativePath($Root, $resolvedLedgerPath))
}

# Executes a validation script and returns a status record.
function Invoke-ValidationScript {
    param(
        [string] $Root,
        [string] $Name,
        [string] $RelativeScriptPath,
        [hashtable] $Arguments,
        [bool] $TreatFailureAsWarning
    )

    $startedAt = Get-Date
    $resolvedScriptPath = Resolve-RepoPath -Root $Root -Path $RelativeScriptPath
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if (-not (Test-Path -LiteralPath $resolvedScriptPath -PathType Leaf)) {
        $errorMessage = "Script not found: $RelativeScriptPath"
        if ($TreatFailureAsWarning) {
            $status = 'warning'
            $exitCode = 0
            Write-StyledOutput ("[WARN] {0}: {1}" -f $Name, $errorMessage)
        }
        else {
            Write-StyledOutput ("[FAIL] {0}: {1}" -f $Name, $errorMessage)
        }
    }
    else {
        Write-StyledOutput ("[RUN] {0}" -f $Name)
        try {
            & $resolvedScriptPath @Arguments | Out-Host
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }

            if ($exitCode -eq 0) {
                $status = 'passed'
                Write-StyledOutput ("[OK] {0}" -f $Name)
            }
            elseif ($TreatFailureAsWarning) {
                $status = 'warning'
                $exitCode = 0
                Write-StyledOutput ("[WARN] {0} (non-zero exit converted to warning)" -f $Name)
            }
            else {
                $status = 'failed'
                Write-StyledOutput ("[FAIL] {0} (exit code {1})" -f $Name, $exitCode)
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($TreatFailureAsWarning) {
                $status = 'warning'
                $exitCode = 0
                Write-StyledOutput ("[WARN] {0} (exception converted to warning: {1})" -f $Name, $errorMessage)
            }
            else {
                $status = 'failed'
                $exitCode = 1
                Write-StyledOutput ("[FAIL] {0} (exception: {1})" -f $Name, $errorMessage)
            }
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
Repair-ValidationLedgerIfNeeded -Root $resolvedRepoRoot -TargetLedgerPath $LedgerPath | Out-Null

$profileFilePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ValidationProfilesPath
$selectedProfile = Get-ValidationProfile -ProfilesFilePath $profileFilePath -ProfileId $ValidationProfile
$profileId = if ($null -eq $selectedProfile) { 'custom' } else { [string] $selectedProfile.id }

$profileWarningOnly = if ($null -eq $selectedProfile) { $false } else { [bool] $selectedProfile.warningOnly }
$resolvedWarningOnly = Convert-ToBooleanValue -Value $WarningOnly -ParameterName 'WarningOnly' -DefaultValue $true
$effectiveWarningOnly = [bool] ($resolvedWarningOnly -or $profileWarningOnly)

if ($effectiveWarningOnly) {
    Write-StyledOutput '[INFO] validate-all running in warning-only mode.'
}
else {
    Write-StyledOutput '[INFO] validate-all running in enforcing mode.'
}

$baseCheckDefinitions = @{}
$baseCheckDefinitions['validate-instructions'] = [pscustomobject]@{
    name = 'validate-instructions'
    script = 'scripts/validation/validate-instructions.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-policy'] = [pscustomobject]@{
    name = 'validate-policy'
    script = 'scripts/validation/validate-policy.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-security-baseline'] = [pscustomobject]@{
    name = 'validate-security-baseline'
    script = 'scripts/validation/validate-security-baseline.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-shared-script-checksums'] = [pscustomobject]@{
    name = 'validate-shared-script-checksums'
    script = 'scripts/validation/validate-shared-script-checksums.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-agent-orchestration'] = [pscustomobject]@{
    name = 'validate-agent-orchestration'
    script = 'scripts/validation/validate-agent-orchestration.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-agent-skill-alignment'] = [pscustomobject]@{
    name = 'validate-agent-skill-alignment'
    script = 'scripts/validation/validate-agent-skill-alignment.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-agent-permissions'] = [pscustomobject]@{
    name = 'validate-agent-permissions'
    script = 'scripts/validation/validate-agent-permissions.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-planning-structure'] = [pscustomobject]@{
    name = 'validate-planning-structure'
    script = 'scripts/validation/validate-planning-structure.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-routing-coverage'] = [pscustomobject]@{
    name = 'validate-routing-coverage'
    script = 'scripts/validation/validate-routing-coverage.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-authoritative-source-policy'] = [pscustomobject]@{
    name = 'validate-authoritative-source-policy'
    script = 'scripts/validation/validate-authoritative-source-policy.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-instruction-architecture'] = [pscustomobject]@{
    name = 'validate-instruction-architecture'
    script = 'scripts/validation/validate-instruction-architecture.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-readme-standards'] = [pscustomobject]@{
    name = 'validate-readme-standards'
    script = 'scripts/validation/validate-readme-standards.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-template-standards'] = [pscustomobject]@{
    name = 'validate-template-standards'
    script = 'scripts/validation/validate-template-standards.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-workspace-efficiency'] = [pscustomobject]@{
    name = 'validate-workspace-efficiency'
    script = 'scripts/validation/validate-workspace-efficiency.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-compatibility-lifecycle-policy'] = [pscustomobject]@{
    name = 'validate-compatibility-lifecycle-policy'
    script = 'scripts/validation/validate-compatibility-lifecycle-policy.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}

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
$baseCheckDefinitions['validate-powershell-standards'] = [pscustomobject]@{
    name = 'validate-powershell-standards'
    script = 'scripts/validation/validate-powershell-standards.ps1'
    args = $powershellArgs
}

$baseCheckDefinitions['validate-agent-hooks'] = [pscustomobject]@{
    name = 'validate-agent-hooks'
    script = 'scripts/validation/validate-agent-hooks.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}

$baseCheckDefinitions['validate-shell-hooks'] = [pscustomobject]@{
    name = 'validate-shell-hooks'
    script = 'scripts/validation/validate-shell-hooks.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}

$baseCheckDefinitions['validate-runtime-script-tests'] = [pscustomobject]@{
    name = 'validate-runtime-script-tests'
    script = 'scripts/validation/validate-runtime-script-tests.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}

$baseCheckDefinitions['validate-warning-baseline'] = [pscustomobject]@{
    name = 'validate-warning-baseline'
    script = 'scripts/validation/validate-warning-baseline.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-dotnet-standards'] = [pscustomobject]@{
    name = 'validate-dotnet-standards'
    script = 'scripts/validation/validate-dotnet-standards.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-architecture-boundaries'] = [pscustomobject]@{
    name = 'validate-architecture-boundaries'
    script = 'scripts/validation/validate-architecture-boundaries.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-instruction-metadata'] = [pscustomobject]@{
    name = 'validate-instruction-metadata'
    script = 'scripts/validation/validate-instruction-metadata.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-supply-chain'] = [pscustomobject]@{
    name = 'validate-supply-chain'
    script = 'scripts/validation/validate-supply-chain.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-release-governance'] = [pscustomobject]@{
    name = 'validate-release-governance'
    script = 'scripts/validation/validate-release-governance.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-release-provenance'] = [pscustomobject]@{
    name = 'validate-release-provenance'
    script = 'scripts/validation/validate-release-provenance.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-audit-ledger'] = [pscustomobject]@{
    name = 'validate-audit-ledger'
    script = 'scripts/validation/validate-audit-ledger.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}

$defaultCheckOrder = @(
    'validate-instructions',
    'validate-policy',
    'validate-security-baseline',
    'validate-shared-script-checksums',
    'validate-agent-orchestration',
    'validate-agent-skill-alignment',
    'validate-agent-permissions',
    'validate-planning-structure',
    'validate-routing-coverage',
    'validate-authoritative-source-policy',
    'validate-instruction-architecture',
    'validate-readme-standards',
    'validate-template-standards',
    'validate-workspace-efficiency',
    'validate-compatibility-lifecycle-policy',
    'validate-powershell-standards',
    'validate-agent-hooks',
    'validate-shell-hooks',
    'validate-runtime-script-tests',
    'validate-warning-baseline',
    'validate-dotnet-standards',
    'validate-architecture-boundaries',
    'validate-instruction-metadata',
    'validate-supply-chain',
    'validate-release-governance',
    'validate-release-provenance',
    'validate-audit-ledger'
)

$selectedCheckOrder = if ($null -eq $selectedProfile) {
    $defaultCheckOrder
}
else {
    $profileChecks = @($selectedProfile.checkOrder | ForEach-Object { [string] $_ })
    if ($profileChecks.Count -eq 0) { $defaultCheckOrder } else { $profileChecks }
}

$profileCheckOptionMap = if ($null -eq $selectedProfile) { @{} } else { Convert-ToHashtable -Value $selectedProfile.checkOptions }

$results = New-Object System.Collections.Generic.List[object]
foreach ($checkName in $selectedCheckOrder) {
    if (-not $baseCheckDefinitions.ContainsKey($checkName)) {
        Add-SuiteWarning ("Profile references unknown check '{0}' and it will be skipped." -f $checkName)
        continue
    }

    $definition = $baseCheckDefinitions[$checkName]
    $checkArguments = Copy-Hashtable -Source $definition.args
    $checkWarningOnly = $effectiveWarningOnly
    $checkOptionObject = $null
    if ($profileCheckOptionMap.ContainsKey($checkName)) {
        $checkOptionObject = $profileCheckOptionMap[$checkName]
    }

    $checkOptions = Convert-ToHashtable -Value $checkOptionObject
    foreach ($optionKey in $checkOptions.Keys) {
        if ($optionKey -eq 'WarningOnly') {
            $profileCheckWarningOnly = [bool] $checkOptions[$optionKey]
            $checkWarningOnly = [bool] ($checkWarningOnly -or $profileCheckWarningOnly)
            continue
        }

        $checkArguments[$optionKey] = $checkOptions[$optionKey]
    }

    $resolvedScriptPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $definition.script
    if (Test-ScriptSupportsParameter -ScriptPath $resolvedScriptPath -ParameterName 'WarningOnly') {
        $checkArguments['WarningOnly'] = $checkWarningOnly
    }

    $result = Invoke-ValidationScript `
        -Root $resolvedRepoRoot `
        -Name $definition.name `
        -RelativeScriptPath $definition.script `
        -Arguments $checkArguments `
        -TreatFailureAsWarning:$checkWarningOnly

$results.Add($result) | Out-Null
}

$passed = @($results | Where-Object { $_.status -eq 'passed' }).Count
$warningChecks = @($results | Where-Object { $_.status -eq 'warning' }).Count
$failed = @($results | Where-Object { $_.status -eq 'failed' }).Count
$suiteFinishedAt = Get-Date
$totalDurationMs = [int] ($suiteFinishedAt - $script:SuiteStartedAt).TotalMilliseconds
$durationSum = (@($results | Measure-Object -Property durationMs -Sum).Sum)
if ($null -eq $durationSum) {
    $durationSum = 0
}
$averageCheckDurationMs = if ($results.Count -gt 0) {
    [math]::Round(([double]$durationSum / [double]$results.Count), 2)
}
else {
    0
}

Write-StyledOutput ''
Write-StyledOutput 'Validation suite summary'
Write-StyledOutput ("  Profile: {0}" -f $profileId)
Write-StyledOutput ("  Warning-only mode: {0}" -f $effectiveWarningOnly)
Write-StyledOutput ("  Total checks: {0}" -f $results.Count)
Write-StyledOutput ("  Passed: {0}" -f $passed)
Write-StyledOutput ("  Warnings: {0}" -f $warningChecks)
Write-StyledOutput ("  Failed: {0}" -f $failed)
Write-StyledOutput ("  Duration (ms): {0}" -f $totalDurationMs)
Write-StyledOutput ("  Average check duration (ms): {0}" -f $averageCheckDurationMs)

$suiteWarningCount = Get-SuiteWarningCount
if ($suiteWarningCount -gt 0) {
    Write-StyledOutput ("  Suite warnings: {0}" -f $suiteWarningCount)
}

if ($WriteLedger) {
    try {
        Write-ValidationLedgerEntry -Root $resolvedRepoRoot -TargetLedgerPath $LedgerPath -ProfileId $profileId -IsWarningOnly $effectiveWarningOnly -ResultList $results.ToArray()
    }
    catch {
        Add-SuiteWarning ("Could not write validation ledger: {0}" -f $_.Exception.Message)
        if (-not $effectiveWarningOnly) {
            $failed++
        }
    }
}

$resolvedOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $OutputPath
$reportParent = Get-ParentDirectoryPath -Path $resolvedOutputPath
if (-not [string]::IsNullOrWhiteSpace($reportParent)) {
    New-Item -ItemType Directory -Path $reportParent -Force | Out-Null
}

$slowestChecks = @(
    $results |
        Sort-Object -Property durationMs -Descending |
        Select-Object -First 5 |
        ForEach-Object {
            [ordered]@{
                name = $_.name
                durationMs = $_.durationMs
                status = $_.status
            }
        }
)

$suiteWarningList = @()
if ($null -ne $script:Warnings) {
    if ($script:Warnings -is [System.Collections.Generic.List[string]]) {
        $suiteWarningList = @($script:Warnings.ToArray())
    }
    else {
        $suiteWarningList = @($script:Warnings)
    }
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = $suiteFinishedAt.ToString('o')
    profile = $profileId
    warningOnly = [bool] $effectiveWarningOnly
    repoRoot = $resolvedRepoRoot
    summary = [ordered]@{
        totalChecks = $results.Count
        passed = $passed
        warnings = $warningChecks
        failed = $failed
        suiteWarnings = $suiteWarningCount
    }
    performance = [ordered]@{
        totalDurationMs = $totalDurationMs
        averageCheckDurationMs = $averageCheckDurationMs
        slowestChecks = $slowestChecks
    }
    checks = @($results | ForEach-Object {
        [ordered]@{
            name = $_.name
            script = $_.script
            status = $_.status
            exitCode = $_.exitCode
            durationMs = $_.durationMs
            error = $_.error
        }
    })
    suiteWarningMessages = $suiteWarningList
}

try {
    Set-Content -LiteralPath $resolvedOutputPath -Value ($report | ConvertTo-Json -Depth 100)
    Write-StyledOutput ("  Report: {0}" -f [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $resolvedOutputPath))
}
catch {
    Add-SuiteWarning ("Could not write validation report: {0}" -f $_.Exception.Message)
    if (-not $effectiveWarningOnly) {
        $failed++
    }
}

if ($failed -gt 0) {
    Write-StyledOutput ''
    Write-StyledOutput 'Failed checks'
    foreach ($failedResult in ($results | Where-Object { $_.status -eq 'failed' })) {
        $errorDetail = if ([string]::IsNullOrWhiteSpace([string] $failedResult.error)) { '' } else { " :: $($failedResult.error)" }
        Write-StyledOutput ("  - {0} (exit {1}){2}" -f $failedResult.name, $failedResult.exitCode, $errorDetail)
    }

    if (-not $effectiveWarningOnly) {
        exit 1
    }
}

if ($warningChecks -gt 0 -or $suiteWarningCount -gt 0) {
    Write-StyledOutput 'Validation suite completed with warnings.'
}
else {
    Write-StyledOutput 'All validation checks passed.'
}

Complete-ValidationSession -Metrics ([ordered]@{
        'Profile' = $profileId
        'Total checks' = $results.Count
        'Passed' = $passed
        'Warnings' = $warningChecks
        'Failures' = $failed
        'Suite warnings' = $suiteWarningCount
    }) | Out-Null

exit 0