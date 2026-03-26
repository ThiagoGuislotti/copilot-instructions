<#
.SYNOPSIS
    Cleans stale VS Code user-runtime artifacts that commonly bloat Copilot Chat state.

.DESCRIPTION
    Removes stale or oversized VS Code user-runtime artifacts under the global
    `Code/User` profile using a safe, policy-driven cleanup model:
    - old workspaceStorage directories
    - old Copilot chat session files
    - old chat editing session files
    - old Copilot transcript files
    - old History files
    - old settings/mcp backup files
    - oversized Copilot chat session files
    - oversized Copilot workspace local-index databases

    Default behavior is preview-only. Use -Apply to perform deletions.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user folder path. Defaults to the detected global
    Code/User profile for the current OS.

.PARAMETER WorkspaceStorageRetentionDays
    Optional number of days to keep untouched workspaceStorage workspace
    directories before removing the entire workspace state directory.

.PARAMETER ChatSessionRetentionDays
    Optional number of days to keep Copilot chat session files.

.PARAMETER ChatEditingSessionRetentionDays
    Optional number of days to keep Copilot chat editing session files.

.PARAMETER TranscriptRetentionDays
    Optional number of days to keep Copilot transcript files under
    GitHub.copilot-chat/transcripts.

.PARAMETER HistoryRetentionDays
    Optional number of days to keep VS Code user History files.

.PARAMETER SettingsBackupRetentionDays
    Optional number of days to keep timestamped settings/mcp backup files in
    the global VS Code user profile.

.PARAMETER MaxChatSessionFileSizeMB
    Optional maximum size for one Copilot chat session file. Larger files are
    removed once they are older than OversizedFileGraceHours.

.PARAMETER MaxCopilotWorkspaceIndexSizeMB
    Optional maximum size for one GitHub.copilot-chat local-index database.
    Larger files are removed once they are older than OversizedFileGraceHours.

.PARAMETER OversizedFileGraceHours
    Optional grace period before oversized session/index files are eligible for
    removal.

.PARAMETER RecentRunWindowHours
    Optional throttle window. When greater than zero and the cleanup already
    ran within that many hours, the script skips work.

.PARAMETER StateFilePath
    Optional state file path used to record the last cleanup timestamp for the
    recent-run throttle.

.PARAMETER Apply
    Executes deletions. When omitted, the script runs in preview mode only.

.PARAMETER ExportPlanningSummary
    Exports a concise planning handoff summary before cleanup so the next
    session can resume from active plan/spec artifacts instead of replaying a
    large chat history.

.PARAMETER RepoRoot
    Repository root used when ExportPlanningSummary is set. Defaults to the
    repository that owns this runtime script.

.PARAMETER DetailedOutput
    Prints additional diagnostics.

.PARAMETER Verbose
    Shows verbose session metadata.

.EXAMPLE
    pwsh -File scripts/runtime/clean-vscode-user-runtime.ps1

.EXAMPLE
    pwsh -File scripts/runtime/clean-vscode-user-runtime.ps1 -Apply

.EXAMPLE
    pwsh -File scripts/runtime/clean-vscode-user-runtime.ps1 -RecentRunWindowHours 0 -DetailedOutput

.EXAMPLE
    pwsh -File scripts/runtime/clean-vscode-user-runtime.ps1 -ExportPlanningSummary -Apply

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $GlobalVscodeUserPath,
    [Nullable[int]] $WorkspaceStorageRetentionDays,
    [Nullable[int]] $ChatSessionRetentionDays,
    [Nullable[int]] $ChatEditingSessionRetentionDays,
    [Nullable[int]] $TranscriptRetentionDays,
    [Nullable[int]] $HistoryRetentionDays,
    [Nullable[int]] $SettingsBackupRetentionDays,
    [Nullable[int]] $MaxChatSessionFileSizeMB,
    [Nullable[int]] $MaxCopilotWorkspaceIndexSizeMB,
    [Nullable[int]] $OversizedFileGraceHours,
    [Nullable[int]] $RecentRunWindowHours,
    [string] $StateFilePath,
    [switch] $Apply,
    [switch] $ExportPlanningSummary,
    [string] $RepoRoot,
    [switch] $DetailedOutput,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../shared-scripts/common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'vscode-runtime-hygiene')
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput
$script:IsVerboseEnabled = [bool] $Verbose
$script:RemovedEntries = 0
$script:FailedEntries = 0
$script:ReclaimedBytes = 0

