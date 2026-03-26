<#
.SYNOPSIS
    Dispatches a stage prompt to the local Codex CLI and captures structured output.

.DESCRIPTION
    Executes `codex exec` with a rendered prompt, JSON schema constrained output,
    and deterministic run metadata for orchestration stages.

.PARAMETER RepoRoot
    Repository root path.

.PARAMETER WorkingDirectory
    Working directory for the Codex CLI. Defaults to RepoRoot.

.PARAMETER TraceId
    Current orchestration trace id.

.PARAMETER StageId
    Current stage id.

.PARAMETER AgentId
    Current agent id.

.PARAMETER PromptPath
    Path to the rendered prompt text file.

.PARAMETER ResponseSchemaPath
    Path to the JSON schema used for the final message.

.PARAMETER ResultPath
    Path where the structured final response should be written.

.PARAMETER DispatchRecordPath
    Path where the dispatch metadata record should be written.

.PARAMETER CommandName
    Codex CLI command name or absolute path.

.PARAMETER Model
    Agent model string.

.PARAMETER SandboxMode
    Sandbox mode passed to Codex CLI.

.PARAMETER ApprovalPolicy
    Approval policy passed to Codex CLI.

.PARAMETER DetailedOutput
    Enables verbose diagnostics.

.EXAMPLE
    pwsh -File .\scripts\orchestration\engine\invoke-codex-dispatch.ps1 -RepoRoot . -WorkingDirectory . -TraceId trace-001 -StageId plan -AgentId planner -PromptPath .temp\planner.md -ResponseSchemaPath .github\schemas\agent.stage-plan-result.schema.json -ResultPath .temp\planner-result.json -DispatchRecordPath .temp\planner-dispatch.json

.NOTES
    Uses the local Codex CLI as the execution backend for live sequential orchestration stages.
#>

param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [string] $WorkingDirectory,
    [Parameter(Mandatory = $true)] [string] $TraceId,
    [Parameter(Mandatory = $true)] [string] $StageId,
    [Parameter(Mandatory = $true)] [string] $AgentId,
    [Parameter(Mandatory = $true)] [string] $PromptPath,
    [Parameter(Mandatory = $true)] [string] $ResponseSchemaPath,
    [Parameter(Mandatory = $true)] [string] $ResultPath,
    [Parameter(Mandatory = $true)] [string] $DispatchRecordPath,
    [string] $CommandName = 'codex',
    [string] $Model = 'gpt-5',
    [string] $SandboxMode = 'workspace-write',
    [string] $ApprovalPolicy = 'never',
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:IsVerboseEnabled = [bool] $DetailedOutput
$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedWorkingDirectory = if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) { $resolvedRepoRoot } else { Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $WorkingDirectory }
$resolvedPromptPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $PromptPath
$resolvedResponseSchemaPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResponseSchemaPath
$resolvedResultPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResultPath
$resolvedDispatchRecordPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $DispatchRecordPath

$command = Get-Command -Name $CommandName -ErrorAction Stop

$directories = @(
    (Split-Path -Parent $resolvedResultPath),
    (Split-Path -Parent $resolvedDispatchRecordPath)
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
foreach ($directory in $directories) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $resolvedPromptPath -PathType Leaf)) {
    throw "Prompt file not found: $resolvedPromptPath"
}

if (-not (Test-Path -LiteralPath $resolvedResponseSchemaPath -PathType Leaf)) {
    throw "Response schema not found: $resolvedResponseSchemaPath"
}

$promptText = Get-Content -Raw -LiteralPath $resolvedPromptPath
$startedAt = Get-Date
$logPath = [System.IO.Path]::ChangeExtension($resolvedDispatchRecordPath, '.log')
$arguments = @(
    'exec',
    '-C', $resolvedWorkingDirectory,
    '-s', $SandboxMode,
    '-a', $ApprovalPolicy,
    '-m', $Model,
    '--color', 'never',
    '--output-schema', $resolvedResponseSchemaPath,
    '-o', $resolvedResultPath,
    '-'
)

Write-VerboseLog ("Dispatching stage {0} agent {1} with command '{2}'" -f $StageId, $AgentId, $command.Source)

$processFileName = $command.Source
$processArguments = @($arguments)
if ($processFileName.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
    $siblingCommandPath = [System.IO.Path]::ChangeExtension($processFileName, '.cmd')
    $siblingExecutablePath = [System.IO.Path]::ChangeExtension($processFileName, '.exe')
    if (Test-Path -LiteralPath $siblingCommandPath -PathType Leaf) {
        $processFileName = $siblingCommandPath
    }
    elseif (Test-Path -LiteralPath $siblingExecutablePath -PathType Leaf) {
        $processFileName = $siblingExecutablePath
    }
    else {
        $processFileName = (Get-Process -Id $PID).Path
        $processArguments = @('-NoProfile', '-File', $command.Source) + $arguments
    }
}

$commandOutput = @()
$exitCode = 1
$dispatchError = $null

try {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $processFileName
    $startInfo.WorkingDirectory = $resolvedWorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    foreach ($argument in $processArguments) {
        $startInfo.ArgumentList.Add([string] $argument) | Out-Null
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $process.Start() | Out-Null
    $process.StandardInput.Write($promptText)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $exitCode = [int] $process.ExitCode
    $commandOutput = @()
    foreach ($outputChunk in @($stdout, $stderr)) {
        if (-not [string]::IsNullOrWhiteSpace($outputChunk)) {
            $commandOutput += $outputChunk
        }
    }
}
catch {
    $dispatchError = $_.Exception.Message
    $exitCode = 1
}

$finishedAt = Get-Date
$durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
$commandOutputText = ($commandOutput | ForEach-Object { [string] $_ }) -join [Environment]::NewLine
Set-Content -LiteralPath $logPath -Value $commandOutputText -Encoding UTF8 -NoNewline

$record = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    model = $Model
    sandboxMode = $SandboxMode
    approvalPolicy = $ApprovalPolicy
    command = $processFileName
    arguments = $processArguments
    promptPath = $resolvedPromptPath
    responseSchemaPath = $resolvedResponseSchemaPath
    resultPath = $resolvedResultPath
    logPath = $logPath
    startedAt = $startedAt.ToString('o')
    finishedAt = $finishedAt.ToString('o')
    durationMs = $durationMs
    exitCode = $exitCode
    error = $dispatchError
}
Set-Content -LiteralPath $resolvedDispatchRecordPath -Value ($record | ConvertTo-Json -Depth 40) -Encoding UTF8 -NoNewline

if ($exitCode -ne 0) {
    if (-not [string]::IsNullOrWhiteSpace($dispatchError)) {
        throw "Codex dispatch failed: $dispatchError"
    }

    $failureDetail = if ([string]::IsNullOrWhiteSpace($commandOutputText)) { '' } else { " Output: $commandOutputText" }
    throw "Codex dispatch failed with exit code $exitCode. See log: $logPath.$failureDetail"
}

if (-not (Test-Path -LiteralPath $resolvedResultPath -PathType Leaf)) {
    throw "Codex dispatch did not produce result file: $resolvedResultPath"
}

try {
    Get-Content -Raw -LiteralPath $resolvedResultPath | ConvertFrom-Json -Depth 200 | Out-Null
}
catch {
    throw "Codex dispatch produced invalid JSON result: $resolvedResultPath"
}

exit 0