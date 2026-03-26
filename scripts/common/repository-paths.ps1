<#
.SYNOPSIS
    Shared repository path and logging helpers for runtime and validation scripts.

.DESCRIPTION
    Provides helper functions for:
    - repository root discovery
    - git-aware and solution/layout-aware root discovery
    - repository-relative path resolution
    - generic absolute/relative path conversion
    - parent directory resolution
    - verbose diagnostics
    - structured execution logging

    Consumers are expected to dot-source `console-style.ps1` first and set:
    - `$script:ScriptRoot`
    - `$script:IsVerboseEnabled`
    - optionally `$script:LogFilePath`

.PARAMETER None
    This helper script does not require input parameters.

.EXAMPLE
    . ./scripts/common/console-style.ps1
    . ./scripts/common/repository-paths.ps1
    $root = Resolve-RepositoryRoot -RequestedRoot $RepoRoot

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param()

$ErrorActionPreference = 'Stop'

# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    $verboseVariable = Get-Variable -Name IsVerboseEnabled -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $verboseVariable -and [bool] $verboseVariable.Value) {
        Write-StyledOutput ("[VERBOSE:{0}] {1}" -f $Color, $Message) | Out-Null
    }
}

# Writes plain verbose diagnostics when verbose mode is enabled.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    Write-VerboseColor -Message $Message -Color ([ConsoleColor]::Gray)
}

# Resolves the repository root using explicit and fallback location candidates.
function Resolve-RepositoryRoot {
    param(
        [string] $RequestedRoot
    )

    $candidates = @()
    $scriptRootVariable = Get-Variable -Name ScriptRoot -Scope Script -ErrorAction SilentlyContinue

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $RequestedRoot).Path
        }
        catch {
            throw "Invalid RepoRoot path: $RequestedRoot"
        }
    }

    if ($null -ne $scriptRootVariable -and -not [string]::IsNullOrWhiteSpace([string] $scriptRootVariable.Value)) {
        $scriptRootPath = [string] $scriptRootVariable.Value
        $repositoryCandidate = Join-Path (Join-Path $scriptRootPath '..') '..'
        $candidates += (Resolve-Path -LiteralPath $repositoryCandidate).Path
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Resolves the current working repository root from an explicit path, git root,
# or the current location when no git metadata is available.
function Resolve-GitRootOrCurrentPath {
    param(
        [string] $RequestedRoot,
        [string] $FallbackPath = (Get-Location).Path
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        if (-not (Test-Path -LiteralPath $RequestedRoot -PathType Container)) {
            throw "Requested RepoRoot does not exist: $RequestedRoot"
        }

        return (Resolve-Path -LiteralPath $RequestedRoot).Path
    }

    $gitRoot = (& git -C $FallbackPath rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string] $gitRoot)) {
        return ([string] $gitRoot).Trim()
    }

    return [System.IO.Path]::GetFullPath($FallbackPath)
}

# Resolves the current git checkout root from an explicit path or throws when
# the current location is not inside a repository.
function Resolve-ExplicitOrGitRoot {
    param(
        [string] $RequestedRoot,
        [string] $StartPath = (Get-Location).Path
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        if (-not (Test-Path -LiteralPath $RequestedRoot -PathType Container)) {
            throw "Requested RepoRoot does not exist: $RequestedRoot"
        }

        return (Resolve-Path -LiteralPath $RequestedRoot).Path
    }

    $gitRoot = (& git -C $StartPath rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string] $gitRoot)) {
        return ([string] $gitRoot).Trim()
    }

    throw 'Could not detect a git repository root. Use -RepoRoot explicitly.'
}

# Resolves a root path by searching for solution or source/module layout markers.
function Resolve-SolutionOrLayoutRoot {
    param(
        [string] $RequestedRoot,
        [string] $StartPath = (Get-Location).Path
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        if (-not (Test-Path -LiteralPath $RequestedRoot -PathType Container)) {
            throw "Requested RepoRoot '$RequestedRoot' does not exist."
        }

        return (Resolve-Path -LiteralPath $RequestedRoot).Path
    }

    $candidate = [System.IO.DirectoryInfo]::new($StartPath)
    for ($step = 0; $step -lt 6 -and $null -ne $candidate; $step++) {
        $candidatePath = $candidate.FullName
        $hasSolution = @(Get-ChildItem -LiteralPath $candidatePath -Filter *.sln -File -ErrorAction SilentlyContinue).Count -gt 0
        $hasSrc = Test-Path -LiteralPath (Join-Path $candidatePath 'src') -PathType Container
        $hasModules = Test-Path -LiteralPath (Join-Path $candidatePath 'modules') -PathType Container
        $hasGithub = Test-Path -LiteralPath (Join-Path $candidatePath '.github') -PathType Container

        if ($hasSolution -or ($hasSrc -and ($hasModules -or $hasGithub))) {
            return $candidatePath
        }

        $candidate = $candidate.Parent
    }

    throw "Could not auto-detect repository root from '$StartPath'."
}

