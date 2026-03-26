<#
.SYNOPSIS
    Shared runtime path helpers for cross-platform scripts.

.DESCRIPTION
    Provides helper functions to resolve local runtime paths in a
    cross-platform way for Windows, Linux, and macOS. Runtime locations are
    resolved from a versioned catalog plus an optional user-local override
    file so bootstrap, install, doctor, healthcheck, hooks, and helper tools
    use the same effective contract.

.PARAMETER None
    This helper script does not require input parameters.

.EXAMPLE
    . ./scripts/common/runtime-paths.ps1
    $homePath = Resolve-UserHomePath

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

param()

$ErrorActionPreference = 'Stop'
$script:RuntimePathsHelperRoot = Split-Path -Path $PSCommandPath -Parent
$script:RuntimeLocationCatalogCache = $null
$script:RuntimeLocationOverrideCache = $null

# Ensures script-scope cache variables exist even when the helper is loaded in
# isolated or re-entrant contexts during tests and mirrored runtime usage.
function Initialize-RuntimeLocationCaches {
    $helperRootVariable = Get-Variable -Name 'RuntimePathsHelperRoot' -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $helperRootVariable -or [string]::IsNullOrWhiteSpace([string] $helperRootVariable.Value)) {
        $script:RuntimePathsHelperRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            $PSScriptRoot
        }
        else {
            Join-Path (Get-Location) 'scripts/common'
        }
    }

    $catalogCacheVariable = Get-Variable -Name 'RuntimeLocationCatalogCache' -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $catalogCacheVariable) {
        $script:RuntimeLocationCatalogCache = $null
    }

    $overrideCacheVariable = Get-Variable -Name 'RuntimeLocationOverrideCache' -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $overrideCacheVariable) {
        $script:RuntimeLocationOverrideCache = $null
    }
}

# Resolves the current user home directory with cross-platform fallbacks.
function Resolve-UserHomePath {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return [System.IO.Path]::GetFullPath($env:USERPROFILE)
    }

    if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        return [System.IO.Path]::GetFullPath($HOME)
    }

    $profileFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($profileFolder)) {
        return [System.IO.Path]::GetFullPath($profileFolder)
    }

    throw 'Could not resolve user home path. Set USERPROFILE or HOME.'
}

# Joins path segments safely for the current operating system.
function Join-PathSegments {
    param(
        [Parameter(Mandatory = $true)]
        [string] $BasePath,
        [string[]] $Segments = @()
    )

    $currentPath = [System.IO.Path]::GetFullPath($BasePath)
    foreach ($segment in @($Segments | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })) {
        $currentPath = Join-Path $currentPath $segment
    }

    return $currentPath
}

# Returns the built-in runtime location catalog used when no versioned catalog is found.
function Get-BuiltInRuntimeLocationCatalog {
    return @{
        schemaVersion = 1
        settings = @{
            userOverrideRelativePath = '.codex/runtime-location-settings.json'
        }
        paths = @{
            githubRuntimeRoot = '${HOME}/.github'
            codexRuntimeRoot = '${HOME}/.codex'
            agentsSkillsRoot = '${HOME}/.agents/skills'
            copilotSkillsRoot = '${HOME}/.copilot/skills'
            codexGitHooksRoot = '${HOME}/.codex/git-hooks'
            claudeRuntimeRoot = '${HOME}/.claude'
        }
    }
}

# Resolves the default user-local runtime location override file path without reading the versioned catalog.
function Resolve-BuiltInRuntimeLocationSettingsPath {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH)) {
        return [System.IO.Path]::GetFullPath($env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH)
    }

    return Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.codex', 'runtime-location-settings.json')
}

# Expands runtime path placeholders and normalizes the result for the current OS.
function ConvertTo-ExpandedRuntimeLocationPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PathValue
    )

    $homePath = Resolve-UserHomePath
    $expandedPath = [string] $PathValue
    $expandedPath = $expandedPath.Replace('${HOME}', $homePath)
    $expandedPath = $expandedPath.Replace('$HOME', $homePath)
    $expandedPath = $expandedPath.Replace('%USERPROFILE%', $homePath)
    $expandedPath = $expandedPath.Replace('${USERPROFILE}', $homePath)
    $expandedPath = $expandedPath.Replace('${env:USERPROFILE}', $homePath)
    $expandedPath = $expandedPath.Replace('$env:USERPROFILE', $homePath)

    if ([System.IO.Path]::IsPathRooted($expandedPath)) {
        return [System.IO.Path]::GetFullPath($expandedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $homePath $expandedPath))
}

