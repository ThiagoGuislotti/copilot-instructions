<#
.SYNOPSIS
    Runs safe Super Agent housekeeping for one workspace.

.DESCRIPTION
    Performs best-effort, planning-anchored housekeeping for a workspace in a
    way that is safe for active sessions:
    - exports a concise planning handoff summary first
    - refreshes the local context index used for safe RAG/CAG reuse
    - cleans persisted Codex runtime state
    - cleans persisted VS Code user-runtime state
    - enforces a workspace-local throttle so repeated session hooks do not run
      cleanup more often than the configured interval

    The script does not attempt to clear or mutate the live active model
    context window.

.PARAMETER WorkspacePath
    Target workspace path currently using the Super Agent. Defaults to the
    current working directory.

.PARAMETER RepoRoot
    Repository or workspace root used for planning-summary export. Defaults to
    WorkspacePath when omitted.

.PARAMETER IntervalHours
    Minimum number of hours between housekeeping runs for the same workspace.
    Defaults to 2.

.PARAMETER StateFilePath
    Optional state file path used to persist last-attempt and last-run
    timestamps for the throttle.

.PARAMETER Apply
    Executes cleanup after exporting the planning summary. When omitted, the
    script stays in preview mode.

.PARAMETER BypassThrottle
    Forces housekeeping to run regardless of the recorded last attempt.

.PARAMETER RecordOnlyPath
    Optional test-only output path. When set, the script records the planned
    housekeeping invocation and exits without touching the real runtime state.

.PARAMETER DetailedOutput
    Prints additional diagnostics.

.PARAMETER Verbose
    Shows verbose execution metadata.

.EXAMPLE
    pwsh -File scripts/runtime/invoke-super-agent-housekeeping.ps1 -WorkspacePath . -Apply

.EXAMPLE
    pwsh -File scripts/runtime/invoke-super-agent-housekeeping.ps1 -WorkspacePath . -RecordOnlyPath .temp/housekeeping-record.json

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $WorkspacePath,
    [string] $RepoRoot,
    [Nullable[int]] $IntervalHours,
    [string] $StateFilePath,
    [switch] $Apply,
    [switch] $BypassThrottle,
    [string] $RecordOnlyPath,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')

$script:IsDetailedOutputEnabled = [bool] $DetailedOutput

# Writes detail output only when enabled.
function Write-DetailedLog {
    param(
        [string] $Message
    )

    if ($script:IsDetailedOutputEnabled) {
        Write-StyledOutput ("[DETAIL] {0}" -f $Message)
    }
}

# Resolves the target workspace path.
function Resolve-WorkspaceRootPath {
    param(
        [string] $RequestedPath
    )

    $candidate = if ([string]::IsNullOrWhiteSpace($RequestedPath)) { $PWD.Path } else { $RequestedPath }
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        throw ("WorkspacePath not found: {0}" -f $candidate)
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

# Resolves the state file path used by the housekeeping throttle.
function Resolve-HousekeepingStateFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedWorkspacePath,
        [string] $RequestedStatePath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedStatePath)) {
        if ([System.IO.Path]::IsPathRooted($RequestedStatePath)) {
            return [System.IO.Path]::GetFullPath($RequestedStatePath)
        }

        return [System.IO.Path]::GetFullPath((Join-Path $ResolvedWorkspacePath $RequestedStatePath))
    }

    return (Join-Path $ResolvedWorkspacePath '.build/super-agent/runtime/housekeeping.state.json')
}

# Reads one optional housekeeping state document.
function Read-HousekeepingState {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedStateFilePath
    )

    if (-not (Test-Path -LiteralPath $ResolvedStateFilePath -PathType Leaf)) {
        return $null
    }

    try {
        return (Get-Content -Raw -LiteralPath $ResolvedStateFilePath | ConvertFrom-Json -Depth 20)
    }
    catch {
        Write-DetailedLog ("Ignoring invalid housekeeping state file: {0}" -f $ResolvedStateFilePath)
        return $null
    }
}

# Writes one housekeeping state document.
function Save-HousekeepingState {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedStateFilePath,
        [Parameter(Mandatory = $true)]
        [hashtable] $State
    )

    $parentPath = Split-Path -Path $ResolvedStateFilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }

    $State | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ResolvedStateFilePath
}

# Resolves the last relevant housekeeping timestamp from state.
function Get-LastHousekeepingTimestamp {
    param(
        [AllowNull()]
        [object] $State
    )

    if ($null -eq $State) {
        return $null
    }

    foreach ($propertyName in @('lastAttemptAt', 'lastRunAt')) {
        $property = $State.PSObject.Properties[$propertyName]
        if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string] $property.Value)) {
            continue
        }

        try {
            return [datetime] $property.Value
        }
        catch {
            continue
        }
    }

    return $null
}

# Returns true when housekeeping should be skipped because it ran recently.
function Test-ShouldSkipHousekeeping {
    param(
        [AllowNull()]
        [Nullable[datetime]] $LastActivityAt,
        [int] $EffectiveIntervalHours
    )

    if ($EffectiveIntervalHours -le 0 -or $null -eq $LastActivityAt) {
        return $false
    }

    $threshold = (Get-Date).AddHours(-1 * $EffectiveIntervalHours)
    return ([datetime] $LastActivityAt -gt $threshold)
}

# Resolves one runtime script path expected under scripts/runtime.
function Resolve-RuntimeScriptPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptName
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw ("Missing runtime script: {0}" -f $scriptPath)
    }

    return $scriptPath
}

