<#
.SYNOPSIS
    Shared helpers for local and global Git hook EOF hygiene settings.

.DESCRIPTION
    Loads the versioned EOF-hook mode catalog and resolves the effective
    selection from local-repo and global machine-level settings.

.PARAMETER None
    This helper script does not require input parameters.

.EXAMPLE
    . ./scripts/common/git-hook-eof-settings.ps1
    $mode = Get-EffectiveGitHookEofMode -ResolvedRepoRoot $RepoRoot

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git.
#>

param()

$ErrorActionPreference = 'Stop'

# Reads a boolean property from a PSObject while tolerating missing members.
function Get-GitHookModeBooleanValue {
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

# Resolves a user home path for global settings without requiring runtime helpers.
function Resolve-GitHookEofUserHomePath {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return [System.IO.Path]::GetFullPath($env:USERPROFILE)
    }

    if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        return [System.IO.Path]::GetFullPath($HOME)
    }

    $folder = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($folder)) {
        return [System.IO.Path]::GetFullPath($folder)
    }

    throw 'Could not resolve user home path for Git hook EOF settings.'
}

# Resolves the versioned catalog path for EOF hook modes.
function Get-GitHookEofModeCatalogPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $localCatalogPath = Join-Path (Join-Path $ResolvedRepoRoot '.github') 'governance/git-hook-eof-modes.json'
    if (Test-Path -LiteralPath $localCatalogPath -PathType Leaf) {
        return $localCatalogPath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_GIT_HOOK_EOF_CATALOG_PATH)) {
        $overrideCatalogPath = [System.IO.Path]::GetFullPath($env:CODEX_GIT_HOOK_EOF_CATALOG_PATH)
        if (Test-Path -LiteralPath $overrideCatalogPath -PathType Leaf) {
            return $overrideCatalogPath
        }
    }

    $globalCatalogPath = Join-Path (Join-Path (Resolve-GitHookEofUserHomePath) '.github') 'governance/git-hook-eof-modes.json'
    if (Test-Path -LiteralPath $globalCatalogPath -PathType Leaf) {
        return $globalCatalogPath
    }

    return $localCatalogPath
}

# Loads the versioned EOF hook mode catalog.
function Get-GitHookEofModeCatalog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $catalogPath = Get-GitHookEofModeCatalogPath -ResolvedRepoRoot $ResolvedRepoRoot
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Missing Git hook EOF mode catalog: $catalogPath"
    }

    $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -Depth 50
    if ([string]::IsNullOrWhiteSpace([string] $catalog.defaultMode)) {
        throw "Git hook EOF mode catalog is missing defaultMode: $catalogPath"
    }

    if ([string]::IsNullOrWhiteSpace([string] $catalog.defaultScope)) {
        throw "Git hook EOF mode catalog is missing defaultScope: $catalogPath"
    }

    $modeNames = @($catalog.modes.PSObject.Properties.Name | Sort-Object -Unique)
    if ($modeNames.Count -eq 0) {
        throw "Git hook EOF mode catalog does not define any modes: $catalogPath"
    }

    $scopeNames = @($catalog.scopes.PSObject.Properties.Name | Sort-Object -Unique)
    if ($scopeNames.Count -eq 0) {
        throw "Git hook EOF mode catalog does not define any scopes: $catalogPath"
    }

    return [pscustomobject]@{
        Path = $catalogPath
        DefaultMode = [string] $catalog.defaultMode
        DefaultScope = [string] $catalog.defaultScope
        ModeNames = $modeNames
        ScopeNames = $scopeNames
        Catalog = $catalog
    }
}

# Resolves a supported EOF hook scope definition from the catalog.
function Resolve-GitHookEofScope {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $ScopeName
    )

    $catalogInfo = Get-GitHookEofModeCatalog -ResolvedRepoRoot $ResolvedRepoRoot
    $catalog = $catalogInfo.Catalog
    $effectiveScopeName = if (-not [string]::IsNullOrWhiteSpace($ScopeName)) { $ScopeName } else { $catalogInfo.DefaultScope }

    $scopeNode = $catalog.scopes.PSObject.Properties[$effectiveScopeName]
    if ($null -eq $scopeNode) {
        $validScopes = $catalogInfo.ScopeNames -join ', '
        throw "Unknown Git hook EOF scope '$effectiveScopeName'. Valid scopes: $validScopes"
    }

    $scope = $scopeNode.Value
    return [pscustomobject]@{
        Name = $effectiveScopeName
        Description = [string] $scope.description
        CatalogPath = $catalogInfo.Path
        DefaultScope = $catalogInfo.DefaultScope
        AvailableScopes = $catalogInfo.ScopeNames
    }
}

# Resolves the local Git-directory-backed settings path for the current repository.
function Resolve-LocalGitHookEofSettingsPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $settingsPath = & git -C $ResolvedRepoRoot rev-parse --git-path codex-hook-eof-settings.json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($settingsPath)) {
        throw "Could not resolve local Git hook EOF settings path for repository: $ResolvedRepoRoot"
    }

    $trimmedPath = $settingsPath.Trim()
    if ([System.IO.Path]::IsPathRooted($trimmedPath)) {
        return $trimmedPath
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $trimmedPath))
}

# Resolves the global machine-level settings path for EOF hook mode selection.
function Resolve-GlobalGitHookEofSettingsPath {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH)) {
        return [System.IO.Path]::GetFullPath($env:CODEX_GIT_HOOK_EOF_SETTINGS_PATH)
    }

    return (Join-Path (Join-Path (Resolve-GitHookEofUserHomePath) '.codex') 'git-hook-eof-settings.json')
}

