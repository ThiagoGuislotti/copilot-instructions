<#
.SYNOPSIS
    Cleans local Codex runtime folders and optionally prunes old session files.

.DESCRIPTION
    Removes transient runtime data under the local Codex home folder:
    - tmp/
    - vendor_imports/
    - log/ files older than the configured retention window (based on LastWriteTime)

    Optionally prunes session files under sessions/. The default hygiene mode
    keeps active context intact by applying only retention by LastWriteTime.
    Oversized single-file and total session-storage pruning remain available as
    explicit emergency overrides, but they are disabled by default unless the
    catalog or environment variables opt into them.

    Default behavior is preview-only. Use -Apply to perform deletions.

.PARAMETER CodexHome
    Local Codex home path. Defaults to <user-home>/.codex.

.PARAMETER IncludeSessions
    Includes session-file cleanup based on SessionRetentionDays.

.PARAMETER SessionRetentionDays
    Optional number of days of session history to keep when IncludeSessions is
    used (based on LastWriteTime). When omitted, the hygiene catalog default is
    used unless CODEX_SESSION_RETENTION_DAYS overrides it.

.PARAMETER LogRetentionDays
    Optional number of days of log history to keep for .codex/log and
    sandbox.log (based on LastWriteTime). When omitted, the hygiene catalog
    default is used unless CODEX_LOG_RETENTION_DAYS overrides it.

.PARAMETER MaxSessionFileSizeMB
    Optional size threshold for one session file. Session files larger than
    this threshold are removed when they are older than
    OversizedSessionGraceHours. When omitted, the hygiene catalog default is
    used unless CODEX_MAX_SESSION_FILE_SIZE_MB overrides it.

.PARAMETER OversizedSessionGraceHours
    Optional grace window before oversized session files are eligible for
    removal. When omitted, the hygiene catalog default is used unless
    CODEX_OVERSIZED_SESSION_GRACE_HOURS overrides it.

.PARAMETER MaxSessionStorageGB
    Optional total storage budget for the sessions folder. When current session
    storage exceeds the budget, the oldest session files older than
    SessionStorageGraceHours are pruned until the budget is satisfied. When
    omitted, the hygiene catalog default is used unless
    CODEX_MAX_SESSION_STORAGE_GB overrides it.

.PARAMETER SessionStorageGraceHours
    Optional grace window before session files are eligible for storage-budget
    pruning. When omitted, the hygiene catalog default is used unless
    CODEX_SESSION_STORAGE_GRACE_HOURS overrides it.

.PARAMETER Apply
    Executes deletions. When omitted, script runs in preview mode only.

.PARAMETER ExportPlanningSummary
    Exports a context handoff summary from active planning artifacts before
    performing any cleanup. Requires the repo root to be resolvable.

.PARAMETER RepoRoot
    Repository root used when ExportPlanningSummary is set. Defaults to
    auto-detection from script location.

.PARAMETER DetailedOutput
    Prints additional diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/clean-codex-runtime.ps1

.EXAMPLE
    pwsh -File scripts/runtime/clean-codex-runtime.ps1 -LogRetentionDays 14

.EXAMPLE
    pwsh -File scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 14 -Apply

.NOTES
    Version: 1.4
    Requirements: PowerShell 7+.
#>

param(
    [string] $CodexHome,
    [switch] $IncludeSessions,
    [Nullable[int]] $SessionRetentionDays,
    [Nullable[int]] $LogRetentionDays,
    [Nullable[long]] $MaxSessionFileSizeMB,
    [Nullable[int]] $OversizedSessionGraceHours,
    [Nullable[long]] $MaxSessionStorageGB,
    [Nullable[int]] $SessionStorageGraceHours,
    [switch] $Apply,
    [switch] $ExportPlanningSummary,
    [string] $RepoRoot,
    [switch] $DetailedOutput
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'runtime-paths', 'codex-runtime-hygiene')
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput
$script:RemovedEntries = 0
$script:FailedEntries = 0
$script:ReclaimedBytes = 0

