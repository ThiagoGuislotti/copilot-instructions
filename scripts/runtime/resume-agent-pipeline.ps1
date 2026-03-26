<#
.SYNOPSIS
    Resumes a Super Agent pipeline from the last safe checkpoint.

.DESCRIPTION
    Loads checkpoint state and request artifacts from an existing run
    directory, resolves the next resumable stage, and re-enters the main
    pipeline runner from that safe checkpoint.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER RunDirectory
    Existing run directory that contains checkpoint-state.json and request artifacts.

.PARAMETER ExecutionBackend
    Pipeline execution backend. Choose between `script-only` and `codex-exec`.

.PARAMETER DispatchCommand
    Command used to invoke delegated Codex execution when the backend requires it.

.PARAMETER WarningOnly
    When true (default), pipeline failures are reported as warnings and exit code remains zero.

.PARAMETER StartAtStageId
    Optional explicit stage override. When omitted, resume uses the checkpoint-declared next safe stage.

.PARAMETER ApprovedStageIds
    Optional list of stage ids explicitly approved for sensitive execution.

.PARAMETER ApprovedAgentIds
    Optional list of agent ids explicitly approved for sensitive execution.

.PARAMETER ApprovedBy
    Required when approval ids are supplied. Identifies who approved the resumed run.

.PARAMETER ApprovalJustification
    Required when approval ids are supplied. Explains why the resumed sensitive execution was approved.

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/resume-agent-pipeline.ps1 -RunDirectory .temp/runs/run-20260322-010203

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RunDirectory,
    [ValidateSet('script-only', 'codex-exec')] [string] $ExecutionBackend = 'script-only',
    [string] $DispatchCommand = 'codex',
    [bool] $WarningOnly = $true,
    [string] $StartAtStageId,
    [string[]] $ApprovedStageIds = @(),
    [string[]] $ApprovedAgentIds = @(),
    [string] $ApprovedBy,
    [string] $ApprovalJustification,
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

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$resolvedRunDirectory = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $RunDirectory
$checkpointStatePath = Join-Path $resolvedRunDirectory 'checkpoint-state.json'
$requestPath = Join-Path $resolvedRunDirectory 'artifacts\request.md'
$pipelinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.codex/orchestration/pipelines/default.pipeline.json'
$runnerPath = Join-Path $resolvedRepoRoot 'scripts\runtime\run-agent-pipeline.ps1'

if (-not (Test-Path -LiteralPath $checkpointStatePath -PathType Leaf)) {
    throw "Checkpoint state not found: $checkpointStatePath"
}
if (-not (Test-Path -LiteralPath $requestPath -PathType Leaf)) {
    throw "Request artifact not found: $requestPath"
}

$checkpointState = Read-HardeningJsonFile -Path $checkpointStatePath
$pipeline = Read-HardeningJsonFile -Path $pipelinePath
$resumeDecision = Get-ResumeCheckpointDecision -CheckpointState $checkpointState -PipelineStages @($pipeline.stages) -RequestedStartStageId $StartAtStageId
$requestText = Get-Content -Raw -LiteralPath $requestPath
$runRoot = Split-Path -Parent $resolvedRunDirectory

& $runnerPath `
    -RepoRoot $resolvedRepoRoot `
    -RunRoot $runRoot `
    -TraceId ([string] $checkpointState.traceId) `
    -RequestText $requestText `
    -ResumeFromRunDirectory $resolvedRunDirectory `
    -StartAtStageId ([string] $resumeDecision.startStageId) `
    -ExecutionBackend $ExecutionBackend `
    -DispatchCommand $DispatchCommand `
    -WarningOnly:$WarningOnly `
    -ApprovedStageIds $ApprovedStageIds `
    -ApprovedAgentIds $ApprovedAgentIds `
    -ApprovedBy $ApprovedBy `
    -ApprovalJustification $ApprovalJustification `
    -DetailedOutput:$DetailedOutput