<#
.SYNOPSIS
    Shared validation logging and summary helpers.

.DESCRIPTION
    Provides reusable helpers for validation-oriented scripts:
    - warning/failure list initialization
    - standardized warning/failure output
    - compact validation summary rendering

    Consumers are expected to dot-source `console-style.ps1` first and set:
    - `$script:IsVerboseEnabled`
    - `$script:IsWarningOnly` when warning-only behavior applies

    Consumers must also dot-source `repository-paths.ps1` first so the shared
    verbose helpers remain centralized in one place.

.PARAMETER None
    This helper script does not require input parameters.

.EXAMPLE
    . ./scripts/common/console-style.ps1
    . ./scripts/common/repository-paths.ps1
    . ./scripts/common/validation-logging.ps1
    Initialize-ValidationState -WarningOnly $true -VerboseEnabled $false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name Write-VerboseLog -ErrorAction SilentlyContinue)) {
    throw 'validation-logging.ps1 requires repository-paths.ps1 to be loaded first.'
}

# Resolves the current validation session name from the caller script path.
function Get-ValidationSessionName {
    $commandPathVariable = Get-Variable -Name PSCommandPath -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $commandPathVariable -and -not [string]::IsNullOrWhiteSpace([string] $commandPathVariable.Value)) {
        return [System.IO.Path]::GetFileNameWithoutExtension([string] $commandPathVariable.Value)
    }

    return 'validation-script'
}