# Writes diagnostics when detailed mode is enabled.
function Write-DetailedLog {
    param(
        [string] $Message
    )

    if ($script:IsDetailedOutputEnabled) {
        Write-StyledOutput ("[DETAIL] {0}" -f $Message)
    }
}

# Converts bytes to megabytes with a fixed precision.
function Convert-BytesToMB {
    param(
        [long] $Bytes
    )

    return [math]::Round(($Bytes / 1MB), 2)
}

# Safely sums file lengths for a collection that may be empty.
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
    if ($null -eq $measure) {
        return [long] 0
    }

    $sumProperty = $measure.PSObject.Properties['Sum']
    if ($null -eq $sumProperty -or $null -eq $sumProperty.Value) {
        return [long] 0
    }

    return [long] $sumProperty.Value
}

# Resolves one required numeric hygiene setting from explicit input, environment, or catalog defaults.
function Resolve-NumericHygieneSetting {
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

# Resolves one optional numeric hygiene setting from explicit input, environment, or catalog defaults.
function Resolve-OptionalNumericHygieneSetting {
    param(
        [Nullable[long]] $ExplicitValue,
        [string] $EnvironmentVariableName,
        [AllowNull()]
        [Nullable[long]] $CatalogValue,
        [string] $SettingName
    )

    if ($null -ne $ExplicitValue) {
        if ([long] $ExplicitValue -lt 1) {
            throw ("{0} must be >= 1." -f $SettingName)
        }

        return [Nullable[long]] ([long] $ExplicitValue)
    }

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentVariableName)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        [long] $parsedEnvironmentValue = 0
        if (-not [long]::TryParse($environmentValue, [ref] $parsedEnvironmentValue)) {
            throw ("Environment variable {0} must be an integer. Actual='{1}'." -f $EnvironmentVariableName, $environmentValue)
        }

        if ($parsedEnvironmentValue -lt 1) {
            throw ("Environment variable {0} must be >= 1." -f $EnvironmentVariableName)
        }

        return [Nullable[long]] $parsedEnvironmentValue
    }

    if ($null -eq $CatalogValue) {
        return $null
    }

    if ([long] $CatalogValue -lt 1) {
        throw ("Catalog value for {0} must be >= 1 when defined." -f $SettingName)
    }

    return [Nullable[long]] ([long] $CatalogValue)
}

# Resolves the local Codex home path.
function Resolve-CodexHomePath {
    param(
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        throw 'CodexHome cannot be empty.'
    }

    if (Test-Path -LiteralPath $RequestedPath) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    return [System.IO.Path]::GetFullPath($RequestedPath)
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

    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
    $sum = Get-FileCollectionByteSum -Files $files

    return [pscustomobject]@{
        exists = $true
        files = $files.Count
        bytes = [long] $sum
    }
}

# Gets total bytes for a file or directory path.
function Get-PathByteCount {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [long] 0
    }

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
        return (Get-FileCollectionByteSum -Files $files)
    }

    return [long] $item.Length
}

# Removes one file or directory and tracks cleanup metrics.
function Invoke-PathRemoval {
    param(
        [string] $Path
    )

    try {
        $entryBytes = Get-PathByteCount -Path $Path
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        $script:RemovedEntries++
        $script:ReclaimedBytes += $entryBytes
        Write-DetailedLog ("Removed: {0}" -f $Path)
    }
    catch {
        $script:FailedEntries++
        Write-Warning ("Failed to remove '{0}': {1}" -f $Path, $_.Exception.Message)
    }
}

# Removes all direct children inside a directory.
function Invoke-DirectoryContentRemoval {
    param(
        [string] $DirectoryPath
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath -PathType Container)) {
        return
    }

    $children = @(Get-ChildItem -LiteralPath $DirectoryPath -Force -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Invoke-PathRemoval -Path $child.FullName
    }
}