# Writes diagnostics when detailed output is enabled.
function Write-DetailedLog {
    param(
        [string] $Message
    )

    if ($script:IsDetailedOutputEnabled) {
        Write-StyledOutput ("[DETAIL] {0}" -f $Message)
    }
}

# Converts bytes to megabytes with fixed precision.
function Convert-BytesToMB {
    param(
        [long] $Bytes
    )

    return [math]::Round(($Bytes / 1MB), 2)
}

# Sums the Length property for a file collection safely.
function Get-FileCollectionByteSum {
    param(
        [AllowNull()]
        [object[]] $Files
    )

    $items = @($Files | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) {
        return [long] 0
    }

    $measure = $items | Measure-Object -Property Length -Sum
    if ($null -eq $measure -or $null -eq $measure.Sum) {
        return [long] 0
    }

    return [long] $measure.Sum
}

# Resolves one positive numeric hygiene setting from explicit input, environment, or catalog.
function Resolve-PositiveSetting {
    param(
        [Nullable[int]] $ExplicitValue,
        [string] $EnvironmentVariableName,
        [int] $CatalogValue,
        [string] $SettingName
    )

    if ($null -ne $ExplicitValue) {
        if ([int] $ExplicitValue -lt 1) {
            throw ("{0} must be >= 1." -f $SettingName)
        }

        return [int] $ExplicitValue
    }

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentVariableName)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        $parsedEnvironmentValue = 0
        if (-not [int]::TryParse($environmentValue, [ref] $parsedEnvironmentValue)) {
            throw ("Environment variable {0} must be an integer. Actual='{1}'." -f $EnvironmentVariableName, $environmentValue)
        }

        if ($parsedEnvironmentValue -lt 1) {
            throw ("Environment variable {0} must be >= 1." -f $EnvironmentVariableName)
        }

        return [int] $parsedEnvironmentValue
    }

    if ($CatalogValue -lt 1) {
        throw ("Catalog value for {0} must be >= 1." -f $SettingName)
    }

    return [int] $CatalogValue
}

# Resolves one non-negative numeric hygiene setting from explicit input, environment, or catalog.
function Resolve-NonNegativeSetting {
    param(
        [Nullable[int]] $ExplicitValue,
        [string] $EnvironmentVariableName,
        [int] $CatalogValue,
        [string] $SettingName
    )

    if ($null -ne $ExplicitValue) {
        if ([int] $ExplicitValue -lt 0) {
            throw ("{0} must be >= 0." -f $SettingName)
        }

        return [int] $ExplicitValue
    }

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentVariableName)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        $parsedEnvironmentValue = 0
        if (-not [int]::TryParse($environmentValue, [ref] $parsedEnvironmentValue)) {
            throw ("Environment variable {0} must be an integer. Actual='{1}'." -f $EnvironmentVariableName, $environmentValue)
        }

        if ($parsedEnvironmentValue -lt 0) {
            throw ("Environment variable {0} must be >= 0." -f $EnvironmentVariableName)
        }

        return [int] $parsedEnvironmentValue
    }

    if ($CatalogValue -lt 0) {
        throw ("Catalog value for {0} must be >= 0." -f $SettingName)
    }

    return [int] $CatalogValue
}

# Resolves the cleanup state file path.
function Resolve-HygieneStateFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedGlobalUserPath,
        [string] $RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
            return [System.IO.Path]::GetFullPath($RequestedPath)
        }

        return [System.IO.Path]::GetFullPath((Join-Path $ResolvedGlobalUserPath $RequestedPath))
    }

    return (Join-Path $ResolvedGlobalUserPath '.copilot-instructions-runtime-hygiene.state.json')
}

# Reads the last cleanup timestamp from the state file when it exists.
function Get-LastCleanupTimestamp {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedStateFilePath
    )

    if (-not (Test-Path -LiteralPath $ResolvedStateFilePath -PathType Leaf)) {
        return $null
    }

    try {
        $state = Get-Content -Raw -LiteralPath $ResolvedStateFilePath | ConvertFrom-Json -Depth 10
        if ($null -eq $state -or [string]::IsNullOrWhiteSpace([string] $state.lastRunAt)) {
            return $null
        }

        return [datetime] $state.lastRunAt
    }
    catch {
        Write-DetailedLog ("Ignoring invalid hygiene state file: {0}" -f $ResolvedStateFilePath)
        return $null
    }
}

