<#
.SYNOPSIS
    Resolves repository-owned Codex runtime hygiene defaults.

.DESCRIPTION
    Loads the versioned Codex runtime hygiene catalog from either the repository
    `.github/governance` surface or the mirrored runtime `~/.github/governance`
    surface. The helper returns deterministic defaults used by runtime config
    preference scripts and by session/log cleanup automation.

.PARAMETER ResolvedRepoRoot
    Optional resolved repository root. When omitted, the helper falls back to
    the mirrored runtime governance surface under the effective `.github`
    runtime root.

.EXAMPLE
    . ./scripts/common/codex-runtime-hygiene.ps1
    Get-CodexRuntimeHygieneSettings -ResolvedRepoRoot .

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Safely reads an optional object property.
function Get-OptionalHygieneProperty {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject -or [string]::IsNullOrWhiteSpace($PropertyName)) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Converts an optional catalog property into a nullable positive integer.
function Get-OptionalPositiveIntegerSetting {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    $rawValue = Get-OptionalHygieneProperty -InputObject $InputObject -PropertyName $PropertyName
    if ($null -eq $rawValue) {
        return $null
    }

    $parsedValue = 0
    if (-not [int]::TryParse([string] $rawValue, [ref] $parsedValue)) {
        throw ("Codex runtime hygiene catalog contains non-integer {0} value '{1}'." -f $PropertyName, $rawValue)
    }

    if ($parsedValue -lt 1) {
        throw ("Codex runtime hygiene catalog contains invalid {0} value '{1}'." -f $PropertyName, $parsedValue)
    }

    return [Nullable[int]] $parsedValue
}

# Resolves the governance catalog path for Codex runtime hygiene defaults.
function Resolve-CodexRuntimeHygieneCatalogPath {
    param(
        [string] $ResolvedRepoRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ResolvedRepoRoot)) {
        $repoCatalogPath = Join-Path $ResolvedRepoRoot '.github\governance\codex-runtime-hygiene.catalog.json'
        if (Test-Path -LiteralPath $repoCatalogPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $repoCatalogPath).Path
        }
    }

    $scriptRelativeCatalogPath = Join-Path (Join-Path (Join-Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) '.github') 'governance') 'codex-runtime-hygiene.catalog.json'
    if (Test-Path -LiteralPath $scriptRelativeCatalogPath -PathType Leaf) {
        return (Resolve-Path -LiteralPath $scriptRelativeCatalogPath).Path
    }

    $runtimeCatalogPath = Join-Path (Resolve-GithubRuntimePath) 'governance\codex-runtime-hygiene.catalog.json'
    if (Test-Path -LiteralPath $runtimeCatalogPath -PathType Leaf) {
        return (Resolve-Path -LiteralPath $runtimeCatalogPath).Path
    }

    throw 'Missing Codex runtime hygiene catalog. Expected .github/governance/codex-runtime-hygiene.catalog.json in the repository or mirrored runtime.'
}

# Loads and validates the Codex runtime hygiene catalog.
function Get-CodexRuntimeHygieneSettings {
    param(
        [string] $ResolvedRepoRoot
    )

    $catalogPath = Resolve-CodexRuntimeHygieneCatalogPath -ResolvedRepoRoot $ResolvedRepoRoot
    $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -Depth 50
    $defaults = Get-OptionalHygieneProperty -InputObject $catalog -PropertyName 'defaults'
    if ($null -eq $defaults) {
        throw ("Codex runtime hygiene catalog is missing the 'defaults' section: {0}" -f $catalogPath)
    }

    $reasoningEffort = [string] (Get-OptionalHygieneProperty -InputObject $defaults -PropertyName 'reasoningEffort')
    $multiAgentMode = [string] (Get-OptionalHygieneProperty -InputObject $defaults -PropertyName 'multiAgentMode')
    $logRetentionDays = Get-OptionalPositiveIntegerSetting -InputObject $defaults -PropertyName 'logRetentionDays'
    $sessionRetentionDays = Get-OptionalPositiveIntegerSetting -InputObject $defaults -PropertyName 'sessionRetentionDays'
    $maxSessionFileSizeMB = Get-OptionalPositiveIntegerSetting -InputObject $defaults -PropertyName 'maxSessionFileSizeMB'
    $oversizedSessionGraceHours = Get-OptionalPositiveIntegerSetting -InputObject $defaults -PropertyName 'oversizedSessionGraceHours'
    $maxSessionStorageGB = Get-OptionalPositiveIntegerSetting -InputObject $defaults -PropertyName 'maxSessionStorageGB'
    $sessionStorageGraceHours = Get-OptionalPositiveIntegerSetting -InputObject $defaults -PropertyName 'sessionStorageGraceHours'

    if ($reasoningEffort -notin @('low', 'medium', 'high', 'xhigh')) {
        throw ("Codex runtime hygiene catalog contains unsupported reasoningEffort '{0}'." -f $reasoningEffort)
    }

    if ($multiAgentMode -notin @('enabled', 'disabled')) {
        throw ("Codex runtime hygiene catalog contains unsupported multiAgentMode '{0}'." -f $multiAgentMode)
    }

    foreach ($requiredNumericSetting in @(
            @{ Name = 'logRetentionDays'; Value = $logRetentionDays },
            @{ Name = 'sessionRetentionDays'; Value = $sessionRetentionDays }
        )) {
        if ($null -eq $requiredNumericSetting.Value) {
            throw ("Codex runtime hygiene catalog is missing required {0}." -f $requiredNumericSetting.Name)
        }
    }

    return [pscustomobject]@{
        CatalogPath                = $catalogPath
        ReasoningEffort            = $reasoningEffort
        MultiAgentMode             = $multiAgentMode
        LogRetentionDays           = $logRetentionDays
        SessionRetentionDays       = $sessionRetentionDays
        MaxSessionFileSizeMB       = $maxSessionFileSizeMB
        OversizedSessionGraceHours = $oversizedSessionGraceHours
        MaxSessionStorageGB        = $maxSessionStorageGB
        SessionStorageGraceHours   = $sessionStorageGraceHours
    }
}