# Gets session files older than the retention cutoff date.
function Get-ExpiredSessionFile {
    param(
        [string] $SessionsPath,
        [int] $RetentionDays
    )

    if (-not (Test-Path -LiteralPath $SessionsPath -PathType Container)) {
        return @()
    }

    $cutoff = (Get-Date).AddDays(-1 * $RetentionDays)
    return @(
        Get-ChildItem -LiteralPath $SessionsPath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
    )
}

# Gets session files larger than the configured threshold after the grace window.
function Get-OversizedSessionFiles {
    param(
        [string] $SessionsPath,
        [long] $MaxFileSizeBytes,
        [int] $GraceHours
    )

    if (-not (Test-Path -LiteralPath $SessionsPath -PathType Container)) {
        return @()
    }

    $cutoff = (Get-Date).AddHours(-1 * $GraceHours)
    return @(
        Get-ChildItem -LiteralPath $SessionsPath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff -and $_.Length -gt $MaxFileSizeBytes }
    )
}

# Gets the oldest session files eligible for storage-budget pruning.
function Get-SessionFilesForStorageBudgetPrune {
    param(
        [string] $SessionsPath,
        [int] $GraceHours
    )

    if (-not (Test-Path -LiteralPath $SessionsPath -PathType Container)) {
        return @()
    }

    $cutoff = (Get-Date).AddHours(-1 * $GraceHours)
    return @(
        Get-ChildItem -LiteralPath $SessionsPath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Sort-Object LastWriteTime, Length
    )
}

# Builds a deduplicated removal plan for session files using retention, oversized-file, and storage-budget rules.
function Get-SessionCleanupPlan {
    param(
        [string] $SessionsPath,
        [int] $RetentionDays,
        [Nullable[long]] $MaxSessionFileSizeMB,
        [Nullable[int]] $OversizedSessionGraceHours,
        [Nullable[long]] $MaxSessionStorageGB,
        [Nullable[int]] $SessionStorageGraceHours
    )

    $allSessionFiles = if (Test-Path -LiteralPath $SessionsPath -PathType Container) {
        @(Get-ChildItem -LiteralPath $SessionsPath -Recurse -File -Force -ErrorAction SilentlyContinue)
    }
    else {
        @()
    }

    $expiredFiles = @(Get-ExpiredSessionFile -SessionsPath $SessionsPath -RetentionDays $RetentionDays)
    $oversizedFiles = @()
    if (($null -ne $MaxSessionFileSizeMB) -and ($null -ne $OversizedSessionGraceHours)) {
        $oversizedFiles = @(Get-OversizedSessionFiles -SessionsPath $SessionsPath -MaxFileSizeBytes ($MaxSessionFileSizeMB * 1MB) -GraceHours $OversizedSessionGraceHours)
    }

    $plannedRemovalMap = @{}
    foreach ($file in @($expiredFiles + $oversizedFiles)) {
        if ($null -ne $file) {
            $plannedRemovalMap[$file.FullName] = $file
        }
    }

    $totalSessionBytes = Get-FileCollectionByteSum -Files $allSessionFiles
    $plannedRemovalBytes = Get-FileCollectionByteSum -Files @($plannedRemovalMap.Values)
    $remainingSessionBytes = [long] ($totalSessionBytes - $plannedRemovalBytes)
    $storageBudgetBytes = if ($null -ne $MaxSessionStorageGB) { [long] ($MaxSessionStorageGB * 1GB) } else { [long] 0 }
    $storageBudgetPruneFiles = New-Object System.Collections.Generic.List[object]

    if (($null -ne $MaxSessionStorageGB) -and ($null -ne $SessionStorageGraceHours) -and ($remainingSessionBytes -gt $storageBudgetBytes)) {
        foreach ($candidate in (Get-SessionFilesForStorageBudgetPrune -SessionsPath $SessionsPath -GraceHours $SessionStorageGraceHours)) {
            if ($remainingSessionBytes -le $storageBudgetBytes) {
                break
            }

            if ($plannedRemovalMap.ContainsKey($candidate.FullName)) {
                continue
            }

            $plannedRemovalMap[$candidate.FullName] = $candidate
            $storageBudgetPruneFiles.Add($candidate) | Out-Null
            $remainingSessionBytes -= [long] $candidate.Length
        }
    }

    return [pscustomobject]@{
        AllSessionFiles               = $allSessionFiles
        TotalSessionBytes             = [long] $totalSessionBytes
        ExpiredFiles                  = $expiredFiles
        OversizedFiles                = $oversizedFiles
        StorageBudgetPruneFiles       = @($storageBudgetPruneFiles.ToArray())
        PlannedRemovalFiles           = @($plannedRemovalMap.Values | Sort-Object FullName)
        PlannedRemovalBytes           = (Get-FileCollectionByteSum -Files @($plannedRemovalMap.Values))
        StorageBudgetBytes            = $storageBudgetBytes
        RemainingBytesAfterPlannedRun = [long] $(if ($remainingSessionBytes -lt 0) { 0 } else { $remainingSessionBytes })
    }
}