# Returns true when the cleanup ran too recently and should be skipped.
function Test-ShouldSkipRecentRun {
    param(
        [Nullable[datetime]] $LastRunAt,
        [int] $EffectiveRecentRunWindowHours
    )

    if ($EffectiveRecentRunWindowHours -le 0 -or $null -eq $LastRunAt) {
        return $false
    }

    $threshold = (Get-Date).AddHours(-1 * $EffectiveRecentRunWindowHours)
    return ([datetime] $LastRunAt -gt $threshold)
}

# Persists the latest cleanup timestamp to the state file.
function Save-CleanupState {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedStateFilePath
    )

    $parentPath = Split-Path -Path $ResolvedStateFilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }

    $payload = [ordered]@{
        lastRunAt = (Get-Date).ToString('o')
    }

    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ResolvedStateFilePath
}

# Gets recursive file statistics for a path.
function Get-PathStat {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            exists = $false
            files = 0
            bytes = 0
        }
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue)
    return [pscustomobject]@{
        exists = $true
        files = $files.Count
        bytes = Get-FileCollectionByteSum -Files $files
    }
}

# Gets a recursive file inventory once so large roots are not scanned repeatedly.
function Get-RecursiveFileInventory {
    param(
        [string] $RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $RootPath -Force -Recurse -File -ErrorAction SilentlyContinue)
}

# Builds stats from an existing file inventory without scanning the root again.
function Get-PathStatFromInventory {
    param(
        [string] $RootPath,
        [AllowNull()]
        [object[]] $Files
    )

    $items = @($Files | Where-Object { $null -ne $_ })
    return [pscustomobject]@{
        exists = (Test-Path -LiteralPath $RootPath)
        files = $items.Count
        bytes = Get-FileCollectionByteSum -Files $items
    }
}

# Gets stale workspaceStorage workspace directories eligible for whole-directory removal.
function Get-StaleWorkspaceDirectories {
    param(
        [string] $WorkspaceStoragePath,
        [int] $RetentionDays
    )

    if (-not (Test-Path -LiteralPath $WorkspaceStoragePath -PathType Container)) {
        return @()
    }

    $threshold = (Get-Date).AddDays(-1 * $RetentionDays)
    return @(
        Get-ChildItem -LiteralPath $WorkspaceStoragePath -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $threshold }
    )
}

# Sums bytes for one directory using a precomputed inventory to avoid repeated recursion.
function Get-DirectoryByteSumFromInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DirectoryPath,
        [AllowNull()]
        [object[]] $Files
    )

    $normalizedDirectory = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($DirectoryPath))
    $directoryPrefix = $normalizedDirectory + [System.IO.Path]::DirectorySeparatorChar
    return Get-FileCollectionByteSum -Files @(
        @($Files | Where-Object { $null -ne $_ }) |
            Where-Object {
                $candidatePath = [System.IO.Path]::GetFullPath($_.FullName)
                $candidatePath.StartsWith($directoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)
            }
    )
}

# Collects only the targeted Copilot/VS Code files that matter for hygiene.
function Get-WorkspaceStorageTargetFiles {
    param(
        [AllowNull()]
        [System.IO.DirectoryInfo[]] $WorkspaceDirectories,
        [Parameter(Mandatory = $true)]
        [string[]] $RelativeSegments,
        [string[]] $NamePatterns = @('*')
    )

    $results = New-Object System.Collections.ArrayList
    foreach ($workspaceDirectory in @($WorkspaceDirectories | Where-Object { $null -ne $_ })) {
        $targetPath = $workspaceDirectory.FullName
        foreach ($segment in $RelativeSegments) {
            $targetPath = Join-Path $targetPath $segment
        }

        if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
            continue
        }

        $files = @(Get-ChildItem -LiteralPath $targetPath -Force -File -ErrorAction SilentlyContinue)
        foreach ($file in $files) {
            $matchesPattern = $false
            foreach ($pattern in $NamePatterns) {
                if ($file.Name -like $pattern) {
                    $matchesPattern = $true
                    break
                }
            }

            if ($matchesPattern) {
                [void] $results.Add($file)
            }
        }
    }

    return @($results)
}

