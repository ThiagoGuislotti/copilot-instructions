<#
.SYNOPSIS
    Shared helpers for VS Code user-runtime hygiene scripts.

.DESCRIPTION
    Resolves the global VS Code user profile path and loads the shared
    repository-owned hygiene catalog used by cleanup workflows.

.EXAMPLE
    . ./scripts/common/vscode-runtime-hygiene.ps1
    Resolve-GlobalVscodeUserPath

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

$ErrorActionPreference = 'Stop'

# Resolves the current user home path without depending on runtime-path helpers.
function Resolve-VscodeRuntimeHomePath {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return [System.IO.Path]::GetFullPath($env:USERPROFILE)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return [System.IO.Path]::GetFullPath($env:HOME)
    }

    return [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
}

# Reads and parses one JSON file for VS Code hygiene catalogs.
function Read-VscodeHygieneJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing VS Code hygiene JSON file: $Path"
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 50
    }
    catch {
        throw ("Invalid VS Code hygiene JSON file '{0}': {1}" -f $Path, $_.Exception.Message)
    }
}

# Resolves the OS-aware VS Code global user path.
function Resolve-GlobalVscodeUserPath {
    param(
        [string] $RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath -PathType Container) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }

        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    $homePath = Resolve-VscodeRuntimeHomePath
    $candidates = @()

    if ($IsWindows) {
        if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
            $candidates += (Join-Path $env:APPDATA 'Code\User')
        }
        $candidates += (Join-Path $homePath 'AppData\Roaming\Code\User')
    }
    elseif ($IsMacOS) {
        $candidates += (Join-Path $homePath 'Library/Application Support/Code/User')
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
            $candidates += (Join-Path $env:XDG_CONFIG_HOME 'Code/User')
        }
        $candidates += (Join-Path $homePath '.config/Code/User')
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($candidates.Count -gt 0) {
        return [System.IO.Path]::GetFullPath($candidates[0])
    }

    throw 'Could not resolve VS Code global user path.'
}

# Resolves the shared VS Code hygiene catalog from repo or mirrored runtime roots.
function Resolve-VscodeHygieneCatalogPath {
    $repoRoot = $null
    try {
        $repoRoot = Resolve-RepositoryRoot -RequestedRoot $null
    }
    catch {
        $repoRoot = $null
    }
    $runtimeGithubRoot = if (Get-Command -Name Resolve-GitHubRuntimePath -ErrorAction SilentlyContinue) {
        Resolve-GitHubRuntimePath
    }
    else {
        Join-Path (Resolve-VscodeRuntimeHomePath) '.github'
    }

    $candidates = @(
        $(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot '.github\governance\vscode-runtime-hygiene.catalog.json' } else { $null }),
        $(if (-not [string]::IsNullOrWhiteSpace($runtimeGithubRoot)) { Join-Path $runtimeGithubRoot 'governance\vscode-runtime-hygiene.catalog.json' } else { $null })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'Missing vscode-runtime-hygiene.catalog.json in repository or mirrored runtime governance roots.'
}

# Loads the effective VS Code hygiene defaults.
function Get-VscodeRuntimeHygieneSettings {
    $catalogPath = Resolve-VscodeHygieneCatalogPath
    $catalog = Read-VscodeHygieneJsonFile -Path $catalogPath

    $defaults = $catalog.defaults
    if ($null -eq $defaults) {
        throw ("VS Code runtime hygiene catalog missing defaults: {0}" -f $catalogPath)
    }

    return [pscustomobject]@{
        CatalogPath                     = $catalogPath
        WorkspaceStorageRetentionDays   = [int] $defaults.workspaceStorageRetentionDays
        ChatSessionRetentionDays        = [int] $defaults.chatSessionRetentionDays
        ChatEditingSessionRetentionDays = [int] $defaults.chatEditingSessionRetentionDays
        TranscriptRetentionDays         = [int] $defaults.transcriptRetentionDays
        HistoryRetentionDays            = [int] $defaults.historyRetentionDays
        SettingsBackupRetentionDays     = [int] $defaults.settingsBackupRetentionDays
        MaxChatSessionFileSizeMB        = [int] $defaults.maxChatSessionFileSizeMB
        MaxCopilotWorkspaceIndexSizeMB  = [int] $defaults.maxCopilotWorkspaceIndexSizeMB
        OversizedFileGraceHours         = [int] $defaults.oversizedFileGraceHours
        RecentRunWindowHours            = [int] $defaults.recentRunWindowHours
    }
}