# Gets files older than the retention cutoff date for a root folder.
function Get-ExpiredFileByRetention {
    param(
        [string] $RootPath,
        [int] $RetentionDays
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return @()
    }

    $cutoff = (Get-Date).AddDays(-1 * $RetentionDays)
    return @(
        Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
    )
}

# Removes empty directories from deepest paths to root.
function Invoke-EmptyDirectoryRemoval {
    param(
        [string] $RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return
    }

    $directories = @(Get-ChildItem -LiteralPath $RootPath -Recurse -Directory -Force -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)
    foreach ($directory in $directories) {
        $hasChildren = @(Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue).Count -gt 0
        if (-not $hasChildren) {
            Invoke-PathRemoval -Path $directory.FullName
        }
    }
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = Resolve-CodexRuntimePath
}

$hygieneSettings = Get-CodexRuntimeHygieneSettings
$effectiveLogRetentionDays = Resolve-NumericHygieneSetting -ExplicitValue $LogRetentionDays -EnvironmentVariableName 'CODEX_LOG_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.LogRetentionDays) -SettingName 'LogRetentionDays'
$effectiveSessionRetentionDays = Resolve-NumericHygieneSetting -ExplicitValue $SessionRetentionDays -EnvironmentVariableName 'CODEX_SESSION_RETENTION_DAYS' -CatalogValue ([int] $hygieneSettings.SessionRetentionDays) -SettingName 'SessionRetentionDays'
$effectiveMaxSessionFileSizeMB = Resolve-OptionalNumericHygieneSetting -ExplicitValue $MaxSessionFileSizeMB -EnvironmentVariableName 'CODEX_MAX_SESSION_FILE_SIZE_MB' -CatalogValue $hygieneSettings.MaxSessionFileSizeMB -SettingName 'MaxSessionFileSizeMB'
$effectiveOversizedSessionGraceHours = Resolve-OptionalNumericHygieneSetting -ExplicitValue $OversizedSessionGraceHours -EnvironmentVariableName 'CODEX_OVERSIZED_SESSION_GRACE_HOURS' -CatalogValue $hygieneSettings.OversizedSessionGraceHours -SettingName 'OversizedSessionGraceHours'
$effectiveMaxSessionStorageGB = Resolve-OptionalNumericHygieneSetting -ExplicitValue $MaxSessionStorageGB -EnvironmentVariableName 'CODEX_MAX_SESSION_STORAGE_GB' -CatalogValue $hygieneSettings.MaxSessionStorageGB -SettingName 'MaxSessionStorageGB'
$effectiveSessionStorageGraceHours = Resolve-OptionalNumericHygieneSetting -ExplicitValue $SessionStorageGraceHours -EnvironmentVariableName 'CODEX_SESSION_STORAGE_GRACE_HOURS' -CatalogValue $hygieneSettings.SessionStorageGraceHours -SettingName 'SessionStorageGraceHours'