# Returns true when one candidate item is contained inside a planned ancestor directory.
function Test-HasPlannedAncestor {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [string[]] $AncestorPaths
    )

    foreach ($ancestorPath in $AncestorPaths) {
        if ([string]::IsNullOrWhiteSpace($ancestorPath)) {
            continue
        }

        $normalizedAncestor = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($ancestorPath))
        $normalizedPath = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($Path))
        if ($normalizedPath.StartsWith(($normalizedAncestor + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

# Removes planned duplicate children when their parent directory is already scheduled.
function Compress-RemovalPlan {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Items
    )

    $directories = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($directoryItem in @($Items | Where-Object { $_ -is [System.IO.DirectoryInfo] })) {
        $normalizedDirectoryPath = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($directoryItem.FullName))
        [void] $directories.Add($normalizedDirectoryPath)
    }

    $compressed = New-Object System.Collections.ArrayList
    $seenPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Items)) {
        $normalizedItemPath = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($item.FullName))

        if ($item -is [System.IO.FileInfo] -and $directories.Count -gt 0 -and (Test-HasPlannedAncestor -Path $normalizedItemPath -AncestorPaths @($directories))) {
            continue
        }

        if ($seenPaths.Add($normalizedItemPath)) {
            [void] $compressed.Add($item)
        }
    }

    return @($compressed)
}

# Removes or previews one file-system plan.
function Invoke-RemovalPlan {
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Items,
        [switch] $ApplyChanges
    )

    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }

        $fullPath = [string] $item.FullName
        $itemBytes = if ($null -ne $item.PSObject.Properties['PlannedBytes']) {
            [long] $item.PlannedBytes
        }
        elseif ($item -is [System.IO.DirectoryInfo]) {
            [long] 0
        }
        else {
            [long] $item.Length
        }

        if (-not $ApplyChanges) {
            Write-DetailedLog ("[PLAN] {0}" -f $fullPath)
            continue
        }

        try {
            Remove-Item -LiteralPath $fullPath -Force -Recurse -ErrorAction Stop
            $script:RemovedEntries++
            $script:ReclaimedBytes += $itemBytes
            Write-DetailedLog ("[REMOVED] {0}" -f $fullPath)
        }
        catch {
            $script:FailedEntries++
            Write-StyledOutput ("[WARN] Failed to remove {0}: {1}" -f $fullPath, $_.Exception.Message)
        }
    }
}

$resolvedGlobalVscodeUserPath = Resolve-GlobalVscodeUserPath -RequestedPath $GlobalVscodeUserPath
$hygieneSettings = Get-VscodeRuntimeHygieneSettings
$effectiveWorkspaceStorageRetentionDays = Resolve-PositiveSetting -ExplicitValue $WorkspaceStorageRetentionDays -EnvironmentVariableName 'CODEX_VSCODE_WORKSPACE_STORAGE_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.WorkspaceStorageRetentionDays) -SettingName 'WorkspaceStorageRetentionDays'
$effectiveChatSessionRetentionDays = Resolve-PositiveSetting -ExplicitValue $ChatSessionRetentionDays -EnvironmentVariableName 'CODEX_VSCODE_CHAT_SESSION_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.ChatSessionRetentionDays) -SettingName 'ChatSessionRetentionDays'
$effectiveChatEditingSessionRetentionDays = Resolve-PositiveSetting -ExplicitValue $ChatEditingSessionRetentionDays -EnvironmentVariableName 'CODEX_VSCODE_CHAT_EDITING_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.ChatEditingSessionRetentionDays) -SettingName 'ChatEditingSessionRetentionDays'
$effectiveTranscriptRetentionDays = Resolve-PositiveSetting -ExplicitValue $TranscriptRetentionDays -EnvironmentVariableName 'CODEX_VSCODE_TRANSCRIPT_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.TranscriptRetentionDays) -SettingName 'TranscriptRetentionDays'
$effectiveHistoryRetentionDays = Resolve-PositiveSetting -ExplicitValue $HistoryRetentionDays -EnvironmentVariableName 'CODEX_VSCODE_HISTORY_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.HistoryRetentionDays) -SettingName 'HistoryRetentionDays'
$effectiveSettingsBackupRetentionDays = Resolve-PositiveSetting -ExplicitValue $SettingsBackupRetentionDays -EnvironmentVariableName 'CODEX_VSCODE_SETTINGS_BACKUP_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.SettingsBackupRetentionDays) -SettingName 'SettingsBackupRetentionDays'
$effectiveMaxChatSessionFileSizeMB = Resolve-PositiveSetting -ExplicitValue $MaxChatSessionFileSizeMB -EnvironmentVariableName 'CODEX_VSCODE_MAX_CHAT_SESSION_FILE_SIZE_MB' -CatalogValue ([int] $hygieneSettings.MaxChatSessionFileSizeMB) -SettingName 'MaxChatSessionFileSizeMB'
$effectiveMaxCopilotWorkspaceIndexSizeMB = Resolve-PositiveSetting -ExplicitValue $MaxCopilotWorkspaceIndexSizeMB -EnvironmentVariableName 'CODEX_VSCODE_MAX_WORKSPACE_INDEX_SIZE_MB' -CatalogValue ([int] $hygieneSettings.MaxCopilotWorkspaceIndexSizeMB) -SettingName 'MaxCopilotWorkspaceIndexSizeMB'
$effectiveOversizedFileGraceHours = Resolve-PositiveSetting -ExplicitValue $OversizedFileGraceHours -EnvironmentVariableName 'CODEX_VSCODE_OVERSIZED_FILE_GRACE_HOURS' -CatalogValue ([int] $hygieneSettings.OversizedFileGraceHours) -SettingName 'OversizedFileGraceHours'
$effectiveRecentRunWindowHours = Resolve-NonNegativeSetting -ExplicitValue $RecentRunWindowHours -EnvironmentVariableName 'CODEX_VSCODE_RECENT_RUN_WINDOW_HOURS' -CatalogValue ([int] $hygieneSettings.RecentRunWindowHours) -SettingName 'RecentRunWindowHours'
$resolvedStateFilePath = Resolve-HygieneStateFilePath -ResolvedGlobalUserPath $resolvedGlobalVscodeUserPath -RequestedPath $StateFilePath
$lastRunAt = Get-LastCleanupTimestamp -ResolvedStateFilePath $resolvedStateFilePath

