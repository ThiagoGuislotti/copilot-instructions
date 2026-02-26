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
    - validate-agent-orchestration
    - validate-agent-skill-alignment
    - validate-agent-permissions
    - validate-routing-coverage
    - validate-readme-standards
    - validate-powershell-standards
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

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1 -ValidationProfile release

.EXAMPLE
    pwsh -File scripts/validation/validate-all.ps1 -WarningOnly:$false -ValidationProfile enforced

.NOTES
    Version: 2.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ValidationProfile,
    [string] $ValidationProfilesPath = '.github/governance/validation-profiles.json',
    [switch] $IncludeAllPowershellScripts,
    [switch] $StrictPowershellStandards,
    [switch] $SkipPSScriptAnalyzer,
    [bool] $WarningOnly = $true,
    [bool] $WriteLedger = $true,
    [string] $LedgerPath = '.temp/audit/validation-ledger.jsonl',
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

# Registers script-level warning diagnostics.
function Add-SuiteWarning {
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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

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

$profileFilePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ValidationProfilesPath
$selectedProfile = Get-ValidationProfile -ProfilesFilePath $profileFilePath -ProfileId $ValidationProfile
$profileId = if ($null -eq $selectedProfile) { 'custom' } else { [string] $selectedProfile.id }

$profileWarningOnly = if ($null -eq $selectedProfile) { $false } else { [bool] $selectedProfile.warningOnly }
$effectiveWarningOnly = [bool] ($WarningOnly -or $profileWarningOnly)

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
$baseCheckDefinitions['validate-routing-coverage'] = [pscustomobject]@{
    name = 'validate-routing-coverage'
    script = 'scripts/validation/validate-routing-coverage.ps1'
    args = @{ RepoRoot = $resolvedRepoRoot }
}
$baseCheckDefinitions['validate-readme-standards'] = [pscustomobject]@{
    name = 'validate-readme-standards'
    script = 'scripts/validation/validate-readme-standards.ps1'
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
    'validate-agent-orchestration',
    'validate-agent-skill-alignment',
    'validate-agent-permissions',
    'validate-routing-coverage',
    'validate-readme-standards',
    'validate-powershell-standards',
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
$warnings = @($results | Where-Object { $_.status -eq 'warning' }).Count
$failed = @($results | Where-Object { $_.status -eq 'failed' }).Count

Write-StyledOutput ''
Write-StyledOutput 'Validation suite summary'
Write-StyledOutput ("  Profile: {0}" -f $profileId)
Write-StyledOutput ("  Warning-only mode: {0}" -f $effectiveWarningOnly)
Write-StyledOutput ("  Total checks: {0}" -f $results.Count)
Write-StyledOutput ("  Passed: {0}" -f $passed)
Write-StyledOutput ("  Warnings: {0}" -f $warnings)
Write-StyledOutput ("  Failed: {0}" -f $failed)

if ($script:Warnings.Count -gt 0) {
    Write-StyledOutput ("  Suite warnings: {0}" -f $script:Warnings.Count)
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

if ($warnings -gt 0 -or $script:Warnings.Count -gt 0) {
    Write-StyledOutput 'Validation suite completed with warnings.'
}
else {
    Write-StyledOutput 'All validation checks passed.'
}

exit 0