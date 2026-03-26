<#
.SYNOPSIS
    Shared runtime helpers for script invocation and operation log/output setup.

.DESCRIPTION
    Centralizes common runtime execution patterns used by healthcheck,
    self-heal, and related report-generating scripts:
    - ensuring parent directories exist
    - initializing text log files
    - invoking child PowerShell scripts with consistent status and logging

.EXAMPLE
    . ./scripts/common/runtime-operation-support.ps1
    Initialize-PathParentDirectory -Path '.temp/report.json'

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

$ErrorActionPreference = 'Stop'

# Initializes the parent directory for a target file path when needed.
function Initialize-PathParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $parentPath = Get-ParentDirectoryPath -Path $Path
    if (-not [string]::IsNullOrWhiteSpace($parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }
}

# Initializes a text log file with a deterministic header and returns the path.
function Initialize-OperationLogFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LogPath,
        [Parameter(Mandatory = $true)]
        [string] $LogName
    )

    Initialize-PathParentDirectory -Path $LogPath
    Set-Content -LiteralPath $LogPath -Value ("# {0} log`n# generatedAt={1}" -f $LogName, (Get-Date).ToString('o'))
    return $LogPath
}

# Resolves output/log paths for an operation and initializes required folders
# plus the text log file.
function Initialize-OperationArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [Parameter(Mandatory = $true)]
        [string] $PrimaryOutputPath,
        [string[]] $AdditionalOutputPaths = @(),
        [string] $LogPath,
        [Parameter(Mandatory = $true)]
        [string] $DefaultLogFilePrefix,
        [Parameter(Mandatory = $true)]
        [string] $LogName
    )

    $resolvedPrimaryOutputPath = Resolve-RepoPath -Root $ResolvedRepoRoot -Path $PrimaryOutputPath
    $resolvedAdditionalOutputPaths = @($AdditionalOutputPaths | ForEach-Object { Resolve-RepoPath -Root $ResolvedRepoRoot -Path $_ })

    $resolvedLogPath = if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $timestampToken = Get-Date -Format 'yyyyMMdd-HHmmss'
        Resolve-RepoPath -Root $ResolvedRepoRoot -Path (".temp/logs/{0}-{1}.log" -f $DefaultLogFilePrefix, $timestampToken)
    }
    else {
        Resolve-RepoPath -Root $ResolvedRepoRoot -Path $LogPath
    }

    Initialize-PathParentDirectory -Path $resolvedPrimaryOutputPath
    foreach ($additionalPath in $resolvedAdditionalOutputPaths) {
        Initialize-PathParentDirectory -Path $additionalPath
    }

    Initialize-OperationLogFile -LogPath $resolvedLogPath -LogName $LogName | Out-Null

    return [pscustomobject]@{
        PrimaryOutputPath = $resolvedPrimaryOutputPath
        AdditionalOutputPaths = $resolvedAdditionalOutputPaths
        LogPath = $resolvedLogPath
    }
}

# Starts a standardized runtime operation session after output/log paths are resolved.
function Start-RuntimeOperationSession {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [string] $RuntimeProfileName,
        [string] $PrimaryOutputPath,
        [string] $LogPath,
        [hashtable] $AdditionalMetadata,
        [switch] $IncludeMetadataInDefaultOutput
    )

    $metadata = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace($RuntimeProfileName)) {
        $metadata['Runtime profile'] = $RuntimeProfileName
    }
    if (-not [string]::IsNullOrWhiteSpace($PrimaryOutputPath)) {
        $metadata['Output path'] = $PrimaryOutputPath
    }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $metadata['Log path'] = $LogPath
    }
    if ($null -ne $AdditionalMetadata) {
        foreach ($entry in ($AdditionalMetadata.GetEnumerator() | Sort-Object Name)) {
            $metadata[[string] $entry.Key] = $entry.Value
        }
    }

    return Start-ExecutionSession `
        -Name $Name `
        -RootPath $ResolvedRepoRoot `
        -Metadata $metadata `
        -IncludeMetadataInDefaultOutput:$IncludeMetadataInDefaultOutput
}

# Completes a standardized runtime operation session with status and summary values.
function Complete-RuntimeOperationSession {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [ValidateSet('passed', 'warning', 'failed', 'preview', 'skipped')]
        [string] $Status = 'passed',
        [hashtable] $Summary
    )

    return Complete-ExecutionSession -Name $Name -Status $Status -Summary $Summary
}