$resolvedWorkspacePath = Resolve-WorkspaceRootPath -RequestedPath $WorkspacePath
$resolvedRepoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $resolvedWorkspacePath } else { Resolve-WorkspaceRootPath -RequestedPath $RepoRoot }
$effectiveIntervalHours = if ($null -eq $IntervalHours) { 2 } else { [int] $IntervalHours }
if ($effectiveIntervalHours -lt 1) {
    throw 'IntervalHours must be >= 1.'
}
$resolvedStateFilePath = Resolve-HousekeepingStateFilePath -ResolvedWorkspacePath $resolvedWorkspacePath -RequestedStatePath $StateFilePath
$existingState = Read-HousekeepingState -ResolvedStateFilePath $resolvedStateFilePath
$lastHousekeepingAt = Get-LastHousekeepingTimestamp -State $existingState

Start-ExecutionSession `
    -Name 'invoke-super-agent-housekeeping' `
    -RootPath $resolvedWorkspacePath `
    -Metadata ([ordered]@{
        Mode = $(if ($Apply) { 'apply' } else { 'preview' })
        RepoRoot = $resolvedRepoRoot
        IntervalHours = $effectiveIntervalHours
        StateFilePath = $resolvedStateFilePath
        LastActivityAt = $(if ($null -ne $lastHousekeepingAt) { $lastHousekeepingAt.ToString('o') } else { 'none' })
    }) `
    -IncludeMetadataInDefaultOutput | Out-Null

if ((-not $BypassThrottle) -and (Test-ShouldSkipHousekeeping -LastActivityAt $lastHousekeepingAt -EffectiveIntervalHours $effectiveIntervalHours)) {
    Write-StyledOutput 'Super Agent housekeeping skipped because the throttle window is still active.'
    Complete-ExecutionSession -Name 'invoke-super-agent-housekeeping' -Status 'skipped' -Summary ([ordered]@{
            LastActivityAt = $lastHousekeepingAt.ToString('o')
            IntervalHours = $effectiveIntervalHours
        }) | Out-Null
    exit 0
}

$attemptedAt = (Get-Date).ToString('o')
$statePayload = [ordered]@{
    workspacePath = $resolvedWorkspacePath
    lastAttemptAt = $attemptedAt
    lastRunAt = if ($null -ne $existingState -and $null -ne $existingState.PSObject.Properties['lastRunAt']) { [string] $existingState.lastRunAt } else { $null }
    lastStatus = 'running'
}
Save-HousekeepingState -ResolvedStateFilePath $resolvedStateFilePath -State $statePayload

if (-not [string]::IsNullOrWhiteSpace($RecordOnlyPath)) {
    $recordParent = Split-Path -Path $RecordOnlyPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($recordParent)) {
        New-Item -ItemType Directory -Path $recordParent -Force | Out-Null
    }

    ([ordered]@{
            workspacePath = $resolvedWorkspacePath
            repoRoot = $resolvedRepoRoot
            stateFilePath = $resolvedStateFilePath
            intervalHours = $effectiveIntervalHours
            apply = [bool] $Apply
            recordedAt = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $RecordOnlyPath

    $statePayload.lastRunAt = (Get-Date).ToString('o')
    $statePayload.lastStatus = 'recorded'
    Save-HousekeepingState -ResolvedStateFilePath $resolvedStateFilePath -State $statePayload

    Complete-ExecutionSession -Name 'invoke-super-agent-housekeeping' -Status 'passed' -Summary ([ordered]@{
            RecordOnlyPath = $RecordOnlyPath
            WorkspacePath = $resolvedWorkspacePath
        }) | Out-Null
    exit 0
}

$updateLocalIndexScript = Resolve-RuntimeScriptPath -ScriptName 'update-local-context-index.ps1'
$exportScript = Resolve-RuntimeScriptPath -ScriptName 'export-planning-summary.ps1'
$cleanCodexScript = Resolve-RuntimeScriptPath -ScriptName 'clean-codex-runtime.ps1'
$cleanVscodeScript = Resolve-RuntimeScriptPath -ScriptName 'clean-vscode-user-runtime.ps1'

Write-DetailedLog 'Refreshing local context index.'
& $updateLocalIndexScript -RepoRoot $resolvedRepoRoot -DetailedOutput:$DetailedOutput | Out-Host

Write-StyledOutput 'Exporting planning handoff summary before housekeeping cleanup...'
& $exportScript -RepoRoot $resolvedRepoRoot | Out-Host

Write-DetailedLog 'Running Codex runtime cleanup.'
if ($Apply) {
    & $cleanCodexScript -RepoRoot $resolvedRepoRoot -IncludeSessions -Apply | Out-Host
}
else {
    & $cleanCodexScript -RepoRoot $resolvedRepoRoot -IncludeSessions | Out-Host
}

Write-DetailedLog 'Running VS Code user-runtime cleanup.'
if ($Apply) {
    & $cleanVscodeScript -RepoRoot $resolvedRepoRoot -Apply -RecentRunWindowHours 0 | Out-Host
}
else {
    & $cleanVscodeScript -RepoRoot $resolvedRepoRoot -RecentRunWindowHours 0 | Out-Host
}

$statePayload.lastRunAt = (Get-Date).ToString('o')
$statePayload.lastStatus = if ($Apply) { 'passed' } else { 'preview' }
Save-HousekeepingState -ResolvedStateFilePath $resolvedStateFilePath -State $statePayload

Complete-ExecutionSession -Name 'invoke-super-agent-housekeeping' -Status $(if ($Apply) { 'passed' } else { 'preview' }) -Summary ([ordered]@{
        WorkspacePath = $resolvedWorkspacePath
        RepoRoot = $resolvedRepoRoot
        StateFilePath = $resolvedStateFilePath
    }) | Out-Null

exit 0