# Starts the validation session once for the current script scope.
function Start-ValidationSession {
    param(
        [switch] $IncludeMetadataInDefaultOutput
    )

    $sessionStateVariable = Get-Variable -Name ValidationSessionState -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $sessionStateVariable -and $null -ne $sessionStateVariable.Value -and -not [bool] $sessionStateVariable.Value.Completed) {
        return $sessionStateVariable.Value
    }

    $warningOnlyVariable = Get-Variable -Name IsWarningOnly -Scope Script -ErrorAction SilentlyContinue
    $sessionMetadata = [ordered]@{
        'Verbose enabled' = [bool] $script:IsVerboseEnabled
    }
    if ($null -ne $warningOnlyVariable) {
        $sessionMetadata['Warning-only mode'] = [bool] $warningOnlyVariable.Value
    }

    $script:ValidationSessionState = Start-ExecutionSession `
        -Name (Get-ValidationSessionName) `
        -Metadata $sessionMetadata `
        -IncludeMetadataInDefaultOutput:$IncludeMetadataInDefaultOutput

    return $script:ValidationSessionState
}

# Completes the validation session using current warning/failure counts and
# any supplied metrics.
function Complete-ValidationSession {
    param(
        [hashtable] $Metrics,
        [switch] $IncludeWarningOnlyMode
    )

    $counts = Get-ValidationCounts
    $summary = [ordered]@{}
    if ($IncludeWarningOnlyMode) {
        $summary['Warning-only mode'] = [bool] $script:IsWarningOnly
    }
    if ($null -ne $Metrics) {
        foreach ($entry in ($Metrics.GetEnumerator() | Sort-Object Name)) {
            $summary[[string] $entry.Key] = $entry.Value
        }
    }
    $summary['Warnings'] = $counts.warnings
    $summary['Failures'] = $counts.failures

    $status = if ($counts.failures -gt 0) { 'failed' } elseif ($counts.warnings -gt 0) { 'warning' } else { 'passed' }
    $script:ValidationSessionState = Complete-ExecutionSession -Name (Get-ValidationSessionName) -Status $status -Summary $summary
    return $script:ValidationSessionState
}

# Initializes validation warning/failure state for the current script scope.
function Initialize-ValidationState {
    param(
        [bool] $WarningOnly = $false,
        [bool] $VerboseEnabled = $false
    )

    $script:IsWarningOnly = $WarningOnly
    $script:IsVerboseEnabled = $VerboseEnabled

    $warningsVariable = Get-Variable -Name Warnings -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $warningsVariable -or $null -eq $warningsVariable.Value -or -not ($warningsVariable.Value -is [System.Collections.Generic.List[string]])) {
        $script:Warnings = New-Object System.Collections.Generic.List[string]
    }

    $failuresVariable = Get-Variable -Name Failures -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $failuresVariable -or $null -eq $failuresVariable.Value -or -not ($failuresVariable.Value -is [System.Collections.Generic.List[string]])) {
        $script:Failures = New-Object System.Collections.Generic.List[string]
    }

    Start-ValidationSession | Out-Null
}

# Writes styled validation output with a simple host fallback.
function Write-ValidationOutput {
    param(
        [string] $Message
    )

    if (Get-Command -Name Write-StyledOutput -ErrorAction SilentlyContinue) {
        Write-StyledOutput $Message
        return
    }

    Write-Host $Message
}

# Registers a validation warning and prints a standardized warning message.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $warningsVariable = Get-Variable -Name Warnings -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $warningsVariable -or $null -eq $warningsVariable.Value) {
        Initialize-ValidationState -WarningOnly $false -VerboseEnabled $false
    }

    $script:Warnings.Add($Message) | Out-Null
    Write-ValidationOutput ("[WARN] {0}" -f $Message)
}

# Registers a validation failure and prints a standardized failure or warning
# message depending on warning-only mode.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $warningsVariable = Get-Variable -Name Warnings -Scope Script -ErrorAction SilentlyContinue
    $failuresVariable = Get-Variable -Name Failures -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $warningsVariable -or $null -eq $warningsVariable.Value -or $null -eq $failuresVariable -or $null -eq $failuresVariable.Value) {
        Initialize-ValidationState -WarningOnly $false -VerboseEnabled $false
    }

    $warningOnlyVariable = Get-Variable -Name IsWarningOnly -Scope Script -ErrorAction SilentlyContinue
    if ($null -ne $warningOnlyVariable -and [bool] $warningOnlyVariable.Value) {
        Add-ValidationWarning -Message $Message
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-ValidationOutput ("[FAIL] {0}" -f $Message)
}

# Returns current validation counts safely.
function Get-ValidationCounts {
    $warningsVariable = Get-Variable -Name Warnings -Scope Script -ErrorAction SilentlyContinue
    $failuresVariable = Get-Variable -Name Failures -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $warningsVariable -or $null -eq $warningsVariable.Value -or $null -eq $failuresVariable -or $null -eq $failuresVariable.Value) {
        Initialize-ValidationState -WarningOnly $false -VerboseEnabled $false
    }

    return [pscustomobject]@{
        warnings = $script:Warnings.Count
        failures = $script:Failures.Count
    }
}

# Writes a standard validation summary with optional extra metrics.
function Write-ValidationSummary {
    param(
        [string] $Title,
        [hashtable] $Metrics,
        [string] $PassMessage,
        [string] $CompletedWithWarningsMessage,
        [switch] $IncludeWarningOnlyMode
    )

    $counts = Get-ValidationCounts

    Write-ValidationOutput ''
    Write-ValidationOutput $Title

    if ($IncludeWarningOnlyMode) {
        Write-ValidationOutput ("  Warning-only mode: {0}" -f [bool] $script:IsWarningOnly)
    }

    if ($null -ne $Metrics) {
        foreach ($entry in $Metrics.GetEnumerator()) {
            Write-ValidationOutput ("  {0}: {1}" -f $entry.Key, $entry.Value)
        }
    }

    Write-ValidationOutput ("  Warnings: {0}" -f $counts.warnings)
    Write-ValidationOutput ("  Failures: {0}" -f $counts.failures)

    Complete-ValidationSession | Out-Null

    if ($counts.failures -eq 0 -and $counts.warnings -eq 0) {
        if (-not [string]::IsNullOrWhiteSpace($PassMessage)) {
            Write-ValidationOutput $PassMessage
        }
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($CompletedWithWarningsMessage)) {
        Write-ValidationOutput $CompletedWithWarningsMessage
    }
}