<#
.SYNOPSIS
    Summarizes a recorded Super Agent run from trace, policy, and checkpoint artifacts.

.DESCRIPTION
    Loads run-artifact, trace, policy, and checkpoint files from a completed
    run directory and emits a compact replay summary that can also be written
    as JSON for later inspection.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER RunDirectory
    Existing run directory that contains the recorded orchestration artifacts.

.PARAMETER OutputPath
    Optional output path for the generated replay summary JSON.

.PARAMETER DetailedOutput
    Shows detailed diagnostics for the replay session.

.EXAMPLE
    pwsh -File scripts/runtime/replay-agent-run.ps1 -RunDirectory .temp/runs/run-20260322-010203

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RunDirectory,
    [string] $OutputPath,
    [switch] $DetailedOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths', 'agent-runtime-hardening')
$script:IsVerboseEnabled = [bool] $DetailedOutput

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Start-ExecutionSession `
    -Name 'replay-agent-run' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Run directory' = $RunDirectory
            'Output path' = $(if ([string]::IsNullOrWhiteSpace($OutputPath)) { 'none' } else { $OutputPath })
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null
$resolvedRunDirectory = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $RunDirectory
$runArtifactPath = Join-Path $resolvedRunDirectory 'run-artifact.json'
$traceRecordPath = Join-Path $resolvedRunDirectory 'trace-record.json'
$policyEvaluationsPath = Join-Path $resolvedRunDirectory 'policy-evaluations.json'
$checkpointStatePath = Join-Path $resolvedRunDirectory 'checkpoint-state.json'

foreach ($requiredPath in @($runArtifactPath, $traceRecordPath, $policyEvaluationsPath, $checkpointStatePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required run artifact not found: $requiredPath"
    }
}

$runArtifact = Read-HardeningJsonFile -Path $runArtifactPath
$traceRecord = Read-HardeningJsonFile -Path $traceRecordPath
$policyRecord = Read-HardeningJsonFile -Path $policyEvaluationsPath
$checkpointState = Read-HardeningJsonFile -Path $checkpointStatePath

$summary = [ordered]@{
    traceId = [string] $runArtifact.traceId
    pipelineId = [string] $runArtifact.pipelineId
    status = [string] $runArtifact.status
    stageCount = [int] $runArtifact.summary.stageCount
    totalDurationMs = [int] $runArtifact.summary.totalDurationMs
    policyWarningCount = [int] $runArtifact.summary.policyWarningCount
    policyBlockCount = [int] $runArtifact.summary.policyBlockCount
    lastSuccessfulStageId = [string] $checkpointState.lastSuccessfulStageId
    resumableFromStageId = [string] $checkpointState.resumableFromStageId
    stages = @($traceRecord.stages | ForEach-Object {
            [ordered]@{
                stageId = [string] $_.stageId
                status = [string] $_.status
                durationMs = [int] $_.durationMs
                effectiveModel = [string] $_.model.effectiveModel
                policyWarnings = [int] $_.policy.warningCount
                policyBlocks = [int] $_.policy.blockCount
            }
        })
    policyRuleIds = @($policyRecord.evaluations | ForEach-Object { [string] $_.ruleId } | Select-Object -Unique)
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutputPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $OutputPath
    Write-HardeningJsonFile -Path $resolvedOutputPath -Value $summary
}

Complete-ExecutionSession -Name 'replay-agent-run' -Status $(if ([string] $summary.status -eq 'failed') { 'failed' } elseif ([int] $summary.policyBlockCount -gt 0) { 'warning' } else { 'passed' }) -Summary ([ordered]@{
        'Stage count' = $summary.stageCount
        'Policy warnings' = $summary.policyWarningCount
        'Policy blocks' = $summary.policyBlockCount
    }) | Out-Null
$summary | ConvertTo-Json -Depth 50