# Builds an absolute path from repository root and relative input path.
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

# Builds an absolute path from repository root and relative input path.
function Resolve-PathFromRoot {
    param(
        [string] $RootPath,
        [string] $PathValue
    )

    return Resolve-FullPath -BasePath $RootPath -Candidate $PathValue
}

# Builds an absolute path from an arbitrary base path and relative input path.
function Resolve-FullPath {
    param(
        [string] $BasePath,
        [string] $Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($Candidate)) {
        return [System.IO.Path]::GetFullPath($Candidate)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Candidate))
}

# Converts an absolute path into a stable repository-relative path.
function Convert-ToRelativeRepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    return [System.IO.Path]::GetRelativePath($Root, $Path) -replace '\\', '/'
}

# Returns the parent directory for a given file path when available.
function Get-ParentDirectoryPath {
    param(
        [string] $Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return $null
    }

    return $parent
}

# Writes a session line to console output and optional log file.
function Write-ExecutionSessionOutput {
    param(
        [AllowEmptyString()]
        [string] $Message
    )

    $styledOutputCommand = Get-Command -Name Write-StyledOutput -ErrorAction SilentlyContinue
    if ($null -ne $styledOutputCommand) {
        Write-StyledOutput $Message | Out-Host
    }
    else {
        Write-Host $Message
    }

    $logFilePathVariable = Get-Variable -Name LogFilePath -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $logFilePathVariable -and -not [string]::IsNullOrWhiteSpace([string] $logFilePathVariable.Value)) {
        Add-Content -LiteralPath ([string] $logFilePathVariable.Value) -Value $Message
    }
}

# Converts session metadata values into stable single-line text.
function Convert-ExecutionSessionValueToText {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return 'none'
    }

    if ($Value -is [bool]) {
        return ([bool] $Value).ToString()
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @($Value | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($items.Count -eq 0) {
            return 'none'
        }

        return ($items -join ', ')
    }

    $text = [string] $Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return 'none'
    }

    return $text
}

# Starts a deterministic execution session with concise default output and
# verbose-expanded metadata.
function Start-ExecutionSession {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [string] $RootPath,
        [hashtable] $Metadata,
        [switch] $IncludeMetadataInDefaultOutput
    )

    $existingStateVariable = Get-Variable -Name ExecutionSessionState -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $existingStateVariable -and $null -ne $existingStateVariable.Value -and -not [bool] $existingStateVariable.Value.Completed) {
        return $existingStateVariable.Value
    }

    $verboseVariable = Get-Variable -Name IsVerboseEnabled -Scope Script -ErrorAction SilentlyContinue
    $isVerbose = ($null -ne $verboseVariable) -and [bool] $verboseVariable.Value
    $resolvedRootPath = if ([string]::IsNullOrWhiteSpace($RootPath)) { $null } else { [string] $RootPath }
    $sessionMetadata = [ordered]@{}
    if ($null -ne $Metadata) {
        foreach ($entry in ($Metadata.GetEnumerator() | Sort-Object Name)) {
            $sessionMetadata[[string] $entry.Key] = $entry.Value
        }
    }

    $sessionState = [pscustomobject]@{
        Name = $Name
        StartedAt = Get-Date
        RootPath = $resolvedRootPath
        Metadata = $sessionMetadata
        VerboseEnabled = $isVerbose
        Completed = $false
    }
    $script:ExecutionSessionState = $sessionState

    Write-ExecutionSessionOutput ''
    Write-ExecutionSessionOutput ("Session start: {0}" -f $Name)
    if (-not [string]::IsNullOrWhiteSpace($resolvedRootPath)) {
        Write-ExecutionSessionOutput ("  Repo root: {0}" -f $resolvedRootPath)
    }

    if ($sessionMetadata.Count -gt 0 -and ($IncludeMetadataInDefaultOutput -or $isVerbose)) {
        foreach ($entry in $sessionMetadata.GetEnumerator()) {
            Write-ExecutionSessionOutput ("  {0}: {1}" -f $entry.Key, (Convert-ExecutionSessionValueToText -Value $entry.Value))
        }
    }

    return $sessionState
}