# Resolves the runtime location catalog path from environment, repository, or mirrored runtime candidates.
function Resolve-RuntimeLocationCatalogPath {
    Initialize-RuntimeLocationCaches

    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_RUNTIME_LOCATION_CATALOG_PATH)) {
        return [System.IO.Path]::GetFullPath($env:CODEX_RUNTIME_LOCATION_CATALOG_PATH)
    }

    $builtInSettingsPath = Resolve-BuiltInRuntimeLocationSettingsPath
    if (Test-Path -LiteralPath $builtInSettingsPath -PathType Leaf) {
        $settingsDocument = Get-Content -Raw -LiteralPath $builtInSettingsPath | ConvertFrom-Json -AsHashtable -Depth 20
        if ($settingsDocument.ContainsKey('paths') -and $settingsDocument.paths.ContainsKey('githubRuntimeRoot')) {
            $overrideGithubRoot = ConvertTo-ExpandedRuntimeLocationPath -PathValue ([string] $settingsDocument.paths.githubRuntimeRoot)
            $overrideCatalogPath = Join-PathSegments -BasePath $overrideGithubRoot -Segments @('governance', 'runtime-location-catalog.json')
            if (Test-Path -LiteralPath $overrideCatalogPath -PathType Leaf) {
                return (Resolve-Path -LiteralPath $overrideCatalogPath).Path
            }
        }
    }

    $candidatePaths = New-Object System.Collections.Generic.List[string]
    $relativeCandidates = @(
        $(Join-PathSegments -BasePath $script:RuntimePathsHelperRoot -Segments @('..', '..', '.github', 'governance', 'runtime-location-catalog.json')),
        $(Join-PathSegments -BasePath $script:RuntimePathsHelperRoot -Segments @('..', '..', 'governance', 'runtime-location-catalog.json')),
        $(Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.github', 'governance', 'runtime-location-catalog.json'))
    )

    foreach ($candidatePath in $relativeCandidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidatePath).Path
        }

        if (-not $candidatePaths.Contains($candidatePath)) {
            $candidatePaths.Add($candidatePath) | Out-Null
        }
    }

    return $null
}

# Loads the effective runtime location catalog.
function Get-RuntimeLocationCatalog {
    Initialize-RuntimeLocationCaches

    if ($null -ne $script:RuntimeLocationCatalogCache) {
        return $script:RuntimeLocationCatalogCache
    }

    $catalogPath = Resolve-RuntimeLocationCatalogPath
    $catalogData = Get-BuiltInRuntimeLocationCatalog

    if (-not [string]::IsNullOrWhiteSpace($catalogPath)) {
        $catalogData = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -AsHashtable -Depth 20
    }
    else {
        $catalogPath = '<built-in>'
    }

    $script:RuntimeLocationCatalogCache = [pscustomobject]@{
        path = $catalogPath
        data = $catalogData
    }

    return $script:RuntimeLocationCatalogCache
}

# Resolves the user-local runtime location override file path.
function Resolve-RuntimeLocationSettingsPath {
    $catalog = Get-RuntimeLocationCatalog
    $relativeOverridePath = [string] $catalog.data.settings.userOverrideRelativePath
    if ([string]::IsNullOrWhiteSpace($relativeOverridePath)) {
        $relativeOverridePath = '.codex/runtime-location-settings.json'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH)) {
        return [System.IO.Path]::GetFullPath($env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH)
    }

    return ConvertTo-ExpandedRuntimeLocationPath -PathValue $relativeOverridePath
}

# Loads the optional user-local runtime location override payload.
function Get-RuntimeLocationOverrideSettings {
    Initialize-RuntimeLocationCaches

    if ($null -ne $script:RuntimeLocationOverrideCache) {
        return $script:RuntimeLocationOverrideCache
    }

    $settingsPath = Resolve-RuntimeLocationSettingsPath
    $settingsData = @{}
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
        $settingsData = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -AsHashtable -Depth 20
    }

    $script:RuntimeLocationOverrideCache = [pscustomobject]@{
        path = $settingsPath
        exists = (Test-Path -LiteralPath $settingsPath -PathType Leaf)
        data = $settingsData
    }

    return $script:RuntimeLocationOverrideCache
}

