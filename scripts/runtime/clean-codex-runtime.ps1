<#
.SYNOPSIS
    Cleans local Codex runtime folders and optionally prunes old session files.

.DESCRIPTION
    Removes transient runtime data under the local Codex home folder:
    - tmp/
    - vendor_imports/
    - log/ files older than the configured retention window

    Optionally prunes old files under sessions/ using a retention window.
    Default behavior is preview-only. Use -Apply to perform deletions.

.PARAMETER CodexHome
    Local Codex home path. Defaults to $env:USERPROFILE\.codex.

.PARAMETER IncludeSessions
    Includes session-file cleanup based on SessionRetentionDays.

.PARAMETER SessionRetentionDays
    Number of days of session history to keep when IncludeSessions is used.

.PARAMETER LogRetentionDays
    Number of days of log history to keep for .codex/log and sandbox.log.

.PARAMETER Apply
    Executes deletions. When omitted, script runs in preview mode only.

.PARAMETER DetailedOutput
    Prints additional diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/clean-codex-runtime.ps1

.EXAMPLE
    pwsh -File scripts/runtime/clean-codex-runtime.ps1 -LogRetentionDays 7

.EXAMPLE
    pwsh -File scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -SessionRetentionDays 60 -LogRetentionDays 7 -Apply

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $CodexHome = "$env:USERPROFILE\.codex",
    [switch] $IncludeSessions,
    [ValidateRange(1, 3650)] [int] $SessionRetentionDays = 90,
    [ValidateRange(1, 3650)] [int] $LogRetentionDays = 7,
    [switch] $Apply,
    [switch] $DetailedOutput
)

$ErrorActionPreference = 'Stop'
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
        Write-Output ("[DETAIL] {0}" -f $Message)
    }
}

# Converts bytes to megabytes with a fixed precision.
function Convert-BytesToMB {
    param(
        [long] $Bytes
    )

    return [math]::Round(($Bytes / 1MB), 2)
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
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) {
        $sum = 0
    }

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
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) {
            return [long] 0
        }

        return [long] $sum
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

$sessionFiles = @()
if ($IncludeSessions) {
    $sessionFiles = Get-ExpiredSessionFile -SessionsPath $sessionsPath -RetentionDays $SessionRetentionDays
}

$expiredLogFiles = Get-ExpiredFileByRetention -RootPath $logPath -RetentionDays $LogRetentionDays
$sandboxLogExpired = $false
if (Test-Path -LiteralPath $sandboxLogPath -PathType Leaf) {
    $sandboxLogCutoff = (Get-Date).AddDays(-1 * $LogRetentionDays)
    $sandboxLogItem = Get-Item -LiteralPath $sandboxLogPath -Force
    $sandboxLogExpired = $sandboxLogItem.LastWriteTime -lt $sandboxLogCutoff
}

Write-Output 'Codex runtime cleanup plan'
Write-Output ("  CodexHome: {0}" -f $resolvedCodexHome)
$executionMode = if ($Apply) { 'apply' } else { 'preview' }
Write-Output ("  Mode: {0}" -f $executionMode)
Write-Output ("  LogRetentionDays: {0}" -f $LogRetentionDays)
Write-Output ("  IncludeSessions: {0}" -f [bool] $IncludeSessions)
if ($IncludeSessions) {
    Write-Output ("  SessionRetentionDays: {0}" -f $SessionRetentionDays)
}

foreach ($target in $directoryTargets) {
    $stats = Get-PathStat -Path $target.path
    Write-Output ("  Target {0}: files={1} sizeMB={2}" -f $target.name, $stats.files, (Convert-BytesToMB -Bytes $stats.bytes))
}

$logStats = Get-PathStat -Path $logPath
$expiredLogBytes = ($expiredLogFiles | Measure-Object -Property Length -Sum).Sum
if ($null -eq $expiredLogBytes) {
    $expiredLogBytes = 0
}
Write-Output ("  Target log: files={0} sizeMB={1}" -f $logStats.files, (Convert-BytesToMB -Bytes $logStats.bytes))
Write-Output ("  Expired log files: {0} (sizeMB={1})" -f $expiredLogFiles.Count, (Convert-BytesToMB -Bytes $expiredLogBytes))

if (Test-Path -LiteralPath $sandboxLogPath -PathType Leaf) {
    $sandboxLogSize = (Get-Item -LiteralPath $sandboxLogPath -Force).Length
    Write-Output ("  Target sandbox.log: sizeMB={0} expired={1}" -f (Convert-BytesToMB -Bytes $sandboxLogSize), $sandboxLogExpired)
}
else {
    Write-Output '  Target sandbox.log: not found'
}

if ($IncludeSessions) {
    $sessionBytes = ($sessionFiles | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sessionBytes) {
        $sessionBytes = 0
    }

    Write-Output ("  Expired session files: {0} (sizeMB={1})" -f $sessionFiles.Count, (Convert-BytesToMB -Bytes $sessionBytes))
}

if (-not $Apply) {
    Write-Output ''
    Write-Output 'Preview complete. Re-run with -Apply to execute cleanup.'
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
    foreach ($sessionFile in $sessionFiles) {
        Invoke-PathRemoval -Path $sessionFile.FullName
    }

    Invoke-EmptyDirectoryRemoval -RootPath $sessionsPath
}

Write-Output ''
Write-Output 'Codex runtime cleanup summary'
Write-Output ("  Removed entries: {0}" -f $script:RemovedEntries)
Write-Output ("  Failed entries: {0}" -f $script:FailedEntries)
Write-Output ("  Reclaimed sizeMB: {0}" -f (Convert-BytesToMB -Bytes $script:ReclaimedBytes))

exit 0