Start-ExecutionSession `
    -Name 'clean-vscode-user-runtime' `
    -RootPath $resolvedGlobalVscodeUserPath `
    -Metadata ([ordered]@{
        Mode = $(if ($Apply) { 'apply' } else { 'preview' })
        CatalogPath = $hygieneSettings.CatalogPath
        RecentRunWindowHours = $effectiveRecentRunWindowHours
        LastRunAt = $(if ($null -ne $lastRunAt) { $lastRunAt.ToString('o') } else { 'none' })
    }) `
    -IncludeMetadataInDefaultOutput

if (Test-ShouldSkipRecentRun -LastRunAt $lastRunAt -EffectiveRecentRunWindowHours $effectiveRecentRunWindowHours) {
    Write-StyledOutput 'VS Code user runtime cleanup skipped because the recent-run window is still active.'
    Complete-ExecutionSession -Name 'clean-vscode-user-runtime' -Status 'skipped' -Summary ([ordered]@{
            LastRunAt = $lastRunAt.ToString('o')
            RecentRunWindowHours = $effectiveRecentRunWindowHours
        }) | Out-Null
    exit 0
}

$workspaceStoragePath = Join-Path $resolvedGlobalVscodeUserPath 'workspaceStorage'
$historyPath = Join-Path $resolvedGlobalVscodeUserPath 'History'
$globalStorageEmptyWindowPath = Join-Path $resolvedGlobalVscodeUserPath 'globalStorage\emptyWindowChatSessions'

Write-StyledOutput '  [1/7] Scanning History files...'
$historyFiles = @(Get-RecursiveFileInventory -RootPath $historyPath)
Write-StyledOutput '  [2/7] Scanning empty-window chat sessions...'
$emptyWindowFiles = @(Get-RecursiveFileInventory -RootPath $globalStorageEmptyWindowPath)
Write-StyledOutput '  [3/7] Listing workspaceStorage directories...'
$workspaceDirectories = @()
if (Test-Path -LiteralPath $workspaceStoragePath -PathType Container) {
    $workspaceDirectories = @(Get-ChildItem -LiteralPath $workspaceStoragePath -Force -Directory -ErrorAction SilentlyContinue)
}
$workspaceDirectoryCount = $workspaceDirectories.Count
Write-StyledOutput ("  Found {0} workspace directories" -f $workspaceDirectoryCount)
$historyStats = Get-PathStatFromInventory -RootPath $historyPath -Files $historyFiles
$emptyWindowStats = Get-PathStatFromInventory -RootPath $globalStorageEmptyWindowPath -Files $emptyWindowFiles