# Resolves a scope-aware settings path for EOF hook mode selection.
function Resolve-GitHookEofSettingsPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $ScopeName
    )

    $resolvedScope = Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $ScopeName
    if ($resolvedScope.Name -eq 'global') {
        return Resolve-GlobalGitHookEofSettingsPath
    }

    return Resolve-LocalGitHookEofSettingsPath -ResolvedRepoRoot $ResolvedRepoRoot
}

# Resolves a supported EOF hook mode definition from the catalog.
function Resolve-GitHookEofMode {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $ModeName
    )

    $catalogInfo = Get-GitHookEofModeCatalog -ResolvedRepoRoot $ResolvedRepoRoot
    $catalog = $catalogInfo.Catalog
    $effectiveModeName = if (-not [string]::IsNullOrWhiteSpace($ModeName)) { $ModeName } else { $catalogInfo.DefaultMode }

    $modeNode = $catalog.modes.PSObject.Properties[$effectiveModeName]
    if ($null -eq $modeNode) {
        $validModes = $catalogInfo.ModeNames -join ', '
        throw "Unknown Git hook EOF mode '$effectiveModeName'. Valid modes: $validModes"
    }

    $mode = $modeNode.Value
    return [pscustomobject]@{
        Name = $effectiveModeName
        Description = [string] $mode.description
        AutoFixStagedFiles = (Get-GitHookModeBooleanValue -InputObject $mode -PropertyName 'autoFixStagedFiles')
        CatalogPath = $catalogInfo.Path
        DefaultMode = $catalogInfo.DefaultMode
        AvailableModes = $catalogInfo.ModeNames
    }
}

# Reads a persisted EOF hook mode selection from disk when present.
function Read-GitHookEofModeSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SettingsPath
    )

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return $null
    }

    return (Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json -Depth 20)
}

# Persists the selected EOF hook mode for the requested scope.
function Set-GitHookEofModeSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $ModeName,
        [string] $ScopeName
    )

    $resolvedMode = Resolve-GitHookEofMode -ResolvedRepoRoot $ResolvedRepoRoot -ModeName $ModeName
    $resolvedScope = Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $ScopeName
    $settingsPath = Resolve-GitHookEofSettingsPath -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $resolvedScope.Name
    $settingsParent = Split-Path -Path $settingsPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($settingsParent)) {
        New-Item -ItemType Directory -Path $settingsParent -Force | Out-Null
    }

    $payload = [ordered]@{
        schemaVersion = 1
        selectedMode = $resolvedMode.Name
        selectedScope = $resolvedScope.Name
        updatedAt = (Get-Date).ToString('o')
        catalogPath = $resolvedMode.CatalogPath
    }

    Set-Content -LiteralPath $settingsPath -Value ($payload | ConvertTo-Json -Depth 10)

    return [pscustomobject]@{
        Mode = $resolvedMode
        Scope = $resolvedScope
        SettingsPath = $settingsPath
    }
}

# Returns the effective EOF hook mode for the repository, falling back to global then catalog defaults.
function Get-EffectiveGitHookEofMode {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot
    )

    $catalogInfo = Get-GitHookEofModeCatalog -ResolvedRepoRoot $ResolvedRepoRoot
    $selectedMode = $null
    $source = 'catalog-default'
    $effectiveScope = Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $null
    $localSettingsPath = Resolve-LocalGitHookEofSettingsPath -ResolvedRepoRoot $ResolvedRepoRoot
    $globalSettingsPath = Resolve-GlobalGitHookEofSettingsPath

    $localSettings = Read-GitHookEofModeSelection -SettingsPath $localSettingsPath
    if ($null -ne $localSettings -and -not [string]::IsNullOrWhiteSpace([string] $localSettings.selectedMode)) {
        $selectedMode = [string] $localSettings.selectedMode
        $source = 'local-settings'
        $effectiveScope = Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName 'local-repo'
    }

    if ($null -eq $selectedMode) {
        $globalSettings = Read-GitHookEofModeSelection -SettingsPath $globalSettingsPath
        if ($null -ne $globalSettings -and -not [string]::IsNullOrWhiteSpace([string] $globalSettings.selectedMode)) {
            $selectedMode = [string] $globalSettings.selectedMode
            $source = 'global-settings'
            $effectiveScope = Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName 'global'
        }
    }

    $resolvedMode = Resolve-GitHookEofMode -ResolvedRepoRoot $ResolvedRepoRoot -ModeName $selectedMode
    return [pscustomobject]@{
        Name = $resolvedMode.Name
        Description = $resolvedMode.Description
        AutoFixStagedFiles = $resolvedMode.AutoFixStagedFiles
        Scope = $effectiveScope.Name
        ScopeDescription = $effectiveScope.Description
        CatalogPath = $resolvedMode.CatalogPath
        DefaultMode = $resolvedMode.DefaultMode
        AvailableModes = $resolvedMode.AvailableModes
        DefaultScope = $effectiveScope.DefaultScope
        AvailableScopes = $effectiveScope.AvailableScopes
        SettingsPath = if ($source -eq 'local-settings') { $localSettingsPath } elseif ($source -eq 'global-settings') { $globalSettingsPath } else { $null }
        LocalSettingsPath = $localSettingsPath
        GlobalSettingsPath = $globalSettingsPath
        Source = $source
    }
}

# Removes the EOF hook mode selection file for the requested scope.
function Remove-GitHookEofModeSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $ScopeName
    )

    $resolvedScope = Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $ScopeName
    $settingsPath = Resolve-GitHookEofSettingsPath -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $resolvedScope.Name
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        Remove-Item -LiteralPath $settingsPath -Force
    }

    return $settingsPath
}