$resolvedCodexHome = Resolve-CodexHomePath -RequestedPath $CodexHome
if (-not (Test-Path -LiteralPath $resolvedCodexHome -PathType Container)) {
    throw ("Codex home directory not found: {0}" -f $resolvedCodexHome)
}

$tmpPath = Join-Path $resolvedCodexHome 'tmp'
$logPath = Join-Path $resolvedCodexHome 'log'
$vendorImportsPath = Join-Path $resolvedCodexHome 'vendor_imports'
$sessionsPath = Join-Path $resolvedCodexHome 'sessions'
$sandboxLogPath = Join-Path $resolvedCodexHome 'sandbox.log'

$directoryTargets = @(
    [pscustomobject]@{ name = 'tmp'; path = $tmpPath },
    [pscustomobject]@{ name = 'vendor_imports'; path = $vendorImportsPath }
)

$sessionCleanupPlan = $null
if ($IncludeSessions) {
    $sessionCleanupPlan = Get-SessionCleanupPlan `
        -SessionsPath $sessionsPath `
        -RetentionDays $effectiveSessionRetentionDays `
        -MaxSessionFileSizeMB $effectiveMaxSessionFileSizeMB `
        -OversizedSessionGraceHours $effectiveOversizedSessionGraceHours `
        -MaxSessionStorageGB $effectiveMaxSessionStorageGB `
        -SessionStorageGraceHours $effectiveSessionStorageGraceHours
}

$expiredLogFiles = @(
    Get-ExpiredFileByRetention -RootPath $logPath -RetentionDays $effectiveLogRetentionDays
)
$sandboxLogExpired = $false
if (Test-Path -LiteralPath $sandboxLogPath -PathType Leaf) {
    $sandboxLogCutoff = (Get-Date).AddDays(-1 * $effectiveLogRetentionDays)
    $sandboxLogItem = Get-Item -LiteralPath $sandboxLogPath -Force
    $sandboxLogExpired = $sandboxLogItem.LastWriteTime -lt $sandboxLogCutoff
}

Write-StyledOutput 'Codex runtime cleanup plan'
Write-StyledOutput ("  CodexHome: {0}" -f $resolvedCodexHome)
$executionMode = if ($Apply) { 'apply' } else { 'preview' }
Write-StyledOutput ("  Mode: {0}" -f $executionMode)
Write-StyledOutput ("  CatalogPath: {0}" -f $hygieneSettings.CatalogPath)
Write-StyledOutput '  RetentionReference: LastWriteTime'
Write-StyledOutput ("  LogRetentionDays: {0}" -f $effectiveLogRetentionDays)
Write-StyledOutput ("  IncludeSessions: {0}" -f [bool] $IncludeSessions)
if ($IncludeSessions) {
    Write-StyledOutput ("  SessionRetentionDays: {0}" -f $effectiveSessionRetentionDays)
    Write-StyledOutput ("  MaxSessionFileSizeMB: {0}" -f $(if ($null -eq $effectiveMaxSessionFileSizeMB) { 'disabled' } else { [string] $effectiveMaxSessionFileSizeMB }))
    Write-StyledOutput ("  OversizedSessionGraceHours: {0}" -f $(if ($null -eq $effectiveOversizedSessionGraceHours) { 'disabled' } else { [string] $effectiveOversizedSessionGraceHours }))
    Write-StyledOutput ("  MaxSessionStorageGB: {0}" -f $(if ($null -eq $effectiveMaxSessionStorageGB) { 'disabled' } else { [string] $effectiveMaxSessionStorageGB }))
    Write-StyledOutput ("  SessionStorageGraceHours: {0}" -f $(if ($null -eq $effectiveSessionStorageGraceHours) { 'disabled' } else { [string] $effectiveSessionStorageGraceHours }))
}

foreach ($target in $directoryTargets) {
    $stats = Get-PathStat -Path $target.path
    Write-StyledOutput ("  Target {0}: files={1} sizeMB={2}" -f $target.name, $stats.files, (Convert-BytesToMB -Bytes $stats.bytes))
}