$staleWorkspaceDirectories = @($workspaceDirectories | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1 * $effectiveWorkspaceStorageRetentionDays) })
foreach ($staleWorkspaceDirectory in @($staleWorkspaceDirectories)) {
    if ($null -eq $staleWorkspaceDirectory.PSObject.Properties['PlannedBytes']) {
        $staleWorkspaceDirectory | Add-Member -NotePropertyName PlannedBytes -NotePropertyValue 0 -Force
    }
}
$staleWorkspaceDirectoryPaths = @($staleWorkspaceDirectories | Select-Object -ExpandProperty FullName)
if ($staleWorkspaceDirectories.Count -lt $workspaceDirectoryCount) {
    $activeWorkspaceDirectories = @($workspaceDirectories | Where-Object {
        $staleWorkspaceDirectoryPaths -notcontains $_.FullName -and
        ($staleWorkspaceDirectoryPaths.Count -eq 0 -or -not (Test-HasPlannedAncestor -Path $_.FullName -AncestorPaths $staleWorkspaceDirectoryPaths))
    })
}
else {
    $activeWorkspaceDirectories = @()
}
Write-StyledOutput ("  Stale: {0}  Active: {1}" -f $staleWorkspaceDirectories.Count, $activeWorkspaceDirectories.Count)
if ($script:IsDetailedOutputEnabled) {
    Write-DetailedLog ("Targeted workspace scan: totalDirectories={0} activeDirectories={1} staleDirectories={2}" -f $workspaceDirectoryCount, $activeWorkspaceDirectories.Count, $staleWorkspaceDirectories.Count)
}

Write-StyledOutput ("  [4/7] Scanning chat sessions ({0} active dirs)..." -f $activeWorkspaceDirectories.Count)
$activeChatSessionFiles = @(Get-WorkspaceStorageTargetFiles -WorkspaceDirectories $activeWorkspaceDirectories -RelativeSegments @('chatSessions') -NamePatterns @('*.json', '*.jsonl'))
Write-StyledOutput '  [5/7] Scanning editing sessions and transcripts...'
$activeEditingSessionFiles = @(Get-WorkspaceStorageTargetFiles -WorkspaceDirectories $activeWorkspaceDirectories -RelativeSegments @('chatEditingSessions'))
$activeTranscriptFiles = @(Get-WorkspaceStorageTargetFiles -WorkspaceDirectories $activeWorkspaceDirectories -RelativeSegments @('GitHub.copilot-chat', 'transcripts') -NamePatterns @('*.json', '*.jsonl'))
Write-StyledOutput '  [6/7] Scanning workspace indexes...'
$activeWorkspaceIndexFiles = @(Get-WorkspaceStorageTargetFiles -WorkspaceDirectories $activeWorkspaceDirectories -RelativeSegments @('GitHub.copilot-chat') -NamePatterns @('local-index*.db'))

Write-StyledOutput ("  [7/7] Finalizing plan for {0} stale directories..." -f $staleWorkspaceDirectories.Count)
if ($staleWorkspaceDirectories.Count -gt 0) {
    Write-StyledOutput '  Skipping recursive size pre-calculation for stale directories to avoid long blocking scans.'
}
Write-StyledOutput '  Scan complete.'

$chatSessionThreshold = (Get-Date).AddDays(-1 * $effectiveChatSessionRetentionDays)
$editingSessionThreshold = (Get-Date).AddDays(-1 * $effectiveChatEditingSessionRetentionDays)
$transcriptThreshold = (Get-Date).AddDays(-1 * $effectiveTranscriptRetentionDays)
$historyThreshold = (Get-Date).AddDays(-1 * $effectiveHistoryRetentionDays)
$settingsBackupThreshold = (Get-Date).AddDays(-1 * $effectiveSettingsBackupRetentionDays)
$oversizedThreshold = (Get-Date).AddHours(-1 * $effectiveOversizedFileGraceHours)