# Resolves one configured runtime path from environment, user override, catalog, or fallback.
function Resolve-ConfiguredRuntimeLocation {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PathKey,
        [string] $EnvironmentVariableName,
        [Parameter(Mandatory = $true)]
        [string] $FallbackPath
    )

    if (-not [string]::IsNullOrWhiteSpace($EnvironmentVariableName)) {
        $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentVariableName)
        if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
            return ConvertTo-ExpandedRuntimeLocationPath -PathValue $environmentValue
        }
    }

    $overrideSettings = Get-RuntimeLocationOverrideSettings
    if ($overrideSettings.data.ContainsKey('paths') -and $overrideSettings.data.paths.ContainsKey($PathKey)) {
        $overrideValue = [string] $overrideSettings.data.paths[$PathKey]
        if (-not [string]::IsNullOrWhiteSpace($overrideValue)) {
            return ConvertTo-ExpandedRuntimeLocationPath -PathValue $overrideValue
        }
    }

    $catalog = Get-RuntimeLocationCatalog
    if ($catalog.data.ContainsKey('paths') -and $catalog.data.paths.ContainsKey($PathKey)) {
        $catalogValue = [string] $catalog.data.paths[$PathKey]
        if (-not [string]::IsNullOrWhiteSpace($catalogValue)) {
            return ConvertTo-ExpandedRuntimeLocationPath -PathValue $catalogValue
        }
    }

    return [System.IO.Path]::GetFullPath($FallbackPath)
}

# Resolves the local `.agents/skills` picker path used by VS Code and Codex skill discovery.
function Resolve-AgentsSkillsPath {
    return Resolve-ConfiguredRuntimeLocation -PathKey 'agentsSkillsRoot' -EnvironmentVariableName 'CODEX_AGENTS_SKILLS_PATH' -FallbackPath (Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.agents', 'skills'))
}

# Resolves the local `.github` runtime root used by shared GitHub/Copilot assets.
function Resolve-GithubRuntimePath {
    return Resolve-ConfiguredRuntimeLocation -PathKey 'githubRuntimeRoot' -EnvironmentVariableName 'CODEX_GITHUB_RUNTIME_PATH' -FallbackPath (Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.github'))
}

# Resolves the local `.codex` runtime root used by shared Codex assets.
function Resolve-CodexRuntimePath {
    return Resolve-ConfiguredRuntimeLocation -PathKey 'codexRuntimeRoot' -EnvironmentVariableName 'CODEX_CODEX_RUNTIME_PATH' -FallbackPath (Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.codex'))
}

# Resolves the personal Copilot skill path used by GitHub Copilot native skill discovery.
function Resolve-CopilotSkillsPath {
    return Resolve-ConfiguredRuntimeLocation -PathKey 'copilotSkillsRoot' -EnvironmentVariableName 'CODEX_COPILOT_SKILLS_PATH' -FallbackPath (Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.copilot', 'skills'))
}

# Resolves the managed global Git hooks path. Allows test/runtime overrides.
function Resolve-CodexGitHooksPath {
    return Resolve-ConfiguredRuntimeLocation -PathKey 'codexGitHooksRoot' -EnvironmentVariableName 'CODEX_GIT_HOOKS_PATH' -FallbackPath (Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.codex', 'git-hooks'))
}

# Resolves the Claude Code global runtime root (~/.claude). Allows test/runtime overrides.
function Resolve-ClaudeRuntimePath {
    return Resolve-ConfiguredRuntimeLocation -PathKey 'claudeRuntimeRoot' -EnvironmentVariableName 'CLAUDE_RUNTIME_PATH' -FallbackPath (Join-PathSegments -BasePath (Resolve-UserHomePath) -Segments @('.claude'))
}

# Resolves the shared Codex scripts path used by mirrored repository-owned helper tools.
function Resolve-CodexSharedScriptsPath {
    return Join-PathSegments -BasePath (Resolve-CodexRuntimePath) -Segments @('shared-scripts')
}

# Returns the effective runtime locations for diagnostics and orchestration output.
function Get-EffectiveRuntimeLocations {
    $catalog = Get-RuntimeLocationCatalog
    $override = Get-RuntimeLocationOverrideSettings

    return [pscustomobject]@{
        catalogPath = $catalog.path
        settingsPath = $override.path
        settingsExists = [bool] $override.exists
        githubRuntimeRoot = Resolve-GithubRuntimePath
        codexRuntimeRoot = Resolve-CodexRuntimePath
        agentsSkillsRoot = Resolve-AgentsSkillsPath
        copilotSkillsRoot = Resolve-CopilotSkillsPath
        codexGitHooksRoot = Resolve-CodexGitHooksPath
        codexSharedScriptsRoot = Resolve-CodexSharedScriptsPath
        claudeRuntimeRoot = Resolve-ClaudeRuntimePath
    }
}