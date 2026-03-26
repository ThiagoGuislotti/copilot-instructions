<#
.SYNOPSIS
    Runtime tests for shared execution-session logging helpers.

.DESCRIPTION
    Verifies the shared execution-session lifecycle helpers used by runtime and
    validation scripts:
    - deterministic session start/end state
    - optional log-file mirroring
    - automatic validation session bootstrap

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/execution-session-logging.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-operation-support', 'validation-logging')

# Fails the test immediately when a required condition is not met.
function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
$logPath = Join-Path $tempRoot 'session.log'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $script:IsVerboseEnabled = $false
    $script:LogFilePath = $logPath
    Initialize-ExecutionIssueTracking

    $sessionState = Start-ExecutionSession -Name 'helper-smoke' -RootPath $resolvedRepoRoot -Metadata ([ordered]@{ 'Mode' = 'smoke'; 'Verbose enabled' = $false }) -IncludeMetadataInDefaultOutput
    Assert-True ($null -ne $sessionState) 'Start-ExecutionSession must return a session state.'
    Assert-True (-not [bool] $sessionState.Completed) 'Session must start incomplete.'

    $completedState = Complete-ExecutionSession -Name 'helper-smoke' -Status 'passed' -Summary ([ordered]@{ 'Checks' = 2 })
    Assert-True ([bool] $completedState.Completed) 'Complete-ExecutionSession must mark the session as completed.'
    Assert-True ([int] $completedState.DurationMs -ge 0) 'Complete-ExecutionSession must record a non-negative duration.'

    $logContent = Get-Content -Raw -LiteralPath $logPath
    Assert-True ($logContent.Contains('Session start: helper-smoke')) 'Session log must include the session start marker.'
    Assert-True ($logContent.Contains('Session end: helper-smoke')) 'Session log must include the session end marker.'

    Remove-Variable -Name ValidationSessionState -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name ExecutionSessionState -Scope Script -ErrorAction SilentlyContinue
    $script:IsWarningOnly = $true
    Initialize-ValidationState -WarningOnly $true -VerboseEnabled $false
    Assert-True ($null -ne $script:ValidationSessionState) 'Initialize-ValidationState must bootstrap a validation session.'
    Assert-True (-not [bool] $script:ValidationSessionState.Completed) 'Validation session must remain open until explicitly completed.'

    Complete-ValidationSession -Metrics ([ordered]@{ 'Checks' = 1 }) | Out-Null
    Assert-True ([bool] $script:ValidationSessionState.Completed) 'Complete-ValidationSession must complete the validation session.'

    Write-Host '[OK] execution session logging tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] execution session logging tests failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}