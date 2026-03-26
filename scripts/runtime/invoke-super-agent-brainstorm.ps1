<#
.SYNOPSIS
    Runs the Super Agent lifecycle through the brainstorm/spec stage only.

.DESCRIPTION
    Thin repository-owned entrypoint for starting a brainstorm/spec-only run
    through the standard orchestration pipeline.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected by the underlying runner when omitted.

.PARAMETER RequestText
    User request text to normalize and route through intake plus spec.

.PARAMETER ExecutionBackend
    `script-only` or `codex-exec`.

.PARAMETER DispatchCommand
    Codex CLI command name used for live dispatch.

.PARAMETER PreviewOnly
    Emits the pipeline invocation payload as JSON without executing it.

.PARAMETER DetailedOutput
    Enables verbose diagnostics.

.EXAMPLE
    pwsh -File .\scripts\runtime\invoke-super-agent-brainstorm.ps1 -RepoRoot . -RequestText "Design the workstream" -PreviewOnly

.NOTES
    Stops the pipeline after the `spec` stage.
#>

param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RequestText,
    [ValidateSet('script-only', 'codex-exec')] [string] $ExecutionBackend = 'codex-exec',
    [string] $DispatchCommand = 'codex',
    [switch] $PreviewOnly,
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
    StopAfterStageId = 'spec'
    DetailedOutput = [bool] $DetailedOutput
}

if ($PreviewOnly) {
    ([ordered]@{
            command = 'run-agent-pipeline'
            mode = 'brainstorm'
            parameters = $params
        } | ConvertTo-Json -Depth 20)
    exit 0
}

& $runnerPath @params
exit $LASTEXITCODE