$expiredChatSessions = @(
    $activeChatSessionFiles | Where-Object { $_.LastWriteTime -lt $chatSessionThreshold }
)
$expiredEditingSessions = @(
    $activeEditingSessionFiles | Where-Object { $_.LastWriteTime -lt $editingSessionThreshold }
)
$expiredTranscripts = @(
    $activeTranscriptFiles | Where-Object { $_.LastWriteTime -lt $transcriptThreshold }
)
$expiredHistoryFiles = @($historyFiles | Where-Object { $_.LastWriteTime -lt $historyThreshold })
$expiredSettingsBackups = @(
    Get-ChildItem -LiteralPath $resolvedGlobalVscodeUserPath -Force -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTime -lt $settingsBackupThreshold -and
            ($_.Name -like 'settings.json.*.bak' -or $_.Name -like 'mcp.json.*.bak')
        }
)
$expiredEmptyWindowSessions = @(
    $emptyWindowFiles | Where-Object { $_.LastWriteTime -lt $chatSessionThreshold -and ($_.Name -like '*.json' -or $_.Name -like '*.jsonl') }
)
$oversizedChatSessions = @(
    $activeChatSessionFiles |
        Where-Object {
            $_.LastWriteTime -lt $oversizedThreshold -and
            $_.Length -gt ($effectiveMaxChatSessionFileSizeMB * 1MB)
        }
)
$oversizedEmptyWindowSessions = @(
    $emptyWindowFiles |
        Where-Object {
            $_.LastWriteTime -lt $oversizedThreshold -and
            $_.Length -gt ($effectiveMaxChatSessionFileSizeMB * 1MB) -and
            ($_.Name -like '*.json' -or $_.Name -like '*.jsonl')
        }
)
$oversizedWorkspaceIndexes = @(
    $activeWorkspaceIndexFiles |
        Where-Object {
            $_.LastWriteTime -lt $oversizedThreshold -and
            $_.Length -gt ($effectiveMaxCopilotWorkspaceIndexSizeMB * 1MB)
        }
)

$plannedRemovals = Compress-RemovalPlan -Items @(
    $staleWorkspaceDirectories
    $expiredChatSessions
    $expiredEditingSessions
    $expiredTranscripts
    $expiredHistoryFiles
    $expiredSettingsBackups
    $expiredEmptyWindowSessions
    $oversizedChatSessions
    $oversizedEmptyWindowSessions
    $oversizedWorkspaceIndexes
)

$plannedRemovalBytes = 0L
foreach ($item in @($plannedRemovals)) {
    if ($null -ne $item.PSObject.Properties['PlannedBytes']) {
        $plannedRemovalBytes += [long] $item.PlannedBytes
    }
    else {
        $plannedRemovalBytes += [long] $item.Length
    }
}