# Completes the current execution session with deterministic status and
# duration output plus optional summary metrics.
function Complete-ExecutionSession {
    param(
        [string] $Name,
        [ValidateSet('passed', 'warning', 'failed', 'preview', 'skipped')]
        [string] $Status = 'passed',
        [hashtable] $Summary
    )

    $sessionStateVariable = Get-Variable -Name ExecutionSessionState -Scope Script -ErrorAction SilentlyContinue
    $sessionState = if ($null -ne $sessionStateVariable) { $sessionStateVariable.Value } else { $null }

    if ($null -eq $sessionState) {
        $sessionState = [pscustomobject]@{
            Name = if ([string]::IsNullOrWhiteSpace($Name)) { 'execution' } else { $Name }
            StartedAt = Get-Date
            Completed = $false
        }
        $script:ExecutionSessionState = $sessionState
    }

    if ([bool] $sessionState.Completed) {
        return $sessionState
    }

    $sessionName = if ([string]::IsNullOrWhiteSpace($Name)) { [string] $sessionState.Name } else { $Name }
    $finishedAt = Get-Date
    $durationMs = [int] ($finishedAt - [datetime] $sessionState.StartedAt).TotalMilliseconds

    Write-ExecutionSessionOutput ''
    Write-ExecutionSessionOutput ("Session end: {0}" -f $sessionName)
    Write-ExecutionSessionOutput ("  Status: {0}" -f $Status)
    Write-ExecutionSessionOutput ("  Duration (ms): {0}" -f $durationMs)

    if ($null -ne $Summary) {
        foreach ($entry in ($Summary.GetEnumerator() | Sort-Object Name)) {
            Write-ExecutionSessionOutput ("  {0}: {1}" -f $entry.Key, (Convert-ExecutionSessionValueToText -Value $entry.Value))
        }
    }

    $sessionState | Add-Member -NotePropertyName FinishedAt -NotePropertyValue $finishedAt -Force
    $sessionState | Add-Member -NotePropertyName Status -NotePropertyValue $Status -Force
    $sessionState | Add-Member -NotePropertyName DurationMs -NotePropertyValue $durationMs -Force
    $sessionState | Add-Member -NotePropertyName Completed -NotePropertyValue $true -Force
    $script:ExecutionSessionState = $sessionState

    return $sessionState
}

# Resets the runtime issue registry used by execution logging.
function Initialize-ExecutionIssueTracking {
    $script:ExecutionIssuesBySignature = @{}
    $script:ExecutionIssuesById = [ordered]@{}
    $script:ExecutionIssueSequence = @{
        warning = 0
        error = 0
    }
}

# Maps log levels to supported issue severity buckets.
function Get-ExecutionIssueSeverity {
    param(
        [string] $Level
    )

    $normalizedLevel = [string] $Level
    switch ($normalizedLevel.ToUpperInvariant()) {
        'WARN' { return 'warning' }
        'WARNING' { return 'warning' }
        'ERROR' { return 'error' }
        'FAIL' { return 'error' }
        default { return $null }
    }
}

# Creates the next issue id for the supplied severity.
function New-ExecutionIssueId {
    param(
        [ValidateSet('warning', 'error')]
        [string] $Severity
    )

    if ($null -eq $script:ExecutionIssueSequence) {
        Initialize-ExecutionIssueTracking
    }

    $script:ExecutionIssueSequence[$Severity] = [int] $script:ExecutionIssueSequence[$Severity] + 1
    $prefix = if ($Severity -eq 'error') { 'ERR' } else { 'WRN' }
    return ("{0}{1:D3}" -f $prefix, $script:ExecutionIssueSequence[$Severity])
}

# Registers a deduplicated warning/error issue for later summary output.
function Register-ExecutionIssue {
    param(
        [string] $Level,
        [string] $Code,
        [string] $Message
    )

    $severity = Get-ExecutionIssueSeverity -Level $Level
    if ([string]::IsNullOrWhiteSpace($severity)) {
        return $null
    }

    if ($null -eq $script:ExecutionIssuesBySignature -or $null -eq $script:ExecutionIssuesById -or $null -eq $script:ExecutionIssueSequence) {
        Initialize-ExecutionIssueTracking
    }

    $normalizedCode = if ([string]::IsNullOrWhiteSpace($Code)) {
        if ($severity -eq 'error') { 'UNSPECIFIED_ERROR' } else { 'UNSPECIFIED_WARNING' }
    }
    else {
        ([string] $Code).Trim().ToUpperInvariant()
    }

    $normalizedMessage = if ([string]::IsNullOrWhiteSpace($Message)) { '' } else { ([string] $Message).Trim() }
    $signature = "{0}|{1}|{2}" -f $severity, $normalizedCode, $normalizedMessage

    if ($script:ExecutionIssuesBySignature.ContainsKey($signature)) {
        $existingId = [string] $script:ExecutionIssuesBySignature[$signature]
        $existingIssue = $script:ExecutionIssuesById[$existingId]
        $existingIssue.occurrences = [int] $existingIssue.occurrences + 1
        $existingIssue.lastSeenAt = (Get-Date).ToString('o')
        return $existingIssue
    }

    $issueId = New-ExecutionIssueId -Severity $severity
    $issue = [pscustomobject]@{
        id = $issueId
        severity = $severity
        code = $normalizedCode
        message = $normalizedMessage
        occurrences = 1
        firstSeenAt = (Get-Date).ToString('o')
        lastSeenAt = (Get-Date).ToString('o')
    }

    $script:ExecutionIssuesBySignature[$signature] = $issueId
    $script:ExecutionIssuesById[$issueId] = $issue
    return $issue
}