$logStats = Get-PathStat -Path $logPath
$expiredLogBytes = Get-FileCollectionByteSum -Files $expiredLogFiles
Write-StyledOutput ("  Target log: files={0} sizeMB={1}" -f $logStats.files, (Convert-BytesToMB -Bytes $logStats.bytes))
Write-StyledOutput ("  Expired log files: {0} (sizeMB={1})" -f $expiredLogFiles.Count, (Convert-BytesToMB -Bytes $expiredLogBytes))

if (Test-Path -LiteralPath $sandboxLogPath -PathType Leaf) {
    $sandboxLogSize = (Get-Item -LiteralPath $sandboxLogPath -Force).Length
    Write-StyledOutput ("  Target sandbox.log: sizeMB={0} expired={1}" -f (Convert-BytesToMB -Bytes $sandboxLogSize), $sandboxLogExpired)
}
else {
    Write-StyledOutput '  Target sandbox.log: not found'
}

if ($IncludeSessions) {
    Write-StyledOutput ("  Session files total: {0} (sizeGB={1})" -f @($sessionCleanupPlan.AllSessionFiles).Count, [math]::Round(($sessionCleanupPlan.TotalSessionBytes / 1GB), 2))
    Write-StyledOutput ("  Expired session files: {0} (sizeMB={1})" -f @($sessionCleanupPlan.ExpiredFiles).Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files @($sessionCleanupPlan.ExpiredFiles))))
    Write-StyledOutput ("  Oversized session files: {0} (sizeMB={1})" -f @($sessionCleanupPlan.OversizedFiles).Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files @($sessionCleanupPlan.OversizedFiles))))
    Write-StyledOutput ("  Storage-budget prunes: {0} (sizeMB={1})" -f @($sessionCleanupPlan.StorageBudgetPruneFiles).Count, (Convert-BytesToMB -Bytes (Get-FileCollectionByteSum -Files @($sessionCleanupPlan.StorageBudgetPruneFiles))))
    Write-StyledOutput ("  Planned session removals: {0} (sizeMB={1})" -f @($sessionCleanupPlan.PlannedRemovalFiles).Count, (Convert-BytesToMB -Bytes $sessionCleanupPlan.PlannedRemovalBytes))
    Write-StyledOutput ("  Remaining session size after plan: sizeGB={0} budgetGB={1}" -f [math]::Round(($sessionCleanupPlan.RemainingBytesAfterPlannedRun / 1GB), 2), $(if ($null -eq $effectiveMaxSessionStorageGB) { 'disabled' } else { [string] $effectiveMaxSessionStorageGB }))
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
    exit 0
}

foreach ($target in $directoryTargets) {
    Invoke-DirectoryContentRemoval -DirectoryPath $target.path
}

foreach ($logFile in $expiredLogFiles) {
    Invoke-PathRemoval -Path $logFile.FullName
}
Invoke-EmptyDirectoryRemoval -RootPath $logPath

if ($sandboxLogExpired -and (Test-Path -LiteralPath $sandboxLogPath -PathType Leaf)) {
    Invoke-PathRemoval -Path $sandboxLogPath
}

if ($IncludeSessions) {
    foreach ($sessionFile in $sessionCleanupPlan.PlannedRemovalFiles) {
        Invoke-PathRemoval -Path $sessionFile.FullName
    }

    Invoke-EmptyDirectoryRemoval -RootPath $sessionsPath
}

Write-StyledOutput ''
Write-StyledOutput 'Codex runtime cleanup summary'
Write-StyledOutput ("  Removed entries: {0}" -f $script:RemovedEntries)
Write-StyledOutput ("  Failed entries: {0}" -f $script:FailedEntries)
Write-StyledOutput ("  Reclaimed sizeMB: {0}" -f (Convert-BytesToMB -Bytes $script:ReclaimedBytes))

exit 0