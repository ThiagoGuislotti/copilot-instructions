<#
.SYNOPSIS
    Executes one implementation work item with optional task-level review loops.

.DESCRIPTION
    Dispatches an implementation work item through the configured specialist agent,
    then runs spec-compliance review and code-quality review for the same task.
    When reviewers request fixes, the worker re-dispatches the implementer with the
    accumulated review feedback until the task is approved or retry budget is exhausted.

.PARAMETER RepoRoot
    Repository root used to resolve contracts, prompts, and write-scope checks.

.PARAMETER WorkingDirectory
    Effective working directory for task execution.

.PARAMETER RunDirectory
    Run root where task-level artifacts are written.

.PARAMETER TraceId
    Current orchestration trace identifier.

.PARAMETER StageId
    Stage identifier owning this task execution.

.PARAMETER AgentId
    Specialist agent id selected for the task.

.PARAMETER TaskJsonPath
    Path to the worker-ready task payload.

.PARAMETER RequestPath
    Path to the normalized request artifact.

.PARAMETER ContextPackPath
    Path to the selected context pack artifact.

.PARAMETER RouteSelectionPath
    Path to the routing selection artifact.

.PARAMETER SpecialistContextPackPath
    Path to the specialist-specific context pack artifact.

.PARAMETER SpecSummaryPath
    Path to the current active spec summary artifact.

.PARAMETER AgentsManifestPath
    Path to the agent contract manifest.

.PARAMETER ImplementerPromptTemplatePath
    Prompt template for the specialist implementer dispatch.

.PARAMETER ImplementerResponseSchemaPath
    Response schema for the specialist implementer dispatch.

.PARAMETER SpecReviewPromptTemplatePath
    Prompt template for task-level spec compliance review.

.PARAMETER QualityReviewPromptTemplatePath
    Prompt template for task-level code-quality review.

.PARAMETER ReviewResponseSchemaPath
    Response schema shared by task review stages.

.PARAMETER ResultPath
    Output path for the final task execution result.

.PARAMETER DispatchCommand
    Codex CLI command name used for live dispatch.

.PARAMETER ExecutionBackend
    `script-only` or `codex-exec`.

.PARAMETER EffectiveModel
    Optional resolved model override for implementer and reviewer dispatches in this task loop.

.PARAMETER MaxIterations
    Maximum implement-review retry iterations for the task.

.PARAMETER DetailedOutput
    Enables verbose diagnostics.

.EXAMPLE
    pwsh -File .\scripts\orchestration\engine\invoke-task-worker.ps1 -RepoRoot . -WorkingDirectory . -RunDirectory .temp\runs\trace-001 -TraceId trace-001 -StageId implement -AgentId specialist -TaskJsonPath .temp\task.json -RequestPath .temp\request.txt -ContextPackPath .temp\context.json -RouteSelectionPath .temp\route.json -SpecialistContextPackPath .temp\specialist-context.json -SpecSummaryPath .temp\spec.json -AgentsManifestPath .codex\orchestration\agents.manifest.json -ImplementerPromptTemplatePath .codex\orchestration\prompts\executor-task.prompt.md -ImplementerResponseSchemaPath .github\schemas\agent.stage-implementation-result.schema.json -SpecReviewPromptTemplatePath .codex\orchestration\prompts\task-spec-review.prompt.md -QualityReviewPromptTemplatePath .codex\orchestration\prompts\task-quality-review.prompt.md -ReviewResponseSchemaPath .github\schemas\agent.task-review-result.schema.json -ResultPath .temp\task-result.json -ExecutionBackend script-only

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $WorkingDirectory,
    [Parameter(Mandatory = $true)] [string] $RunDirectory,
    [Parameter(Mandatory = $true)] [string] $TraceId,
    [Parameter(Mandatory = $true)] [string] $StageId,
    [Parameter(Mandatory = $true)] [string] $AgentId,
    [Parameter(Mandatory = $true)] [string] $TaskJsonPath,
    [Parameter(Mandatory = $true)] [string] $RequestPath,
    [Parameter(Mandatory = $true)] [string] $ContextPackPath,
    [Parameter(Mandatory = $true)] [string] $RouteSelectionPath,
    [Parameter(Mandatory = $true)] [string] $SpecialistContextPackPath,
    [Parameter(Mandatory = $true)] [string] $SpecSummaryPath,
    [Parameter(Mandatory = $true)] [string] $AgentsManifestPath,
    [Parameter(Mandatory = $true)] [string] $ImplementerPromptTemplatePath,
    [Parameter(Mandatory = $true)] [string] $ImplementerResponseSchemaPath,
    [Parameter(Mandatory = $true)] [string] $SpecReviewPromptTemplatePath,
    [Parameter(Mandatory = $true)] [string] $QualityReviewPromptTemplatePath,
    [Parameter(Mandatory = $true)] [string] $ReviewResponseSchemaPath,
    [Parameter(Mandatory = $true)] [string] $ResultPath,
    [string] $DispatchCommand = 'codex',
    [string] $ExecutionBackend = 'script-only',
    [string] $EffectiveModel,
    [int] $MaxIterations = 3,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths')