# Returns the current execution issue registry as a summary object.
function Get-ExecutionIssueSummary {
    if ($null -eq $script:ExecutionIssuesById) {
        Initialize-ExecutionIssueTracking
    }

    $issues = @($script:ExecutionIssuesById.Values)
    $warningCount = @($issues | Where-Object { $_.severity -eq 'warning' }).Count
    $errorCount = @($issues | Where-Object { $_.severity -eq 'error' }).Count
    $warningMeasure = @($issues | Where-Object { $_.severity -eq 'warning' } | Measure-Object -Property occurrences -Sum) | Select-Object -First 1
    $errorMeasure = @($issues | Where-Object { $_.severity -eq 'error' } | Measure-Object -Property occurrences -Sum) | Select-Object -First 1
    $warningOccurrences = if ($null -eq $warningMeasure -or $null -eq $warningMeasure.Sum) { 0 } else { [int] $warningMeasure.Sum }
    $errorOccurrences = if ($null -eq $errorMeasure -or $null -eq $errorMeasure.Sum) { 0 } else { [int] $errorMeasure.Sum }

    return [pscustomobject]@{
        warnings = $warningCount
        errors = $errorCount
        warningOccurrences = $warningOccurrences
        errorOccurrences = $errorOccurrences
        totalIssues = $issues.Count
        totalOccurrences = $warningOccurrences + $errorOccurrences
        issues = @(
            $issues |
                Sort-Object -Property @{
                    Expression = { if ($_.severity -eq 'error') { 0 } else { 1 } }
                }, @{
                    Expression = { $_.id }
                }
        )
    }
}

# Writes the deduplicated warning/error issue summary for the current run.
function Write-ExecutionIssueSummary {
    param(
        [string] $Title = 'Execution issue summary'
    )

    $summary = Get-ExecutionIssueSummary
    $summaryLines = New-Object System.Collections.Generic.List[string]

    $summaryLines.Add('') | Out-Null
    $summaryLines.Add($Title) | Out-Null
    $summaryLines.Add('  Severity counts') | Out-Null
    $summaryLines.Add('  Severity  Distinct  Occurrences') | Out-Null
    $summaryLines.Add(("  Err       {0,-8} {1}" -f $summary.errors, $summary.errorOccurrences)) | Out-Null
    $summaryLines.Add(("  Wrn       {0,-8} {1}" -f $summary.warnings, $summary.warningOccurrences)) | Out-Null
    $summaryLines.Add(("  Total     {0,-8} {1}" -f $summary.totalIssues, $summary.totalOccurrences)) | Out-Null

    if ($summary.totalIssues -eq 0) {
        $summaryLines.Add('  Issues') | Out-Null
        $summaryLines.Add('    none') | Out-Null
    }
    else {
        $summaryLines.Add('  Issues') | Out-Null
        foreach ($issue in $summary.issues) {
            $summaryLines.Add(("    {0} | {1} | occurrences={2}" -f $issue.id, $issue.code, $issue.occurrences)) | Out-Null
        }
    }

    foreach ($line in $summaryLines) {
        Write-StyledOutput $line | Out-Host
    }

    $logFilePathVariable = Get-Variable -Name LogFilePath -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $logFilePathVariable -and $null -ne $logFilePathVariable.Value) {
        foreach ($line in $summaryLines) {
            Add-Content -LiteralPath $logFilePathVariable.Value -Value $line
        }
    }

    return $summary
}

# Writes execution log entries to console output and optional log file.
function Write-ExecutionLog {
    param(
        [string] $Level,
        [string] $Message,
        [string] $Code
    )

    $timestamp = (Get-Date).ToString('o')
    $issue = Register-ExecutionIssue -Level $Level -Code $Code -Message $Message
    $line = if ($null -eq $issue) {
        "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    }
    else {
        "[{0}] [{1}] [{2}] [{3}] {4}" -f $timestamp, $Level, $issue.id, $issue.code, $Message
    }

    $logFilePathVariable = Get-Variable -Name LogFilePath -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $logFilePathVariable -and $null -ne $logFilePathVariable.Value) {
        Add-Content -LiteralPath $logFilePathVariable.Value -Value $line
    }

    Write-StyledOutput $line | Out-Host
}