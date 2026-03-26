<#
.SYNOPSIS
    Shared helpers for repository-owned runtime installation profiles.

.DESCRIPTION
    Loads the versioned runtime-install profile catalog and resolves the
    effective profile contract used by install/bootstrap/doctor/healthcheck
    style scripts.

.PARAMETER None
    This helper script does not require input parameters.

.EXAMPLE
    . ./scripts/common/runtime-install-profiles.ps1
    $profile = Resolve-RuntimeInstallProfile -ResolvedRepoRoot $RepoRoot -ProfileName 'github'

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param()

$ErrorActionPreference = 'Stop'

# Reads a boolean property from a PSObject while tolerating missing members.
function Get-ProfileBooleanValue {
    param(
        [object] $InputObject,
        [string] $PropertyName,
        [bool] $DefaultValue = $false
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return [bool] $property.Value
}

# Resolves the catalog path for versioned runtime install profiles.
function Get-RuntimeInstallProfileCatalogPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    return (Join-Path (Join-Path $ResolvedRepoRoot '.github') 'governance/runtime-install-profiles.json')
}

# Loads the versioned runtime install profile catalog.
function Get-RuntimeInstallProfileCatalog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $catalogPath = Get-RuntimeInstallProfileCatalogPath -ResolvedRepoRoot $ResolvedRepoRoot
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Missing runtime install profile catalog: $catalogPath"
    }

    $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -Depth 50
    if ([string]::IsNullOrWhiteSpace([string] $catalog.defaultProfile)) {
        throw "Runtime install profile catalog is missing defaultProfile: $catalogPath"
    }

    $profileNames = @($catalog.profiles.PSObject.Properties.Name | Sort-Object -Unique)
    if ($profileNames.Count -eq 0) {
        throw "Runtime install profile catalog does not define any profiles: $catalogPath"
    }

    return [pscustomobject]@{
        Path = $catalogPath
        DefaultProfile = [string] $catalog.defaultProfile
        ProfileNames = $profileNames
        Catalog = $catalog
    }
}

# Resolves the effective runtime install profile for a script invocation.
function Resolve-RuntimeInstallProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $ProfileName,
        [string] $FallbackProfileName
    )

    $catalogInfo = Get-RuntimeInstallProfileCatalog -ResolvedRepoRoot $ResolvedRepoRoot
    $catalog = $catalogInfo.Catalog

    $effectiveProfileName = if (-not [string]::IsNullOrWhiteSpace($ProfileName)) {
        $ProfileName
    }
    elseif (-not [string]::IsNullOrWhiteSpace($FallbackProfileName)) {
        $FallbackProfileName
    }
    else {
        $catalogInfo.DefaultProfile
    }

    $profileNode = $catalog.profiles.PSObject.Properties[$effectiveProfileName]
    if ($null -eq $profileNode) {
        $validProfiles = $catalogInfo.ProfileNames -join ', '
        throw "Unknown runtime profile '$effectiveProfileName'. Valid profiles: $validProfiles"
    }

    $profile = $profileNode.Value
    $installNode = $profile.install
    $runtimeNode = $profile.runtime

    return [pscustomobject]@{
        Name = $effectiveProfileName
        Description = [string] $profile.description
        CatalogPath = $catalogInfo.Path
        DefaultProfile = $catalogInfo.DefaultProfile
        AvailableProfiles = $catalogInfo.ProfileNames
        InstallBootstrap = (Get-ProfileBooleanValue -InputObject $installNode -PropertyName 'bootstrap')
        InstallGlobalVscodeSettings = (Get-ProfileBooleanValue -InputObject $installNode -PropertyName 'globalVscodeSettings')
        InstallGlobalVscodeSnippets = (Get-ProfileBooleanValue -InputObject $installNode -PropertyName 'globalVscodeSnippets')
        InstallLocalGitHooks = (Get-ProfileBooleanValue -InputObject $installNode -PropertyName 'localGitHooks')
        InstallGlobalGitAliases = (Get-ProfileBooleanValue -InputObject $installNode -PropertyName 'globalGitAliases')
        InstallHealthcheck = (Get-ProfileBooleanValue -InputObject $installNode -PropertyName 'healthcheck')
        EnableGithubRuntime = (Get-ProfileBooleanValue -InputObject $runtimeNode -PropertyName 'github')
        EnableCodexRuntime = (Get-ProfileBooleanValue -InputObject $runtimeNode -PropertyName 'codex')
        EnableClaudeRuntime = (Get-ProfileBooleanValue -InputObject $runtimeNode -PropertyName 'claude')
    }
}