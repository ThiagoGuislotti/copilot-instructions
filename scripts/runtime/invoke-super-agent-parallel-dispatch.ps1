<#
.SYNOPSIS
    Runs the full Super Agent lifecycle with live Codex execution so safe parallel task batches can fan out.

.DESCRIPTION
    Thin repository-owned entrypoint for live `codex-exec` orchestration when
    task batching and safe parallel dispatch are desired.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected by the underlying runner when omitted.

.PARAMETER RequestText
    User request text to execute.

.PARAMETER DispatchCommand
    Codex CLI command name used for live dispatch.

.PARAMETER PreviewOnly
    Emits the pipeline invocation payload as JSON without executing it.

.PARAMETER ApprovedStageIds
    Optional sensitive stage ids approved for this run.

.PARAMETER ApprovedAgentIds
    Optional sensitive agent ids approved for this run.

.PARAMETER ApprovedBy
    Identifies who approved the sensitive execution.

.PARAMETER ApprovalJustification
    Explains why the sensitive execution was approved.

.PARAMETER DetailedOutput
    Enables verbose diagnostics.

.EXAMPLE
    pwsh -File .\scripts\runtime\invoke-super-agent-parallel-dispatch.ps1 -RepoRoot . -RequestText "Execute independent work items" -PreviewOnly

.NOTES
    Forces `ExecutionBackend = codex-exec`.
#>

param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RequestText,
    [string] $DispatchCommand = 'codex',
    [switch] $PreviewOnly,
    [string[]] $ApprovedStageIds = @(),
    [string[]] $ApprovedAgentIds = @(),
    [string] $ApprovedBy,
    [string] $ApprovalJustification,
    [switch] $DetailedOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runnerPath = Join-Path $PSScriptRoot 'run-agent-pipeline.ps1'
$params = [ordered]@{
    RepoRoot = $RepoRoot
    RequestText = $RequestText
    ExecutionBackend = 'codex-exec'
    DispatchCommand = $DispatchCommand
    ApprovedStageIds = @($ApprovedStageIds)
    ApprovedAgentIds = @($ApprovedAgentIds)
    ApprovedBy = $ApprovedBy
    ApprovalJustification = $ApprovalJustification
    DetailedOutput = [bool] $DetailedOutput
}

if ($PreviewOnly) {
    ([ordered]@{
            command = 'run-agent-pipeline'
            mode = 'parallel-dispatch'
            parameters = $params
            notes = @('Safe parallelism depends on task dependency graph and write-set isolation.')
        } | ConvertTo-Json -Depth 20)
    exit 0
}

& $runnerPath @params
exit $LASTEXITCODE