# Reads a JSON file and deserializes it with the orchestration depth required by worker artifacts.
function Read-JsonFile {
    param([string] $Path)
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Reads a property safely from PSCustomObject or hashtable values.
function Get-ObjectValue {
    param(
        [object] $Object,
        [string] $Name,
        [object] $DefaultValue = $null
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) {
        return $DefaultValue
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }

        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

# Persists JSON with deterministic UTF-8 output and no final newline.
function Write-JsonFile {
    param([string] $Path, [object] $Value)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value ($Value | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}

# Expands `{{TOKEN}}` placeholders inside prompt templates.
function Expand-Template {
    param([string] $TemplateText, [hashtable] $Tokens)
    $rendered = $TemplateText
    foreach ($key in $Tokens.Keys) {
        $rendered = $rendered.Replace(("{{{0}}}" -f $key), [string] $Tokens[$key])
    }
    return $rendered
}

# Retrieves the first matching agent contract from the manifest.
function Get-AgentContract {
    param([string] $ManifestPath, [string] $TargetAgentId)
    $manifest = Read-JsonFile -Path $ManifestPath
    return @($manifest.agents | Where-Object { $_.id -eq $TargetAgentId } | Select-Object -First 1)
}

# Converts repository path globs into regex patterns.
function Convert-GlobToRegex {
    param([string] $Pattern)
    $normalized = ($Pattern -replace '\\', '/')
    $escaped = [regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return ('^{0}$' -f $escaped)
}

# Verifies that a repository-relative path matches at least one allowed glob.
function Test-IsPathAllowed {
    param([string] $RelativePath, [string[]] $AllowedPatterns)
    foreach ($pattern in $AllowedPatterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        $regex = Convert-GlobToRegex -Pattern $pattern
        if ($RelativePath -match $regex) { return $true }
    }
    return $false
}

# Collects changed paths from git status limited to the task write scope.
function Get-ScopedWorkingTreePaths {
    param([string] $Root, [string[]] $PathSpecs)
    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $arguments = @('-C', $Root, 'status', '--porcelain')
    $usableSpecs = @($PathSpecs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($usableSpecs.Count -gt 0) {
        $arguments += '--'
        $arguments += $usableSpecs
    }
    $statusLines = @(git @arguments 2>$null)
    if ($LASTEXITCODE -ne 0) { return $set }
    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
        $pathText = $line.Substring(3).Trim()
        if ([string]::IsNullOrWhiteSpace($pathText)) { continue }
        if ($pathText.Contains('->')) {
            $pathText = $pathText.Split('->')[-1].Trim()
        }
        $set.Add(($pathText -replace '\\', '/')) | Out-Null
    }
    return $set
}

# Produces a deterministic fallback task result when live dispatch is unavailable.
function New-FallbackTaskResult {
    param([string] $TaskId)
    return [ordered]@{
        taskId = $TaskId
        status = 'completed'
        summary = 'Fallback execution mode produced orchestration artifacts without live Codex dispatch.'
        changedFiles = @()
        validationsPerformed = @('Defer concrete validation to the validate stage.')
        residualRisks = @('No live executor dispatch occurred in script-only mode.')
        notes = @('Use -ExecutionBackend codex-exec to enable live task execution.')
        commitReady = $false
    }
}

# Produces a deterministic fallback review result for spec or quality review.
function New-FallbackTaskReview {
    param(
        [string] $ReviewType,
        [object] $TaskResult
    )

    $taskStatus = [string] $TaskResult.status
    $decision = if ($taskStatus -eq 'completed') { 'approved' } else { 'blocked' }
    return [ordered]@{
        reviewType = $ReviewType
        decision = $decision
        summary = if ($decision -eq 'approved') { 'Fallback review approved the task because the task completed.' } else { 'Fallback review blocked the task because the task did not complete.' }
        findings = if ($decision -eq 'approved') { @() } else { @('Task execution did not complete cleanly.') }
        followUps = if ($decision -eq 'approved') { @() } else { @('Resolve the task execution failure before continuing.') }
    }
}

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedWorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
$resolvedTaskJsonPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $TaskJsonPath
$resolvedRequestPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $RequestPath
$resolvedContextPackPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ContextPackPath
$resolvedRouteSelectionPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $RouteSelectionPath
$resolvedSpecialistContextPackPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $SpecialistContextPackPath
$resolvedSpecSummaryPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $SpecSummaryPath
$resolvedAgentsManifestPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $AgentsManifestPath
$resolvedImplementerPromptTemplatePath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ImplementerPromptTemplatePath
$resolvedImplementerResponseSchemaPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ImplementerResponseSchemaPath
$resolvedSpecReviewPromptTemplatePath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $SpecReviewPromptTemplatePath
$resolvedQualityReviewPromptTemplatePath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $QualityReviewPromptTemplatePath
$resolvedReviewResponseSchemaPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ReviewResponseSchemaPath
$resolvedResultPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResultPath

$taskDirectory = Split-Path -Parent $resolvedResultPath
New-Item -ItemType Directory -Path $taskDirectory -Force | Out-Null

$task = Read-JsonFile -Path $resolvedTaskJsonPath
$requestText = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) { (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim() } else { 'No request content provided.' }
$contextPackJson = if (Test-Path -LiteralPath $resolvedContextPackPath -PathType Leaf) { Get-Content -Raw -LiteralPath $resolvedContextPackPath } else { '{}' }
$routeSelectionJson = if (Test-Path -LiteralPath $resolvedRouteSelectionPath -PathType Leaf) { Get-Content -Raw -LiteralPath $resolvedRouteSelectionPath } else { '{}' }
$specialistContextPackJson = if (Test-Path -LiteralPath $resolvedSpecialistContextPackPath -PathType Leaf) { Get-Content -Raw -LiteralPath $resolvedSpecialistContextPackPath } else { $contextPackJson }
$specSummaryJson = if (Test-Path -LiteralPath $resolvedSpecSummaryPath -PathType Leaf) { Get-Content -Raw -LiteralPath $resolvedSpecSummaryPath } else { '{}' }

$specialistAgent = Get-AgentContract -ManifestPath $resolvedAgentsManifestPath -TargetAgentId $AgentId
if ($null -eq $specialistAgent) {
    throw ("Agent contract not found for task worker: {0}" -f $AgentId)
}
$reviewerAgent = Get-AgentContract -ManifestPath $resolvedAgentsManifestPath -TargetAgentId 'reviewer'
if ($null -eq $reviewerAgent) {
    throw 'Reviewer agent contract not found for task worker.'
}

$taskAllowedPaths = @(Get-ObjectValue -Object $task -Name 'allowedPaths' -DefaultValue @() | ForEach-Object { [string] $_ })
$targetPaths = @(Get-ObjectValue -Object $task -Name 'targetPaths' -DefaultValue @() | ForEach-Object { [string] $_ })
if ($targetPaths.Count -eq 0) {
    $targetPaths = $taskAllowedPaths
}
$agentAllowedPaths = @($specialistAgent.allowedPaths | ForEach-Object { [string] $_ })
$taskPlanSummary = [string] (Get-ObjectValue -Object $task -Name 'description')
$shouldUseCodexDispatch = ($ExecutionBackend -eq 'codex-exec')
$dispatchScriptPath = Join-Path $resolvedRepoRoot 'scripts/orchestration/engine/invoke-codex-dispatch.ps1'
$implementerTemplateText = if ($shouldUseCodexDispatch) { Get-Content -Raw -LiteralPath $resolvedImplementerPromptTemplatePath } else { $null }
$specReviewTemplateText = if ($shouldUseCodexDispatch) { Get-Content -Raw -LiteralPath $resolvedSpecReviewPromptTemplatePath } else { $null }
$qualityReviewTemplateText = if ($shouldUseCodexDispatch) { Get-Content -Raw -LiteralPath $resolvedQualityReviewPromptTemplatePath } else { $null }

$attempt = 0
$feedbackLog = New-Object System.Collections.Generic.List[object]
$finalTaskResult = $null
$finalSpecReview = $null
$finalQualityReview = $null
$finalDispatchRecordRelativePath = $null
$taskWarnings = New-Object System.Collections.Generic.List[string]

while ($attempt -lt $MaxIterations) {
    $attempt++
    $feedbackJson = if ($feedbackLog.Count -gt 0) { ($feedbackLog | ConvertTo-Json -Depth 50) } else { '[]' }
    $taskResult = $null
    $dispatchRecordRelativePath = $null

    if ($shouldUseCodexDispatch) {
        try {
            $renderedPrompt = Expand-Template -TemplateText $implementerTemplateText -Tokens @{
                REQUEST_TEXT = $requestText
                TASK_PLAN_SUMMARY = $taskPlanSummary
                CONTEXT_PACK_JSON = $contextPackJson
                ROUTE_SELECTION_JSON = $routeSelectionJson
                SPECIALIST_CONTEXT_PACK_JSON = $specialistContextPackJson
                WORK_ITEM_JSON = ($task | ConvertTo-Json -Depth 50)
                COMBINED_ALLOWED_PATHS = (($taskAllowedPaths | ForEach-Object { '- ' + $_ }) -join [Environment]::NewLine)
                REVIEW_FEEDBACK_JSON = $feedbackJson
            }
            $dispatchPromptPath = Join-Path $taskDirectory ("executor-prompt-{0}.md" -f $attempt)
            $dispatchResultPath = Join-Path $taskDirectory ("executor-result-{0}.json" -f $attempt)
            $dispatchRecordPath = Join-Path $taskDirectory ("executor-dispatch-{0}.json" -f $attempt)
            Set-Content -LiteralPath $dispatchPromptPath -Value $renderedPrompt -Encoding UTF8 -NoNewline

            $beforeSet = Get-ScopedWorkingTreePaths -Root $resolvedRepoRoot -PathSpecs $targetPaths
            $implementerDispatchParams = @{
                RepoRoot = $resolvedRepoRoot
                WorkingDirectory = $resolvedWorkingDirectory
                TraceId = $TraceId
                StageId = $StageId
                AgentId = $AgentId
                PromptPath = $dispatchPromptPath
                ResponseSchemaPath = $resolvedImplementerResponseSchemaPath
                ResultPath = $dispatchResultPath
                DispatchRecordPath = $dispatchRecordPath
                CommandName = $DispatchCommand
                Model = if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $specialistAgent.model } else { $EffectiveModel }
                DetailedOutput = [bool] $DetailedOutput
            }
            & $dispatchScriptPath @implementerDispatchParams
            $taskResult = Read-JsonFile -Path $dispatchResultPath
            $afterSet = Get-ScopedWorkingTreePaths -Root $resolvedRepoRoot -PathSpecs $targetPaths
            $delta = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($pathAfter in $afterSet) {
                if (-not $beforeSet.Contains($pathAfter)) { $delta.Add($pathAfter) | Out-Null }
            }
            foreach ($reported in @($taskResult.changedFiles | ForEach-Object { [string] $_ -replace '\\', '/' })) {
                if (-not [string]::IsNullOrWhiteSpace($reported)) { $delta.Add($reported) | Out-Null }
            }
            foreach ($candidatePath in $delta) {
                if (-not (Test-IsPathAllowed -RelativePath $candidatePath -AllowedPatterns $agentAllowedPaths)) {
                    throw ("Task {0} changed path outside agent contract: {1}" -f ([string] (Get-ObjectValue -Object $task -Name 'id')), $candidatePath)
                }
                if (($taskAllowedPaths.Count -gt 0) -and (-not (Test-IsPathAllowed -RelativePath $candidatePath -AllowedPatterns $taskAllowedPaths))) {
                    throw ("Task {0} changed path outside task scope: {1}" -f ([string] (Get-ObjectValue -Object $task -Name 'id')), $candidatePath)
                }
            }
            $taskResult.changedFiles = @($delta)
            $dispatchRecordRelativePath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $dispatchRecordPath
        }
        catch {
            $taskWarnings.Add($_.Exception.Message) | Out-Null
            $taskResult = [pscustomobject](New-FallbackTaskResult -TaskId ([string] (Get-ObjectValue -Object $task -Name 'id')))
            $taskResult.status = 'blocked'
            $taskResult.notes += $_.Exception.Message
        }
    }
    else {
        $taskResult = [pscustomobject](New-FallbackTaskResult -TaskId ([string] (Get-ObjectValue -Object $task -Name 'id')))
    }

    if ($taskResult.status -ne 'completed' -or -not $shouldUseCodexDispatch) {
        $specReview = [pscustomobject](New-FallbackTaskReview -ReviewType 'spec-compliance' -TaskResult $taskResult)
    }
    else {
        try {
            $specPromptPath = Join-Path $taskDirectory ("spec-review-prompt-{0}.md" -f $attempt)
            $specResultPath = Join-Path $taskDirectory ("spec-review-result-{0}.json" -f $attempt)
            $specDispatchRecordPath = Join-Path $taskDirectory ("spec-review-dispatch-{0}.json" -f $attempt)
            $specPrompt = Expand-Template -TemplateText $specReviewTemplateText -Tokens @{
                REQUEST_TEXT = $requestText
                SPEC_SUMMARY_JSON = $specSummaryJson
                WORK_ITEM_JSON = ($task | ConvertTo-Json -Depth 50)
                TASK_RESULT_JSON = ($taskResult | ConvertTo-Json -Depth 50)
                REVIEW_FEEDBACK_JSON = $feedbackJson
            }
            Set-Content -LiteralPath $specPromptPath -Value $specPrompt -Encoding UTF8 -NoNewline
            $specReviewDispatchParams = @{
                RepoRoot = $resolvedRepoRoot
                WorkingDirectory = $resolvedWorkingDirectory
                TraceId = $TraceId
                StageId = ("{0}-spec-review" -f $StageId)
                AgentId = 'reviewer'
                PromptPath = $specPromptPath
                ResponseSchemaPath = $resolvedReviewResponseSchemaPath
                ResultPath = $specResultPath
                DispatchRecordPath = $specDispatchRecordPath
                CommandName = $DispatchCommand
                Model = if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $reviewerAgent.model } else { $EffectiveModel }
                DetailedOutput = [bool] $DetailedOutput
            }
            & $dispatchScriptPath @specReviewDispatchParams
            $specReview = Read-JsonFile -Path $specResultPath
            $specReview | Add-Member -NotePropertyName dispatchRecordPath -NotePropertyValue (Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $specDispatchRecordPath) -Force
        }
        catch {
            $taskWarnings.Add($_.Exception.Message) | Out-Null
            $specReview = [pscustomobject](New-FallbackTaskReview -ReviewType 'spec-compliance' -TaskResult $taskResult)
            $specReview.findings += $_.Exception.Message
        }
    }

    if ([string] $specReview.decision -ne 'approved') {
        $feedbackLog.Add([ordered]@{ reviewType = 'spec-compliance'; findings = @($specReview.findings); followUps = @($specReview.followUps) }) | Out-Null
        $finalTaskResult = $taskResult
        $finalSpecReview = $specReview
        $finalDispatchRecordRelativePath = $dispatchRecordRelativePath
        if ($attempt -ge $MaxIterations) { break }
        continue
    }

    if ($taskResult.status -ne 'completed' -or -not $shouldUseCodexDispatch) {
        $qualityReview = [pscustomobject](New-FallbackTaskReview -ReviewType 'code-quality' -TaskResult $taskResult)
    }
    else {
        try {
            $qualityPromptPath = Join-Path $taskDirectory ("quality-review-prompt-{0}.md" -f $attempt)
            $qualityResultPath = Join-Path $taskDirectory ("quality-review-result-{0}.json" -f $attempt)
            $qualityDispatchRecordPath = Join-Path $taskDirectory ("quality-review-dispatch-{0}.json" -f $attempt)
            $qualityPrompt = Expand-Template -TemplateText $qualityReviewTemplateText -Tokens @{
                REQUEST_TEXT = $requestText
                ROUTE_SELECTION_JSON = $routeSelectionJson
                WORK_ITEM_JSON = ($task | ConvertTo-Json -Depth 50)
                TASK_RESULT_JSON = ($taskResult | ConvertTo-Json -Depth 50)
                REVIEW_FEEDBACK_JSON = $feedbackJson
            }
            Set-Content -LiteralPath $qualityPromptPath -Value $qualityPrompt -Encoding UTF8 -NoNewline
            $qualityReviewDispatchParams = @{
                RepoRoot = $resolvedRepoRoot
                WorkingDirectory = $resolvedWorkingDirectory
                TraceId = $TraceId
                StageId = ("{0}-quality-review" -f $StageId)
                AgentId = 'reviewer'
                PromptPath = $qualityPromptPath
                ResponseSchemaPath = $resolvedReviewResponseSchemaPath
                ResultPath = $qualityResultPath
                DispatchRecordPath = $qualityDispatchRecordPath
                CommandName = $DispatchCommand
                Model = if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $reviewerAgent.model } else { $EffectiveModel }
                DetailedOutput = [bool] $DetailedOutput
            }
            & $dispatchScriptPath @qualityReviewDispatchParams
            $qualityReview = Read-JsonFile -Path $qualityResultPath
            $qualityReview | Add-Member -NotePropertyName dispatchRecordPath -NotePropertyValue (Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $qualityDispatchRecordPath) -Force
        }
        catch {
            $taskWarnings.Add($_.Exception.Message) | Out-Null
            $qualityReview = [pscustomobject](New-FallbackTaskReview -ReviewType 'code-quality' -TaskResult $taskResult)
            $qualityReview.findings += $_.Exception.Message
        }
    }

    $finalTaskResult = $taskResult
    $finalSpecReview = $specReview
    $finalQualityReview = $qualityReview
    $finalDispatchRecordRelativePath = $dispatchRecordRelativePath

    if ([string] $qualityReview.decision -eq 'approved') {
        break
    }

    $feedbackLog.Add([ordered]@{ reviewType = 'code-quality'; findings = @($qualityReview.findings); followUps = @($qualityReview.followUps) }) | Out-Null
    if ($attempt -ge $MaxIterations) {
        break
    }
}

if ($null -eq $finalTaskResult) {
    $finalTaskResult = [pscustomobject](New-FallbackTaskResult -TaskId ([string] (Get-ObjectValue -Object $task -Name 'id')))
    $finalTaskResult.status = 'blocked'
}
if ($null -eq $finalSpecReview) {
    $finalSpecReview = [pscustomobject](New-FallbackTaskReview -ReviewType 'spec-compliance' -TaskResult $finalTaskResult)
}
if ($null -eq $finalQualityReview) {
    $finalQualityReview = [pscustomobject](New-FallbackTaskReview -ReviewType 'code-quality' -TaskResult $finalTaskResult)
}

$finalStatus = if (([string] $finalTaskResult.status -eq 'completed') -and ([string] $finalSpecReview.decision -eq 'approved') -and ([string] $finalQualityReview.decision -eq 'approved')) { 'completed' } else { 'blocked' }
$finalCommitReady = ([bool] $finalTaskResult.commitReady) -and ($finalStatus -eq 'completed')

$result = [ordered]@{
    taskId = [string] (Get-ObjectValue -Object $task -Name 'id')
    title = [string] (Get-ObjectValue -Object $task -Name 'title')
    status = $finalStatus
    summary = [string] $finalTaskResult.summary
    changedFiles = @($finalTaskResult.changedFiles | ForEach-Object { [string] $_ })
    validationsPerformed = @($finalTaskResult.validationsPerformed | ForEach-Object { [string] $_ })
    residualRisks = @($finalTaskResult.residualRisks | ForEach-Object { [string] $_ })
    notes = @($finalTaskResult.notes | ForEach-Object { [string] $_ })
    commitReady = $finalCommitReady
    attemptCount = $attempt
    dispatchRecordPath = $finalDispatchRecordRelativePath
    specReview = $finalSpecReview
    qualityReview = $finalQualityReview
    reviewHistory = @($feedbackLog.ToArray())
    warnings = @($taskWarnings.ToArray())
}

Write-JsonFile -Path $resolvedResultPath -Value $result
if ($finalStatus -ne 'completed') { exit 1 }
exit 0