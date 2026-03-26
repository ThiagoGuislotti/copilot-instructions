<#
.SYNOPSIS
    Runs the full Super Agent lifecycle.

.DESCRIPTION
    Thin repository-owned entrypoint for the full intake-to-closeout execution
    flow backed by the standard orchestration pipeline.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected by the underlying runner when omitted.

.PARAMETER RequestText
    User request text to execute.

.PARAMETER ExecutionBackend
    `script-only` or `codex-exec`.

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
    pwsh -File .\scripts\runtime\invoke-super-agent-execute.ps1 -RepoRoot . -RequestText "Implement the planned work" -PreviewOnly

.NOTES
    Executes the full Super Agent lifecycle without truncation.
#>

param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RequestText,
    [ValidateSet('script-only', 'codex-exec')] [string] $ExecutionBackend = 'codex-exec',
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
    ExecutionBackend = $ExecutionBackend
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
            mode = 'execute'
            parameters = $params
        } | ConvertTo-Json -Depth 20)
    exit 0
}

& $runnerPath @params
exit $LASTEXITCODE