# Invokes a child script with standardized logging, duration, and failure handling.
function Invoke-ManagedScriptInvocation {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $ScriptPath,
        [Parameter(Mandatory = $true)]
        [hashtable] $Arguments,
        [bool] $TreatFailureAsWarning = $false,
        [Parameter(Mandatory = $true)]
        [string] $NotFoundCode,
        [Parameter(Mandatory = $true)]
        [string] $FailureCode,
        [Parameter(Mandatory = $true)]
        [string] $ExceptionCode,
        [string] $WarningFailureCode,
        [string] $WarningExceptionCode,
        [string] $StartMessagePrefix = 'Starting step',
        [string] $SuccessMessagePrefix = 'Step passed',
        [string] $FailureMessagePrefix = 'Step failed',
        [string] $ExceptionMessagePrefix = 'Step exception',
        [string] $WarningFailureMessageSuffix = '(non-zero exit converted to warning)',
        [string] $WarningExceptionMessageLabel = 'exception converted to warning'
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        $errorMessage = "Script not found: $ScriptPath"
        if ($TreatFailureAsWarning) {
            $status = 'warning'
            $exitCode = 0
            Write-ExecutionLog -Level 'WARN' -Code $NotFoundCode -Message ("{0}: {1}" -f $Name, $errorMessage)
        }
        else {
            Write-ExecutionLog -Level 'ERROR' -Code $NotFoundCode -Message ("{0}: {1}" -f $Name, $errorMessage)
        }
    }
    else {
        Write-ExecutionLog -Level 'INFO' -Message ("{0}: {1}" -f $StartMessagePrefix, $Name)
        try {
            & $ScriptPath @Arguments | Out-Host
            $lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue
            $exitCode = if ($null -eq $lastExitCodeVariable) { 0 } else { [int] $lastExitCodeVariable.Value }

            if ($exitCode -eq 0) {
                $status = 'passed'
                Write-ExecutionLog -Level 'OK' -Message ("{0}: {1}" -f $SuccessMessagePrefix, $Name)
            }
            elseif ($TreatFailureAsWarning) {
                $status = 'warning'
                $exitCode = 0
                $warningCode = if ([string]::IsNullOrWhiteSpace($WarningFailureCode)) { $FailureCode } else { $WarningFailureCode }
                Write-ExecutionLog -Level 'WARN' -Code $warningCode -Message ("{0}: {1} {2}" -f $FailureMessagePrefix, $Name, $WarningFailureMessageSuffix)
            }
            else {
                Write-ExecutionLog -Level 'ERROR' -Code $FailureCode -Message ("{0}: {1} (exit code {2})" -f $FailureMessagePrefix, $Name, $exitCode)
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($TreatFailureAsWarning) {
                $status = 'warning'
                $exitCode = 0
                $warningCode = if ([string]::IsNullOrWhiteSpace($WarningExceptionCode)) { $ExceptionCode } else { $WarningExceptionCode }
                Write-ExecutionLog -Level 'WARN' -Code $warningCode -Message ("{0}: {1} ({2}: {3})" -f $FailureMessagePrefix, $Name, $WarningExceptionMessageLabel, $errorMessage)
            }
            else {
                Write-ExecutionLog -Level 'ERROR' -Code $ExceptionCode -Message ("{0}: {1} :: {2}" -f $ExceptionMessagePrefix, $Name, $errorMessage)
            }
        }
    }

    $finishedAt = Get-Date
    $durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
    $relativeScriptPath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $ScriptPath)
    $argumentList = @()
    foreach ($entry in ($Arguments.GetEnumerator() | Sort-Object Name)) {
        $argumentList += ("-{0}={1}" -f $entry.Key, $entry.Value)
    }

    return [pscustomobject]@{
        name = $Name
        script = $relativeScriptPath
        arguments = $argumentList
        status = $status
        exitCode = $exitCode
        durationMs = $durationMs
        startedAt = $startedAt.ToString('o')
        finishedAt = $finishedAt.ToString('o')
        error = $errorMessage
    }
}

# Invokes a child runtime script using the standardized healthcheck-style
# check contract.
function Invoke-ManagedRuntimeCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $ScriptPath,
        [Parameter(Mandatory = $true)]
        [hashtable] $Arguments,
        [bool] $TreatFailureAsWarning = $false
    )

    return (Invoke-ManagedScriptInvocation `
            -Name $Name `
            -ScriptPath $ScriptPath `
            -Arguments $Arguments `
            -TreatFailureAsWarning:$TreatFailureAsWarning `
            -NotFoundCode 'HEALTHCHECK_SCRIPT_NOT_FOUND' `
            -FailureCode 'HEALTHCHECK_CHECK_FAILED' `
            -ExceptionCode 'HEALTHCHECK_CHECK_EXCEPTION' `
            -WarningFailureCode 'HEALTHCHECK_CHECK_WARNING' `
            -WarningExceptionCode 'HEALTHCHECK_CHECK_EXCEPTION_WARNING' `
            -StartMessagePrefix 'Starting check' `
            -SuccessMessagePrefix 'Check passed' `
            -FailureMessagePrefix 'Check failed' `
            -ExceptionMessagePrefix 'Check exception')
}

# Invokes a child runtime script using the standardized self-heal-style step
# contract.
function Invoke-ManagedRuntimeStep {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $ScriptPath,
        [Parameter(Mandatory = $true)]
        [hashtable] $Arguments
    )

    return (Invoke-ManagedScriptInvocation `
            -Name $Name `
            -ScriptPath $ScriptPath `
            -Arguments $Arguments `
            -NotFoundCode 'SELF_HEAL_SCRIPT_NOT_FOUND' `
            -FailureCode 'SELF_HEAL_STEP_FAILED' `
            -ExceptionCode 'SELF_HEAL_STEP_EXCEPTION' `
            -StartMessagePrefix 'Starting step' `
            -SuccessMessagePrefix 'Step passed' `
            -FailureMessagePrefix 'Step failed' `
            -ExceptionMessagePrefix 'Step exception')
}