Write-StyledOutput 'VS Code user runtime cleanup plan'
Write-StyledOutput ("  GlobalVscodeUserPath: {0}" -f $resolvedGlobalVscodeUserPath)
Write-StyledOutput ("  Mode: {0}" -f $(if ($Apply) { 'apply' } else { 'preview' }))
Write-StyledOutput ("  CatalogPath: {0}" -f $hygieneSettings.CatalogPath)
Write-StyledOutput ("  WorkspaceStorageRetentionDays: {0}" -f $effectiveWorkspaceStorageRetentionDays)
Write-StyledOutput ("  ChatSessionRetentionDays: {0}" -f $effectiveChatSessionRetentionDays)
Write-StyledOutput ("  ChatEditingSessionRetentionDays: {0}" -f $effectiveChatEditingSessionRetentionDays)
Write-StyledOutput ("  TranscriptRetentionDays: {0}" -f $effectiveTranscriptRetentionDays)
Write-StyledOutput ("  HistoryRetentionDays: {0}" -f $effectiveHistoryRetentionDays)
Write-StyledOutput ("  SettingsBackupRetentionDays: {0}" -f $effectiveSettingsBackupRetentionDays)
Write-StyledOutput ("  MaxChatSessionFileSizeMB: {0}" -f $effectiveMaxChatSessionFileSizeMB)
Write-StyledOutput ("  MaxCopilotWorkspaceIndexSizeMB: {0}" -f $effectiveMaxCopilotWorkspaceIndexSizeMB)
Write-StyledOutput ("  OversizedFileGraceHours: {0}" -f $effectiveOversizedFileGraceHours)
Write-StyledOutput ("  RecentRunWindowHours: {0}" -f $effectiveRecentRunWindowHours)
Write-StyledOutput ("  workspaceStorage: directories={0}" -f $workspaceDirectoryCount)
Write-StyledOutput ("  History: files={0} sizeMB={1}" -f $historyStats.files, (Convert-BytesToMB -Bytes $historyStats.bytes))
Write-StyledOutput ("  emptyWindowChatSessions: files={0} sizeMB={1}" -f $emptyWindowStats.files, (Convert-BytesToMB -Bytes $emptyWindowStats.bytes))
Write-StyledOutput ("  Stale workspace directories: {0}" -f $staleWorkspaceDirectories.Count)
Write-StyledOutput ("  Expired chat sessions: {0} (sizeMB={1})" -f $expiredChatSessions.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $expiredChatSessions)))
Write-StyledOutput ("  Expired chat editing sessions: {0} (sizeMB={1})" -f $expiredEditingSessions.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $expiredEditingSessions)))
Write-StyledOutput ("  Expired transcripts: {0} (sizeMB={1})" -f $expiredTranscripts.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $expiredTranscripts)))
Write-StyledOutput ("  Expired History files: {0} (sizeMB={1})" -f $expiredHistoryFiles.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $expiredHistoryFiles)))
Write-StyledOutput ("  Expired settings/mcp backups: {0} (sizeMB={1})" -f $expiredSettingsBackups.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $expiredSettingsBackups)))
Write-StyledOutput ("  Expired empty-window sessions: {0} (sizeMB={1})" -f $expiredEmptyWindowSessions.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $expiredEmptyWindowSessions)))
Write-StyledOutput ("  Oversized chat sessions: {0} (sizeMB={1})" -f ($oversizedChatSessions.Count + $oversizedEmptyWindowSessions.Count), (Convert-BytesToMB -Bytes ((Get-FileCollectionByteSum -Files $oversizedChatSessions) + (Get-FileCollectionByteSum -Files $oversizedEmptyWindowSessions))))
Write-StyledOutput ("  Oversized Copilot workspace indexes: {0} (sizeMB={1})" -f $oversizedWorkspaceIndexes.Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files $oversizedWorkspaceIndexes)))
Write-StyledOutput ("  Planned removals: {0} (sizeMB={1})" -f $plannedRemovals.Count, (Convert-BytesToMB -Bytes $plannedRemovalBytes))
if ($staleWorkspaceDirectories.Count -gt 0) {
    Write-StyledOutput '  Planned size excludes recursive bytes for stale workspaceStorage directories to keep planning responsive.'
}

if ($ExportPlanningSummary) {
    $exportScript = Join-Path $PSScriptRoot 'export-planning-summary.ps1'
    if (Test-Path -LiteralPath $exportScript -PathType Leaf) {
        $exportRoot = if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot } else { Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
        Write-StyledOutput 'Exporting planning handoff summary before cleanup...'
        & $exportScript -RepoRoot $exportRoot
    } else {
        Write-Warning 'export-planning-summary.ps1 not found — skipping planning export.'
    }
}

if (-not $Apply) {
    Write-StyledOutput ''
    Write-StyledOutput 'Preview complete. Re-run with -Apply to execute cleanup.'
    Complete-ExecutionSession -Name 'clean-vscode-user-runtime' -Status 'preview' -Summary ([ordered]@{
            PlannedRemovals = $plannedRemovals.Count
            PlannedSizeMB = (Convert-BytesToMB -Bytes $plannedRemovalBytes)
        }) | Out-Null
    exit 0
}

Invoke-RemovalPlan -Items $plannedRemovals -ApplyChanges
Save-CleanupState -ResolvedStateFilePath $resolvedStateFilePath

Write-StyledOutput ''
Write-StyledOutput 'VS Code user runtime cleanup summary'
Write-StyledOutput ("  Removed entries: {0}" -f $script:RemovedEntries)
Write-StyledOutput ("  Failed entries: {0}" -f $script:FailedEntries)
Write-StyledOutput ("  Reclaimed sizeMB: {0}" -f (Convert-BytesToMB -Bytes $script:ReclaimedBytes))

Complete-ExecutionSession -Name 'clean-vscode-user-runtime' -Status $(if ($script:FailedEntries -gt 0) { 'warning' } else { 'passed' }) -Summary ([ordered]@{
        RemovedEntries = $script:RemovedEntries
        FailedEntries = $script:FailedEntries
        ReclaimedSizeMB = (Convert-BytesToMB -Bytes $script:ReclaimedBytes)
    }) | Out-Null

exit 0