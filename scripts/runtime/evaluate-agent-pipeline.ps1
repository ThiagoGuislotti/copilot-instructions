<#
.SYNOPSIS
    Evaluates repository-owned agent pipeline contracts against versioned fixtures.

.DESCRIPTION
    Loads the default orchestration pipeline, the agent manifest, and the
    versioned eval fixture file to produce a deterministic scorecard for
    contract-level pipeline expectations.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER EvalsPath
    Relative or absolute path to the versioned eval fixture document.

.PARAMETER OutputPath
    Relative or absolute output path for the generated eval scorecard JSON.

.PARAMETER DetailedOutput
    Shows detailed diagnostics for the evaluation session.

.EXAMPLE
    pwsh -File scripts/runtime/evaluate-agent-pipeline.ps1 -RepoRoot . -OutputPath .temp/agent-evals/pipeline-scorecard.json

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $EvalsPath = '.codex/orchestration/evals/golden-tests.json',
    [string] $OutputPath = '.temp/agent-evals/pipeline-scorecard.json',
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
    -Name 'evaluate-agent-pipeline' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Evals path' = $EvalsPath
            'Output path' = $OutputPath
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null
$resolvedEvalsPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $EvalsPath
$resolvedPipelinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.codex/orchestration/pipelines/default.pipeline.json'
$resolvedAgentsManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.codex/orchestration/agents.manifest.json'
$resolvedOutputPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $OutputPath

$evals = Read-HardeningJsonFile -Path $resolvedEvalsPath
$pipeline = Read-HardeningJsonFile -Path $resolvedPipelinePath
$agentsManifest = Read-HardeningJsonFile -Path $resolvedAgentsManifestPath
$pipelineStageOrder = @($pipeline.stages | ForEach-Object { [string] $_.id })
$agentIds = @($agentsManifest.agents | ForEach-Object { [string] $_.id })

$caseResults = New-Object System.Collections.Generic.List[object]
foreach ($case in @($evals.cases)) {
    $failures = New-Object System.Collections.Generic.List[string]
    if ([string] $case.expectedPipelineId -ne [string] $pipeline.id) {
        $failures.Add(("Expected pipeline {0}, got {1}" -f [string] $case.expectedPipelineId, [string] $pipeline.id)) | Out-Null
    }

    $expectedOrder = @($case.expectedStageOrder | ForEach-Object { [string] $_ })
    if (($expectedOrder -join ',') -ne ($pipelineStageOrder -join ',')) {
        $failures.Add('Expected stage order does not match pipeline manifest.') | Out-Null
    }

    foreach ($requiredAgent in @($case.requiredAgents | ForEach-Object { [string] $_ })) {
        if (-not ($agentIds -contains $requiredAgent)) {
            $failures.Add(("Required agent missing from manifest: {0}" -f $requiredAgent)) | Out-Null
        }
    }

    $caseResults.Add([ordered]@{
            id = [string] $case.id
            status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
            failures = @($failures.ToArray())
        }) | Out-Null
}

$scorecard = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    evalPath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedEvalsPath
    pipelineId = [string] $pipeline.id
    totalCases = $caseResults.Count
    passedCases = @($caseResults | Where-Object { $_.status -eq 'passed' }).Count
    failedCases = @($caseResults | Where-Object { $_.status -eq 'failed' }).Count
    cases = @($caseResults.ToArray())
}

Write-HardeningJsonFile -Path $resolvedOutputPath -Value $scorecard
Complete-ExecutionSession -Name 'evaluate-agent-pipeline' -Status $(if ($scorecard.failedCases -gt 0) { 'warning' } else { 'passed' }) -Summary ([ordered]@{
        'Total cases' = $scorecard.totalCases
        'Passed cases' = $scorecard.passedCases
        'Failed cases' = $scorecard.failedCases
    }) | Out-Null
$scorecard | ConvertTo-Json -Depth 50