<#
.SYNOPSIS
    Executes the multi-agent orchestration pipeline with runtime guardrail enforcement.

.DESCRIPTION
    Runs stages defined in `.codex/orchestration/pipelines/default.pipeline.json` using
    agent contracts in `.codex/orchestration/agents.manifest.json`.

    Features:
    - deterministic stage execution and handoff artifacts
    - retry handling via stage `onFailure`
    - guardrail enforcement for:
      - blocked command patterns
      - allowed path mutations
      - maxSteps / maxDurationMinutes / maxFileEdits budgets
    - run artifact generation under `.temp/runs/<traceId>/run-artifact.json`

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER AgentsManifestPath
    Relative path to agent contract manifest.

.PARAMETER PipelinePath
    Relative path to orchestration pipeline manifest.

.PARAMETER RunRoot
    Root directory where run artifacts are generated.

.PARAMETER TraceId
    Optional trace id. Defaults to `run-<yyyyMMdd-HHmmss>`.

.PARAMETER RequestText
    User request text used as initial `request` artifact.

.PARAMETER SkipGuardrails
    Disables blocked command, allowed path, and budget enforcement.

.PARAMETER WarningOnly
    When true (default), pipeline failures are reported as warnings and exit code remains zero.

.PARAMETER RetryDelaySeconds
    Delay between retry attempts for retryable stages. Default 2 seconds.

.PARAMETER MaxPipelineDurationSeconds
    Optional max total pipeline duration. When 0, uses pipeline/agent defaults.

.PARAMETER ContinueOnStageFailure
    When true (default), continue executing subsequent stages after non-successful stage.

.PARAMETER ExecutionBackend
    Pipeline execution backend. Choose between `script-only` and `codex-exec`.

.PARAMETER DispatchCommand
    Command used to invoke delegated Codex execution when the backend requires it.

.PARAMETER StopAfterStageId
    Optional stage id that truncates the pipeline after the selected stage.

.PARAMETER StartAtStageId
    Optional stage id that skips earlier stages and begins execution at the selected stage.

.PARAMETER ResumeFromRunDirectory
    Optional prior run directory used to preload checkpoint, trace, and policy artifacts before resuming execution.

.PARAMETER PolicyCatalogPath
    Optional override path to the runtime policy catalog.

.PARAMETER ModelRoutingCatalogPath
    Optional override path to the model routing catalog.

.PARAMETER ApprovedStageIds
    Optional list of stage ids explicitly approved for sensitive execution.

.PARAMETER ApprovedAgentIds
    Optional list of agent ids explicitly approved for sensitive execution.

.PARAMETER ApprovedBy
    Required when approval ids are supplied. Identifies who approved the run.

.PARAMETER ApprovalJustification
    Required when approval ids are supplied. Explains why the sensitive execution was approved.

.PARAMETER WriteRunState
    When true (default), writes per-stage and consolidated run-state artifacts.

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate agent flow"

.EXAMPLE
    pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Validate orchestration only" -SkipGuardrails

.EXAMPLE
    pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Run resilient warning-only flow" -WarningOnly:$true -RetryDelaySeconds 3

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git CLI.
#>

param(
    [string] $RepoRoot,
    [string] $AgentsManifestPath = '.codex/orchestration/agents.manifest.json',
    [string] $PipelinePath = '.codex/orchestration/pipelines/default.pipeline.json',
    [string] $RunRoot = '.temp/runs',
    [string] $TraceId,
    [Parameter(Mandatory = $true)] [string] $RequestText,
    [switch] $SkipGuardrails,
    [bool] $WarningOnly = $true,
    [int] $RetryDelaySeconds = 2,
    [int] $MaxPipelineDurationSeconds = 0,
    [bool] $ContinueOnStageFailure = $true,
    [ValidateSet('script-only', 'codex-exec')] [string] $ExecutionBackend,
    [string] $DispatchCommand = 'codex',
    [string] $StopAfterStageId,
    [string] $StartAtStageId,
    [string] $ResumeFromRunDirectory,
    [string] $PolicyCatalogPath,
    [string] $ModelRoutingCatalogPath,
    [string[]] $ApprovedStageIds = @(),
    [string[]] $ApprovedAgentIds = @(),
    [string] $ApprovedBy,
    [string] $ApprovalJustification,
    [bool] $WriteRunState = $true,
    [switch] $DetailedOutput
)

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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'agent-runtime-hardening')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $DetailedOutput
# Reads and parses JSON from path.
function Read-JsonFile {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file not found: $Path"
    }

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Writes JSON content without trailing newline for deterministic artifacts.
function Write-JsonFile {
    param(
        [string] $Path,
        [object] $Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value ($Value | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}

# Returns optional object property value with fallback default.
function Get-OptionalPropertyValue {
    param(
        [object] $Object,
        [string] $PropertyName,
        [object] $DefaultValue = $null
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($PropertyName)) {
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

# Converts path to repository-relative format using forward slashes.
function Convert-ToRepoRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    $relative = [System.IO.Path]::GetRelativePath($Root, $Path)
    return ($relative -replace '\\', '/')
}

# Converts glob-like pattern to regex for allowed path checks.
function Convert-GlobToRegex {
    param(
        [string] $Pattern
    )

    $normalized = ($Pattern -replace '\\', '/')
    $escaped = [regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return ('^{0}$' -f $escaped)
}

# Checks if relative path matches at least one allowed pattern.
function Test-IsPathAllowed {
    param(
        [string] $RelativePath,
        [string[]] $AllowedPatterns
    )

    foreach ($pattern in $AllowedPatterns) {
        $regex = Convert-GlobToRegex -Pattern $pattern
        if ($RelativePath -match $regex) {
            return $true
        }
    }

    return $false
}

# Checks if a command text matches blocked command prefixes.
function Test-IsBlockedCommand {
    param(
        [string] $CommandText,
        [string[]] $BlockedCommands
    )

    $normalized = ($CommandText ?? '').Trim().ToLowerInvariant()
    foreach ($blocked in $BlockedCommands) {
        $blockedText = ($blocked ?? '').Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($blockedText)) {
            continue
        }

        if ($normalized.StartsWith($blockedText, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

# Gets changed/untracked file set from git porcelain output.
function Get-WorkingTreePathSet {
    param(
        [string] $Root
    )

    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    $statusLines = @(git -C "$Root" status --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return $set
    }

    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line.Length -lt 4) {
            continue
        }

        $pathText = $line.Substring(3).Trim()
        if ([string]::IsNullOrWhiteSpace($pathText)) {
            continue
        }

        if ($pathText.Contains('->')) {
            $pathText = $pathText.Split('->')[-1].Trim()
        }

        $normalized = ($pathText -replace '\\', '/')
        $set.Add($normalized) | Out-Null
    }

    return $set
}

# Creates artifact descriptor with checksum.
function Get-ArtifactDescriptor {
    param(
        [string] $Name,
        [string] $AbsolutePath,
        [string] $Root
    )

    $hash = Get-FileHash -LiteralPath $AbsolutePath -Algorithm SHA256
    return [ordered]@{
        name = $Name
        path = Convert-ToRepoRelativePath -Root $Root -Path $AbsolutePath
        checksum = ("sha256:{0}" -f $hash.Hash.ToLowerInvariant())
    }
}

# Converts string input into a case-insensitive set.
function Convert-ToStringSet {
    param(
        [string[]] $Values
    )

    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in @($Values)) {
        $text = [string] $value
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        $set.Add($text.Trim()) | Out-Null
    }

    return ,$set
}

# Evaluates whether the current stage satisfies its approval requirement.
function Get-StageApprovalEvaluation {
    param(
        [string] $StageId,
        [string] $AgentId,
        [object] $Agent,
        [bool] $DefaultApprovalRequired,
        [System.Collections.Generic.HashSet[string]] $ApprovedStageSet,
        [System.Collections.Generic.HashSet[string]] $ApprovedAgentSet
    )

    $approvalRequired = [bool] (Get-OptionalPropertyValue -Object $Agent -PropertyName 'approvalRequired' -DefaultValue $DefaultApprovalRequired)
    $approvalInstructions = [string] (Get-OptionalPropertyValue -Object $Agent -PropertyName 'approvalInstructions' -DefaultValue '')
    $stageApproved = $ApprovedStageSet.Contains($StageId)
    $agentApproved = $ApprovedAgentSet.Contains($AgentId)
    $approvalSatisfied = (-not $approvalRequired) -or $stageApproved -or $agentApproved
    $approvalSource = $null
    if ($stageApproved) {
        $approvalSource = 'stage'
    }
    elseif ($agentApproved) {
        $approvalSource = 'agent'
    }

    return [pscustomobject]@{
        required = $approvalRequired
        satisfied = $approvalSatisfied
        source = $approvalSource
        instructions = $approvalInstructions
    }
}

# Converts artifact manifest object to dictionary (name -> absolute path).
function Convert-ManifestToArtifactMap {
    param(
        [object] $Manifest,
        [string] $Root
    )

    $map = @{}
    foreach ($artifact in @($Manifest.artifacts)) {
        $name = [string] $artifact.name
        $path = [string] $artifact.path
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $map[$name] = Resolve-RepoPath -Root $Root -Path $path
    }

    return $map
}

# Returns clarification metadata from the intake-report artifact when present.
function Get-IntakeClarificationDetails {
    param(
        [string] $StageId,
        [hashtable] $ArtifactMap
    )

    if ([string] $StageId -ne 'intake') {
        return [pscustomobject]@{
            clarificationRequired = $false
            canProceedSafely = $true
            clarificationReason = $null
            clarificationQuestions = @()
        }
    }

    if (-not $ArtifactMap.ContainsKey('intake-report')) {
        return [pscustomobject]@{
            clarificationRequired = $false
            canProceedSafely = $true
            clarificationReason = $null
            clarificationQuestions = @()
        }
    }

    $intakeReportPath = [string] $ArtifactMap['intake-report']
    if (-not (Test-Path -LiteralPath $intakeReportPath -PathType Leaf)) {
        return [pscustomobject]@{
            clarificationRequired = $false
            canProceedSafely = $true
            clarificationReason = $null
            clarificationQuestions = @()
        }
    }

    $intakeReport = Read-JsonFile -Path $intakeReportPath
    $clarificationRequired = [bool] (Get-OptionalPropertyValue -Object $intakeReport -PropertyName 'clarificationRequired' -DefaultValue $false)
    $canProceedSafely = [bool] (Get-OptionalPropertyValue -Object $intakeReport -PropertyName 'canProceedSafely' -DefaultValue (-not $clarificationRequired))
    $clarificationReason = [string] (Get-OptionalPropertyValue -Object $intakeReport -PropertyName 'clarificationReason' -DefaultValue '')
    $clarificationQuestions = @((Get-OptionalPropertyValue -Object $intakeReport -PropertyName 'clarificationQuestions' -DefaultValue @()) | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    return [pscustomobject]@{
        clarificationRequired = $clarificationRequired
        canProceedSafely = $canProceedSafely
        clarificationReason = if ([string]::IsNullOrWhiteSpace($clarificationReason)) { $null } else { $clarificationReason }
        clarificationQuestions = $clarificationQuestions
    }
}

# Writes handoff artifact file for a stage transition.
function Write-HandoffArtifact {
    param(
        [string] $Root,
        [string] $TraceIdValue,
        [string] $PipelineId,
        [string] $FromStage,
        [string] $ToStage,
        [string[]] $RequiredArtifacts,
        [hashtable] $ArtifactMap,
        [string] $HandoffsDirectory
    )

    New-Item -ItemType Directory -Path $HandoffsDirectory -Force | Out-Null
    $handoffPath = Join-Path $HandoffsDirectory ("{0}-to-{1}.json" -f $FromStage, $ToStage)

    $artifactDescriptors = @()
    foreach ($artifactName in $RequiredArtifacts) {
        if ($ArtifactMap.ContainsKey($artifactName)) {
            $absolutePath = [string] $ArtifactMap[$artifactName]
            if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
                $artifactDescriptors += (Get-ArtifactDescriptor -Name $artifactName -AbsolutePath $absolutePath -Root $Root)
            }
        }
    }

    $handoff = [ordered]@{
        traceId = $TraceIdValue
        pipelineId = $PipelineId
        fromStage = $FromStage
        toStage = $ToStage
        producedAt = (Get-Date).ToString('o')
        summary = ("Handoff from {0} to {1} with required artifacts." -f $FromStage, $ToStage)
        artifacts = $artifactDescriptors
        risks = @()
        openQuestions = @()
    }

    Set-Content -LiteralPath $handoffPath -Value ($handoff | ConvertTo-Json -Depth 60) -Encoding UTF8 -NoNewline
}

# Writes deterministic run-state metadata for orchestration resume and observability.
function Write-RunStateArtifact {
    param(
        [string] $Path,
        [string] $TraceIdValue,
        [string] $PipelineId,
        [string] $Status,
        [string] $CurrentStageId,
        [datetime] $StartedAt,
        [System.Collections.Generic.List[object]] $StageResults,
        [System.Collections.Generic.List[string]] $Warnings,
        [System.Collections.Generic.List[string]] $Failures,
        [hashtable] $ArtifactMap,
        [hashtable] $AgentUsage,
        [string] $Root
    )

    $artifactEntries = @()
    foreach ($entry in $ArtifactMap.GetEnumerator()) {
        $artifactPath = [string] $entry.Value
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
            continue
        }

        $artifactEntries += [ordered]@{
            name = [string] $entry.Key
            path = Convert-ToRepoRelativePath -Root $Root -Path $artifactPath
        }
    }

    $usageEntries = @()
    foreach ($agentId in ($AgentUsage.Keys | Sort-Object)) {
        $usage = $AgentUsage[$agentId]
        $usageEntries += [ordered]@{
            agentId = $agentId
            steps = [int] $usage.steps
            durationMs = [int] $usage.durationMs
            fileEdits = [int] $usage.fileEdits
            tokenUsage = [int] $usage.tokenUsage
        }
    }

    $state = [ordered]@{
        traceId = $TraceIdValue
        pipelineId = $PipelineId
        status = $Status
        currentStageId = $CurrentStageId
        startedAt = $StartedAt.ToString('o')
        updatedAt = (Get-Date).ToString('o')
        stages = @($StageResults)
        warnings = @($Warnings)
        failures = @($Failures)
        artifacts = $artifactEntries
        agentUsage = $usageEntries
    }

    Write-JsonFile -Path $Path -Value $state
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot
Start-ExecutionSession `
    -Name 'run-agent-pipeline' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Execution backend' = $(if ([string]::IsNullOrWhiteSpace($ExecutionBackend)) { 'default' } else { $ExecutionBackend })
            'Warning-only mode' = [bool] $WarningOnly
            'Start stage' = $(if ([string]::IsNullOrWhiteSpace($StartAtStageId)) { 'pipeline-start' } else { $StartAtStageId })
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

$validationScriptPath = Join-Path $resolvedRepoRoot 'scripts/validation/validate-agent-orchestration.ps1'
if (-not (Test-Path -LiteralPath $validationScriptPath -PathType Leaf)) {
    throw "Required validator not found: $validationScriptPath"
}

& $validationScriptPath -RepoRoot $resolvedRepoRoot
if ($LASTEXITCODE -ne 0) {
    if ($WarningOnly) {
        Write-StyledOutput '[WARN] Agent orchestration validation failed. Continuing due warning-only mode.'
    }
    else {
        throw 'Agent orchestration validation failed. Fix contracts before running pipeline.'
    }
}

$resolvedAgentsManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AgentsManifestPath
$resolvedPipelinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $PipelinePath
$resolvedRunRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $RunRoot

$agentsManifest = Read-JsonFile -Path $resolvedAgentsManifestPath
$pipeline = Read-JsonFile -Path $resolvedPipelinePath
$pipelineStages = @($pipeline.stages)

$defaultsConfig = Get-OptionalPropertyValue -Object $agentsManifest -PropertyName 'defaults'
$defaultTimeoutValue = Get-OptionalPropertyValue -Object $defaultsConfig -PropertyName 'timeoutMinutes' -DefaultValue 30
$defaultTimeoutMinutes = [int] $defaultTimeoutValue
$defaultApprovalRequired = [bool] (Get-OptionalPropertyValue -Object $defaultsConfig -PropertyName 'approvalRequired' -DefaultValue $false)

$runtimeConfig = Get-OptionalPropertyValue -Object $pipeline -PropertyName 'runtime'
$runtimeExecutionBackendValue = Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'executionBackend'
$runtimeRetryDelayValue = Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'defaultRetryDelaySeconds'
$runtimeMaxDurationValue = Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'maxPipelineDurationSeconds'
$runtimeContinueOnFailureValue = Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'continueOnStageFailure'
$runtimeWriteRunStateValue = Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'writeRunState'
$runtimePolicyCatalogPathValue = [string] (Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'policyCatalogPath' -DefaultValue '')
$runtimeModelRoutingCatalogPathValue = [string] (Get-OptionalPropertyValue -Object $runtimeConfig -PropertyName 'modelRoutingCatalogPath' -DefaultValue '')

$effectiveRetryDelaySeconds = if ($RetryDelaySeconds -gt 0) {
    $RetryDelaySeconds
}
elseif ($null -ne $runtimeRetryDelayValue) {
    [int] $runtimeRetryDelayValue
}
else {
    2
}

$effectiveMaxPipelineDurationSeconds = if ($MaxPipelineDurationSeconds -gt 0) {
    $MaxPipelineDurationSeconds
}
elseif ($null -ne $runtimeMaxDurationValue -and [int] $runtimeMaxDurationValue -gt 0) {
    [int] $runtimeMaxDurationValue
}
else {
    $defaultTimeoutMinutes * 60
}

$effectiveContinueOnStageFailure = if ($null -ne $runtimeContinueOnFailureValue) {
    [bool] $runtimeContinueOnFailureValue
}
else {
    [bool] $ContinueOnStageFailure
}

$effectiveExecutionBackend = if (-not [string]::IsNullOrWhiteSpace($ExecutionBackend)) {
    $ExecutionBackend
}
elseif (-not [string]::IsNullOrWhiteSpace([string] $runtimeExecutionBackendValue)) {
    [string] $runtimeExecutionBackendValue
}
else {
    'script-only'
}

$effectiveWriteRunState = if ($null -ne $runtimeWriteRunStateValue) {
    [bool] $runtimeWriteRunStateValue
}
else {
    [bool] $WriteRunState
}

$startStageIndex = 0
if (-not [string]::IsNullOrWhiteSpace($StartAtStageId)) {
    $matchedStartIndex = -1
    for ($index = 0; $index -lt $pipelineStages.Count; $index++) {
        if ([string] $pipelineStages[$index].id -eq $StartAtStageId) {
            $matchedStartIndex = $index
            break
        }
    }

    if ($matchedStartIndex -lt 0) {
        throw ("Unknown StartAtStageId: {0}" -f $StartAtStageId)
    }

    $startStageIndex = $matchedStartIndex
}

$stopStageIndex = $pipelineStages.Count - 1
if (-not [string]::IsNullOrWhiteSpace($StopAfterStageId)) {
    $matchedStopIndex = -1
    for ($index = 0; $index -lt $pipelineStages.Count; $index++) {
        if ([string] $pipelineStages[$index].id -eq $StopAfterStageId) {
            $matchedStopIndex = $index
            break
        }
    }

    if ($matchedStopIndex -lt 0) {
        throw ("Unknown StopAfterStageId: {0}" -f $StopAfterStageId)
    }

    $stopStageIndex = $matchedStopIndex
}

if ($startStageIndex -gt $stopStageIndex) {
    throw ("StartAtStageId '{0}' occurs after StopAfterStageId '{1}'." -f $StartAtStageId, $StopAfterStageId)
}

$selectedStages = @($pipelineStages[$startStageIndex..$stopStageIndex])

$selectedStageIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($selectedStage in $selectedStages) {
    $selectedStageIds.Add([string] $selectedStage.id) | Out-Null
}

$completionRequiredStages = if ([string]::IsNullOrWhiteSpace($StopAfterStageId)) {
    @($pipeline.completionCriteria.requiredStages)
}
else {
    @($selectedStages | ForEach-Object { [string] $_.id })
}

$completionRequiredArtifacts = if ([string]::IsNullOrWhiteSpace($StopAfterStageId)) {
    @($pipeline.completionCriteria.requiredArtifacts)
}
else {
    @($selectedStages[-1].outputArtifacts | ForEach-Object { [string] $_ })
}

$trace = if ([string]::IsNullOrWhiteSpace($TraceId)) {
    "run-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
}
else {
    $TraceId
}

$resumeRunDirectory = if ([string]::IsNullOrWhiteSpace($ResumeFromRunDirectory)) {
    $null
}
else {
    Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResumeFromRunDirectory
}

$runDirectory = if ($null -ne $resumeRunDirectory) {
    $resumeRunDirectory
}
else {
    Join-Path $resolvedRunRoot $trace
}
$artifactsDirectory = Join-Path $runDirectory 'artifacts'
$stagesDirectory = Join-Path $runDirectory 'stages'
$handoffsDirectory = Join-Path $runDirectory 'handoffs'
$runStatePath = Join-Path $runDirectory 'run-state.json'
$approvalRecordPath = Join-Path $artifactsDirectory 'approval-record.json'
$traceRecordPath = Join-Path $runDirectory 'trace-record.json'
$policyEvaluationsPath = Join-Path $runDirectory 'policy-evaluations.json'
$checkpointStatePath = Join-Path $runDirectory 'checkpoint-state.json'

New-Item -ItemType Directory -Path $artifactsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $stagesDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $handoffsDirectory -Force | Out-Null

$requestPath = Join-Path $artifactsDirectory 'request.md'
Set-Content -LiteralPath $requestPath -Value $RequestText -Encoding UTF8 -NoNewline

$agentMap = @{}
foreach ($agent in @($agentsManifest.agents)) {
    $agentMap[[string] $agent.id] = $agent
}

$artifactMap = @{}
$artifactMap['request'] = $requestPath
$effectivePolicyCatalogPath = if (-not [string]::IsNullOrWhiteSpace($PolicyCatalogPath)) { $PolicyCatalogPath } else { $runtimePolicyCatalogPathValue }
$effectiveModelRoutingCatalogPath = if (-not [string]::IsNullOrWhiteSpace($ModelRoutingCatalogPath)) { $ModelRoutingCatalogPath } else { $runtimeModelRoutingCatalogPathValue }
$policyCatalogInfo = Get-AgentRuntimePolicyCatalog -Root $resolvedRepoRoot -CatalogPath $effectivePolicyCatalogPath
$modelRoutingCatalogInfo = Get-AgentModelRoutingCatalog -Root $resolvedRepoRoot -CatalogPath $effectiveModelRoutingCatalogPath
$approvedStageSet = Convert-ToStringSet -Values $ApprovedStageIds
$approvedAgentSet = Convert-ToStringSet -Values $ApprovedAgentIds
$approvalEntries = New-Object System.Collections.Generic.List[object]
$policyEvaluationEntries = New-Object System.Collections.Generic.List[object]

if (($approvedStageSet.Count -gt 0 -or $approvedAgentSet.Count -gt 0) -and [string]::IsNullOrWhiteSpace($ApprovedBy)) {
    throw 'ApprovedBy is required when ApprovedStageIds or ApprovedAgentIds are supplied.'
}

if (($approvedStageSet.Count -gt 0 -or $approvedAgentSet.Count -gt 0) -and [string]::IsNullOrWhiteSpace($ApprovalJustification)) {
    throw 'ApprovalJustification is required when ApprovedStageIds or ApprovedAgentIds are supplied.'
}

$approvalRecordedAt = (Get-Date).ToString('o')
foreach ($approvedStageId in $approvedStageSet) {
    $approvalEntries.Add([pscustomobject]([ordered]@{
                scope = 'stage'
                targetId = $approvedStageId
                approvedBy = $ApprovedBy
                justification = $ApprovalJustification
                recordedAt = $approvalRecordedAt
            })) | Out-Null
}
foreach ($approvedAgentId in $approvedAgentSet) {
    $approvalEntries.Add([pscustomobject]([ordered]@{
                scope = 'agent'
                targetId = $approvedAgentId
                approvedBy = $ApprovedBy
                justification = $ApprovalJustification
                recordedAt = $approvalRecordedAt
            })) | Out-Null
}

if ($approvalEntries.Count -gt 0) {
    Write-JsonFile -Path $approvalRecordPath -Value ([ordered]@{
            traceId = $trace
            approvals = $approvalEntries.ToArray()
        })
    $artifactMap['approval-record'] = $approvalRecordPath
}

$stageResults = New-Object System.Collections.Generic.List[object]
$runWarnings = New-Object System.Collections.Generic.List[string]
$runFailures = New-Object System.Collections.Generic.List[string]
$agentUsage = @{}

foreach ($agent in @($agentsManifest.agents)) {
    $agentUsage[[string] $agent.id] = [ordered]@{
        steps = 0
        durationMs = 0
        fileEdits = 0
        tokenUsage = 0
    }
}

$pipelineStartedAt = Get-Date
$resumeInfo = [ordered]@{
    resumed = ($null -ne $resumeRunDirectory)
    sourceRunDirectory = if ($null -ne $resumeRunDirectory) { Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $resumeRunDirectory } else { $null }
    startStageId = if ([string]::IsNullOrWhiteSpace($StartAtStageId)) { $null } else { $StartAtStageId }
}
$traceRecord = Initialize-TraceRecord -TraceId $trace -PipelineId ([string] $pipeline.id) -StartedAt $pipelineStartedAt
$checkpointState = Initialize-CheckpointState -TraceId $trace -PipelineId ([string] $pipeline.id) -StartedAt $pipelineStartedAt

if ($null -ne $resumeRunDirectory) {
    $existingRunArtifactPath = Join-Path $resumeRunDirectory 'run-artifact.json'
    if (Test-Path -LiteralPath $existingRunArtifactPath -PathType Leaf) {
        $existingRunArtifact = Read-JsonFile -Path $existingRunArtifactPath
        foreach ($existingStage in @($existingRunArtifact.stages | Where-Object { $_.status -eq 'success' -and -not $selectedStageIds.Contains([string] $_.stageId) })) {
            $stageResults.Add($existingStage) | Out-Null
        }
    }

    $existingCheckpointPath = Join-Path $resumeRunDirectory 'checkpoint-state.json'
    if (Test-Path -LiteralPath $existingCheckpointPath -PathType Leaf) {
        $checkpointState = Read-HardeningJsonFile -Path $existingCheckpointPath
    }

    $existingTracePath = Join-Path $resumeRunDirectory 'trace-record.json'
    if (Test-Path -LiteralPath $existingTracePath -PathType Leaf) {
        $existingTraceRecord = Read-HardeningJsonFile -Path $existingTracePath
        $traceRecord.stages = @($existingTraceRecord.stages)
        $traceRecord.summary = $existingTraceRecord.summary
        $traceRecord.updatedAt = (Get-Date).ToString('o')
    }

    foreach ($completedStageId in @($stageResults | ForEach-Object { [string] $_.stageId })) {
        $resumeOutputManifestPath = Join-Path $stagesDirectory ("{0}-output.json" -f $completedStageId)
        if (-not (Test-Path -LiteralPath $resumeOutputManifestPath -PathType Leaf)) {
            continue
        }

        $resumeOutputManifest = Read-JsonFile -Path $resumeOutputManifestPath
        $resumeArtifactMap = Convert-ManifestToArtifactMap -Manifest $resumeOutputManifest -Root $resolvedRepoRoot
        foreach ($entry in $resumeArtifactMap.GetEnumerator()) {
            $artifactMap[$entry.Key] = $entry.Value
        }
    }

    if (Test-Path -LiteralPath $approvalRecordPath -PathType Leaf) {
        $artifactMap['approval-record'] = $approvalRecordPath
    }
}

Write-StyledOutput ("[INFO] Pipeline warning-only mode: {0}" -f $WarningOnly)
Write-StyledOutput ("[INFO] Continue on stage failure: {0}" -f $effectiveContinueOnStageFailure)
Write-StyledOutput ("[INFO] Retry delay seconds: {0}" -f $effectiveRetryDelaySeconds)
Write-StyledOutput ("[INFO] Max pipeline duration seconds: {0}" -f $effectiveMaxPipelineDurationSeconds)
Write-StyledOutput ("[INFO] Execution backend: {0}" -f $effectiveExecutionBackend)
if (-not [string]::IsNullOrWhiteSpace($StopAfterStageId)) {
    Write-StyledOutput ("[INFO] Stop after stage: {0}" -f $StopAfterStageId)
}
if (-not [string]::IsNullOrWhiteSpace($StartAtStageId)) {
    Write-StyledOutput ("[INFO] Start at stage: {0}" -f $StartAtStageId)
}
if ($resumeInfo.resumed) {
    Write-StyledOutput ("[INFO] Resume from run directory: {0}" -f $resumeRunDirectory)
}

if ($effectiveWriteRunState) {
    Write-RunStateArtifact `
        -Path $runStatePath `
        -TraceIdValue $trace `
        -PipelineId ([string] $pipeline.id) `
        -Status 'running' `
        -CurrentStageId '' `
        -StartedAt $pipelineStartedAt `
        -StageResults $stageResults `
        -Warnings $runWarnings `
        -Failures $runFailures `
        -ArtifactMap $artifactMap `
        -AgentUsage $agentUsage `
        -Root $resolvedRepoRoot
}

foreach ($stage in @($selectedStages)) {
    $stageId = [string] $stage.id
    $agentId = [string] $stage.agentId
    $stageMode = [string] $stage.mode
    $onFailure = [string] (Get-OptionalPropertyValue -Object $stage -PropertyName 'onFailure' -DefaultValue 'stop')
    $execution = Get-OptionalPropertyValue -Object $stage -PropertyName 'execution'
    $retryCountValue = Get-OptionalPropertyValue -Object $execution -PropertyName 'retryCount'
    $configuredRetries = if ($null -ne $retryCountValue) {
        [Math]::Max(0, [int] $retryCountValue)
    }
    elseif ($onFailure -eq 'retry-once') {
        1
    }
    else {
        0
    }
    $maxAttempts = [Math]::Max(1, $configuredRetries + 1)

    if (-not $agentMap.ContainsKey($agentId)) {
        $runFailures.Add(("Unknown agentId in stage {0}: {1}" -f $stageId, $agentId)) | Out-Null
        $stageResults.Add([ordered]@{
            stageId = $stageId
            agentId = $agentId
            status = 'failed'
            startedAt = (Get-Date).ToString('o')
            finishedAt = (Get-Date).ToString('o')
            durationMs = 0
            inputArtifacts = @($stage.inputArtifacts)
            outputArtifacts = @()
            validation = [ordered]@{ warnings = 0; failures = 1 }
        }) | Out-Null
        break
    }

    $agent = $agentMap[$agentId]
    $usage = $agentUsage[$agentId]
    $budget = $agent.budget
    $stageStatePath = Join-Path $stagesDirectory ("{0}-state.json" -f $stageId)
    $dispatchMode = [string] (Get-OptionalPropertyValue -Object $execution -PropertyName 'dispatchMode' -DefaultValue 'scripted')
    $promptTemplatePathValue = [string] (Get-OptionalPropertyValue -Object $execution -PropertyName 'promptTemplatePath' -DefaultValue '')
    $responseSchemaPathValue = [string] (Get-OptionalPropertyValue -Object $execution -PropertyName 'responseSchemaPath' -DefaultValue '')

    $attempt = 0
    $stageSucceeded = $false
    $stageClarificationRequested = $false
    $lastFailureMessage = $null
    $stageStartedAt = Get-Date
    $stageFinishedAt = $stageStartedAt
    $stageDurationMs = 0
    $producedArtifactNames = @()
    $changedDelta = @()
    $stageExecutionDetails = [ordered]@{
        backend = if ($dispatchMode -eq 'codex-exec') { $effectiveExecutionBackend } else { 'scripted' }
        attempts = 0
        dispatchMode = $dispatchMode
        promptTemplatePath = $promptTemplatePathValue
        responseSchemaPath = $responseSchemaPathValue
        dispatchCount = 0
        workItemCount = 0
        changedFileCount = 0
        stageStatePath = $null
        approvalRequired = $false
        approvalSatisfied = $false
        approvalRecordPath = $null
        resolvedModel = $null
        modelRoutingSource = $null
        modelRoutingRuleId = $null
        policyDecisionCount = 0
        policyBlockCount = 0
        clarificationRequired = $false
        canProceedSafely = $true
        clarificationReason = $null
        clarificationQuestions = @()
    }

    $approvalEvaluation = Get-StageApprovalEvaluation `
        -StageId $stageId `
        -AgentId $agentId `
        -Agent $agent `
        -DefaultApprovalRequired $defaultApprovalRequired `
        -ApprovedStageSet $approvedStageSet `
        -ApprovedAgentSet $approvedAgentSet
    $stageBlockedByApproval = $approvalEvaluation.required -and -not $approvalEvaluation.satisfied
    $stageExecutionDetails.approvalRequired = [bool] $approvalEvaluation.required
    $stageExecutionDetails.approvalSatisfied = [bool] $approvalEvaluation.satisfied
    if ($approvalEntries.Count -gt 0) {
        $stageExecutionDetails.approvalRecordPath = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $approvalRecordPath
    }

    $modelRoutingDecision = Resolve-AgentModelRoutingDecision `
        -Catalog $modelRoutingCatalogInfo.Catalog `
        -StageId $stageId `
        -AgentId $agentId `
        -AgentRole ([string] $agent.role) `
        -StageMode $stageMode `
        -AgentModel ([string] $agent.model)
    $stageExecutionDetails.resolvedModel = [string] $modelRoutingDecision.model
    $stageExecutionDetails.modelRoutingSource = [string] $modelRoutingDecision.source
    $stageExecutionDetails.modelRoutingRuleId = [string] $modelRoutingDecision.ruleId

    if ($stageBlockedByApproval) {
        $instructionsText = if ([string]::IsNullOrWhiteSpace([string] $approvalEvaluation.instructions)) {
            'Provide explicit approval before running this sensitive stage.'
        }
        else {
            [string] $approvalEvaluation.instructions
        }
        $lastFailureMessage = ("Stage {0} (agent={1}) requires explicit approval. {2} Use -ApprovedStageIds {0} or -ApprovedAgentIds {1} together with -ApprovedBy and -ApprovalJustification." -f $stageId, $agentId, $instructionsText)
        Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
    }

    while (-not $stageBlockedByApproval -and $attempt -lt $maxAttempts -and -not $stageSucceeded) {
        $attempt++
        Write-StyledOutput ("[INFO] Stage {0} (agent={1}, mode={2}) attempt {3}/{4}" -f $stageId, $agentId, $stageMode, $attempt, $maxAttempts)

        $elapsedPipelineSeconds = [int] ((Get-Date) - $pipelineStartedAt).TotalSeconds
        if ($elapsedPipelineSeconds -gt $effectiveMaxPipelineDurationSeconds) {
            $lastFailureMessage = ("Pipeline exceeded max duration ({0}s) before stage {1}." -f $effectiveMaxPipelineDurationSeconds, $stageId)
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            break
        }

        $inputMissing = @()
        foreach ($inputArtifact in @($stage.inputArtifacts)) {
            $name = [string] $inputArtifact
            if (-not $artifactMap.ContainsKey($name)) {
                $inputMissing += $name
            }
        }

        if ($inputMissing.Count -gt 0) {
            $lastFailureMessage = ("Missing input artifacts for stage {0}: {1}" -f $stageId, ($inputMissing -join ', '))
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        $plannedCommands = Get-ArtifactPlannedCommands -ArtifactMap $artifactMap
        $normalizedRequestText = Get-NormalizedRequestText -ArtifactMap $artifactMap
        $prePolicyEvaluation = Invoke-StagePolicyEvaluation `
            -Catalog $policyCatalogInfo.Catalog `
            -Phase 'pre-stage' `
            -TraceId $trace `
            -StageId $stageId `
            -AgentId $agentId `
            -StageMode $stageMode `
            -EffectiveModel ([string] $modelRoutingDecision.model) `
            -RequestText $RequestText `
            -NormalizedRequestText $normalizedRequestText `
            -PlannedCommands $plannedCommands `
            -ApprovalRequired ([bool] $approvalEvaluation.required) `
            -ApprovalSatisfied ([bool] $approvalEvaluation.satisfied)
        foreach ($evaluation in @($prePolicyEvaluation.evaluations)) {
            $policyEvaluationEntries.Add($evaluation) | Out-Null
            if ([string] $evaluation.action -eq 'warn') {
                $runWarnings.Add(("Policy warning [{0}] stage {1}: {2}" -f [string] $evaluation.ruleId, $stageId, [string] $evaluation.message)) | Out-Null
            }
        }
        $stageExecutionDetails.policyDecisionCount = [int] $prePolicyEvaluation.evaluations.Count
        $stageExecutionDetails.policyBlockCount = [int] $prePolicyEvaluation.blockCount
        if ([bool] $prePolicyEvaluation.blocked) {
            $lastFailureMessage = ("Stage {0} blocked by policy rules: {1}" -f $stageId, ((@($prePolicyEvaluation.evaluations | Where-Object { $_.action -eq 'block' } | ForEach-Object { [string] $_.ruleId }) | Select-Object -Unique) -join ', '))
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            break
        }

        if (-not $SkipGuardrails) {
            $usage.steps = [int] $usage.steps + 1
            if ([int] $usage.steps -gt [int] $budget.maxSteps) {
                $lastFailureMessage = ("Agent {0} exceeded maxSteps ({1})." -f $agentId, $budget.maxSteps)
                Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
                if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $effectiveRetryDelaySeconds
                }
                continue
            }
        }

        $execution = Get-OptionalPropertyValue -Object $stage -PropertyName 'execution'
        if ($null -eq $execution) {
            $lastFailureMessage = ("Stage {0} is missing execution configuration." -f $stageId)
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        $scriptPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path ([string] $execution.scriptPath)
        $scriptPathRelative = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $scriptPath

        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            $lastFailureMessage = ("Stage {0} script not found: {1}" -f $stageId, $scriptPathRelative)
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        $syntheticCommand = "pwsh -File $scriptPathRelative"
        $blockedCommands = @((Get-OptionalPropertyValue -Object $agent -PropertyName 'blockedCommands' -DefaultValue @()))
        if (-not $SkipGuardrails -and (Test-IsBlockedCommand -CommandText $syntheticCommand -BlockedCommands $blockedCommands)) {
            $lastFailureMessage = ("Blocked command for agent {0}: {1}" -f $agentId, $syntheticCommand)
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        $inputManifestPath = Join-Path $stagesDirectory ("{0}-input.json" -f $stageId)
        $outputManifestPath = Join-Path $stagesDirectory ("{0}-output.json" -f $stageId)

        $inputArtifacts = @()
        foreach ($inputArtifactName in @($stage.inputArtifacts)) {
            $artifactName = [string] $inputArtifactName
            $inputArtifacts += (Get-ArtifactDescriptor -Name $artifactName -AbsolutePath ([string] $artifactMap[$artifactName]) -Root $resolvedRepoRoot)
        }

        $inputManifest = [ordered]@{
            traceId = $trace
            stageId = $stageId
            agentId = $agentId
            producedAt = (Get-Date).ToString('o')
            artifacts = $inputArtifacts
        }

        Set-Content -LiteralPath $inputManifestPath -Value ($inputManifest | ConvertTo-Json -Depth 60) -Encoding UTF8 -NoNewline

        $beforeSet = if ($SkipGuardrails) { $null } else { Get-WorkingTreePathSet -Root $resolvedRepoRoot }

        $stageStartedAt = Get-Date
        $stageParameters = @{
            RepoRoot = $resolvedRepoRoot
            RunDirectory = $runDirectory
            TraceId = $trace
            StageId = $stageId
            AgentId = $agentId
            RequestPath = $requestPath
            InputArtifactManifestPath = $inputManifestPath
            OutputArtifactManifestPath = $outputManifestPath
            AgentsManifestPath = $resolvedAgentsManifestPath
            DispatchMode = $dispatchMode
            PromptTemplatePath = $promptTemplatePathValue
            ResponseSchemaPath = $responseSchemaPathValue
            DispatchCommand = $DispatchCommand
            ExecutionBackend = $effectiveExecutionBackend
            EffectiveModel = [string] $modelRoutingDecision.model
            StageStatePath = $stageStatePath
            DetailedOutput = [bool] $DetailedOutput
        }
        & $scriptPath @stageParameters
        $stageExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        $stageFinishedAt = Get-Date
        $stageDurationMs = [int] ($stageFinishedAt - $stageStartedAt).TotalMilliseconds
        $stageExecutionDetails.attempts = $attempt

        $timeoutSecondsValue = Get-OptionalPropertyValue -Object $execution -PropertyName 'timeoutSeconds' -DefaultValue 1800
        $timeoutSeconds = [int] $timeoutSecondsValue
        if ($stageDurationMs -gt ($timeoutSeconds * 1000)) {
            $lastFailureMessage = ("Stage {0} exceeded timeoutSeconds ({1}). Duration={2}ms." -f $stageId, $timeoutSeconds, $stageDurationMs)
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        if ($stageExitCode -ne 0) {
            $lastFailureMessage = ("Stage {0} failed with exit code {1}." -f $stageId, $stageExitCode)
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        if (-not (Test-Path -LiteralPath $outputManifestPath -PathType Leaf)) {
            $lastFailureMessage = ("Stage {0} output manifest not found: {1}" -f $stageId, (Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $outputManifestPath))
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        $outputManifest = Read-JsonFile -Path $outputManifestPath
        $stageArtifactMap = Convert-ManifestToArtifactMap -Manifest $outputManifest -Root $resolvedRepoRoot
        if (Test-Path -LiteralPath $stageStatePath -PathType Leaf) {
            $stageState = Read-JsonFile -Path $stageStatePath
            $stageExecutionDetails.backend = [string] (Get-OptionalPropertyValue -Object $stageState -PropertyName 'backend' -DefaultValue $stageExecutionDetails.backend)
            $stageExecutionDetails.dispatchCount = [int] (Get-OptionalPropertyValue -Object $stageState -PropertyName 'dispatchCount' -DefaultValue 0)
            $stageExecutionDetails.workItemCount = [int] (Get-OptionalPropertyValue -Object $stageState -PropertyName 'workItemCount' -DefaultValue 0)
            $stageExecutionDetails.changedFileCount = [int] (Get-OptionalPropertyValue -Object $stageState -PropertyName 'changedFileCount' -DefaultValue 0)
            $stageExecutionDetails.stageStatePath = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $stageStatePath
            $stateWarningValue = [string] (Get-OptionalPropertyValue -Object $stageState -PropertyName 'warning' -DefaultValue '')
            if (-not [string]::IsNullOrWhiteSpace($stateWarningValue)) {
                $runWarnings.Add(("Stage {0} fallback detail: {1}" -f $stageId, $stateWarningValue)) | Out-Null
            }
            $stateWarnings = @((Get-OptionalPropertyValue -Object $stageState -PropertyName 'warnings' -DefaultValue @()))
            foreach ($stateWarning in $stateWarnings) {
                $warningText = [string] $stateWarning
                if (-not [string]::IsNullOrWhiteSpace($warningText)) {
                    $runWarnings.Add(("Stage {0} warning: {1}" -f $stageId, $warningText)) | Out-Null
                }
            }
        }

        $missingOutputs = @()
        foreach ($expectedOutputName in @($stage.outputArtifacts)) {
            $requiredName = [string] $expectedOutputName
            if (-not $stageArtifactMap.ContainsKey($requiredName)) {
                $missingOutputs += $requiredName
                continue
            }

            $absoluteOutputPath = [string] $stageArtifactMap[$requiredName]
            if (-not (Test-Path -LiteralPath $absoluteOutputPath -PathType Leaf)) {
                $missingOutputs += $requiredName
            }
        }

        if ($missingOutputs.Count -gt 0) {
            $lastFailureMessage = ("Stage {0} missing declared output artifacts: {1}" -f $stageId, ($missingOutputs -join ', '))
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        foreach ($entry in $stageArtifactMap.GetEnumerator()) {
            $artifactMap[$entry.Key] = $entry.Value
        }
        $producedArtifactNames = @($stageArtifactMap.Keys)

        $clarificationDetails = Get-IntakeClarificationDetails -StageId $stageId -ArtifactMap $stageArtifactMap
        $stageExecutionDetails.clarificationRequired = [bool] $clarificationDetails.clarificationRequired
        $stageExecutionDetails.canProceedSafely = [bool] $clarificationDetails.canProceedSafely
        $stageExecutionDetails.clarificationReason = $clarificationDetails.clarificationReason
        $stageExecutionDetails.clarificationQuestions = @($clarificationDetails.clarificationQuestions)
        if ([bool] $clarificationDetails.clarificationRequired) {
            $stageSucceeded = $true
            $stageClarificationRequested = $true
            $reasonText = if ([string]::IsNullOrWhiteSpace([string] $clarificationDetails.clarificationReason)) {
                'The intake stage requires clarification before planning can proceed safely.'
            }
            else {
                [string] $clarificationDetails.clarificationReason
            }

            $runWarnings.Add(("Clarification required after intake: {0}" -f $reasonText)) | Out-Null
            foreach ($clarificationQuestion in @($clarificationDetails.clarificationQuestions)) {
                $runWarnings.Add(("Clarification question: {0}" -f $clarificationQuestion)) | Out-Null
            }
            break
        }

        $afterSet = if ($SkipGuardrails) { $null } else { Get-WorkingTreePathSet -Root $resolvedRepoRoot }
        if (-not $SkipGuardrails -and $null -ne $beforeSet -and $null -ne $afterSet) {
            $changedDelta = @()
            foreach ($pathAfter in $afterSet) {
                if (-not $beforeSet.Contains($pathAfter)) {
                    $changedDelta += $pathAfter
                }
            }

            $disallowed = @()
            $allowedPaths = @((Get-OptionalPropertyValue -Object $agent -PropertyName 'allowedPaths' -DefaultValue @()))
            foreach ($relativeChangedPath in $changedDelta) {
                if (-not (Test-IsPathAllowed -RelativePath $relativeChangedPath -AllowedPatterns $allowedPaths)) {
                    $disallowed += $relativeChangedPath
                }
            }

            if ($disallowed.Count -gt 0) {
                $lastFailureMessage = ("Agent {0} changed disallowed paths: {1}" -f $agentId, ($disallowed -join ', '))
                Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
                if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $effectiveRetryDelaySeconds
                }
                continue
            }

            $usage.fileEdits = [int] $usage.fileEdits + $changedDelta.Count
            if ($changedDelta.Count -gt $stageExecutionDetails.changedFileCount) {
                $stageExecutionDetails.changedFileCount = $changedDelta.Count
            }
            if ([int] $usage.fileEdits -gt [int] $budget.maxFileEdits) {
                $lastFailureMessage = ("Agent {0} exceeded maxFileEdits ({1}). Current={2}" -f $agentId, $budget.maxFileEdits, $usage.fileEdits)
                Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
                if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $effectiveRetryDelaySeconds
                }
                continue
            }

            $usage.durationMs = [int] $usage.durationMs + $stageDurationMs
            $maxDurationMs = [int] $budget.maxDurationMinutes * 60000
            if ([int] $usage.durationMs -gt $maxDurationMs) {
                $lastFailureMessage = ("Agent {0} exceeded maxDurationMinutes ({1}). CurrentDurationMs={2}" -f $agentId, $budget.maxDurationMinutes, $usage.durationMs)
                Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
                if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $effectiveRetryDelaySeconds
                }
                continue
            }

            $estimatedTokens = 0
            foreach ($artifactName in $stageArtifactMap.Keys) {
                $artifactPath = [string] $stageArtifactMap[$artifactName]
                if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
                    continue
                }

                try {
                    $artifactContent = Get-Content -Raw -LiteralPath $artifactPath
                    $estimatedTokens += [int] [Math]::Ceiling($artifactContent.Length / 4.0)
                }
                catch {
                    continue
                }
            }

            $usage.tokenUsage = [int] $usage.tokenUsage + $estimatedTokens
            if ([int] $usage.tokenUsage -gt [int] $budget.maxTokens) {
                $lastFailureMessage = ("Agent {0} exceeded maxTokens ({1})." -f $agentId, $budget.maxTokens)
                Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
                if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $effectiveRetryDelaySeconds
                }
                continue
            }
        }

        $postPolicyEvaluation = Invoke-StagePolicyEvaluation `
            -Catalog $policyCatalogInfo.Catalog `
            -Phase 'post-stage' `
            -TraceId $trace `
            -StageId $stageId `
            -AgentId $agentId `
            -StageMode $stageMode `
            -EffectiveModel ([string] $modelRoutingDecision.model) `
            -RequestText $RequestText `
            -NormalizedRequestText $normalizedRequestText `
            -PlannedCommands $plannedCommands `
            -ChangedPaths $changedDelta `
            -ApprovalRequired ([bool] $approvalEvaluation.required) `
            -ApprovalSatisfied ([bool] $approvalEvaluation.satisfied)
        foreach ($evaluation in @($postPolicyEvaluation.evaluations)) {
            $policyEvaluationEntries.Add($evaluation) | Out-Null
            if ([string] $evaluation.action -eq 'warn') {
                $runWarnings.Add(("Policy warning [{0}] stage {1}: {2}" -f [string] $evaluation.ruleId, $stageId, [string] $evaluation.message)) | Out-Null
            }
        }
        $stageExecutionDetails.policyDecisionCount = [int] $stageExecutionDetails.policyDecisionCount + [int] $postPolicyEvaluation.evaluations.Count
        $stageExecutionDetails.policyBlockCount = [int] $stageExecutionDetails.policyBlockCount + [int] $postPolicyEvaluation.blockCount
        if ([bool] $postPolicyEvaluation.blocked) {
            $lastFailureMessage = ("Stage {0} blocked by post-stage policy rules: {1}" -f $stageId, ((@($postPolicyEvaluation.evaluations | Where-Object { $_.action -eq 'block' } | ForEach-Object { [string] $_.ruleId }) | Select-Object -Unique) -join ', '))
            Write-StyledOutput ("[ERROR] {0}" -f $lastFailureMessage)
            if ($attempt -lt $maxAttempts -and $effectiveRetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $effectiveRetryDelaySeconds
            }
            continue
        }

        $stageSucceeded = $true
    }

    if ((-not $stageSucceeded) -and (-not $stageClarificationRequested)) {
        $runFailures.Add($lastFailureMessage) | Out-Null
        $fallbackAgentId = [string] (Get-OptionalPropertyValue -Object $agent -PropertyName 'fallbackAgentId' -DefaultValue '')
        if (-not [string]::IsNullOrWhiteSpace($fallbackAgentId)) {
            $runWarnings.Add(("Stage {0} failed for agent '{1}'. Fallback agent available: '{2}'." -f $stageId, $agentId, $fallbackAgentId)) | Out-Null
        }
    }

    $stageStatus = if ($stageClarificationRequested) { 'partial' } elseif ($stageSucceeded) { 'success' } else { 'failed' }
    $stageOutputArtifacts = if ($stageSucceeded) { @($producedArtifactNames) } else { @() }
    $stageFailureCount = if ($stageClarificationRequested -or $stageSucceeded) { 0 } else { 1 }
    $stageResult = [pscustomobject]@{
        stageId = $stageId
        agentId = $agentId
        status = $stageStatus
        startedAt = $stageStartedAt.ToString('o')
        finishedAt = $stageFinishedAt.ToString('o')
        durationMs = $stageDurationMs
        inputArtifacts = @($stage.inputArtifacts)
        outputArtifacts = $stageOutputArtifacts
        validation = [pscustomobject]@{
            warnings = 0
            failures = $stageFailureCount
        }
        execution = [pscustomobject]$stageExecutionDetails
    }
    $stageResults.Add($stageResult) | Out-Null

    $nextSelectedStageId = ''
    $nextPipelineStageId = ''
    for ($stageCursor = 0; $stageCursor -lt $pipelineStages.Count; $stageCursor++) {
        if ([string] $pipelineStages[$stageCursor].id -ne $stageId) {
            continue
        }

        if (($stageCursor + 1) -lt $pipelineStages.Count) {
            $nextPipelineStageId = [string] $pipelineStages[$stageCursor + 1].id
        }

        for ($nextCursor = $stageCursor + 1; $nextCursor -lt $pipelineStages.Count; $nextCursor++) {
            $candidateNextStageId = [string] $pipelineStages[$nextCursor].id
            if ($selectedStageIds.Contains($candidateNextStageId)) {
                $nextSelectedStageId = $candidateNextStageId
                break
            }
        }

        Set-CheckpointStageStatus `
            -CheckpointState $checkpointState `
            -StageId $stageId `
            -StageIndex $stageCursor `
            -Status $stageStatus `
            -CheckpointEligible ($stageStatus -eq 'success') `
            -NextStageId $(if ($stageClarificationRequested) { $stageId } else { $nextPipelineStageId })
        break
    }

    Add-TraceStageEntry -TraceRecord $traceRecord -StageEntry ([ordered]@{
            stageId = $stageId
            agentId = $agentId
            status = $stageStatus
            startedAt = $stageStartedAt.ToString('o')
            finishedAt = $stageFinishedAt.ToString('o')
            durationMs = $stageDurationMs
            model = [ordered]@{
                effectiveModel = [string] $modelRoutingDecision.model
                source = [string] $modelRoutingDecision.source
                ruleId = [string] $modelRoutingDecision.ruleId
                reason = [string] $modelRoutingDecision.reason
            }
            policy = [ordered]@{
                warningCount = [Math]::Max(0, [int] $stageExecutionDetails.policyDecisionCount - [int] $stageExecutionDetails.policyBlockCount)
                blockCount = [int] $stageExecutionDetails.policyBlockCount
                evaluationCount = [int] $stageExecutionDetails.policyDecisionCount
            }
            dispatch = [ordered]@{
                backend = [string] $stageExecutionDetails.backend
                dispatchMode = [string] $stageExecutionDetails.dispatchMode
                dispatchCount = [int] $stageExecutionDetails.dispatchCount
            }
            checkpoint = [ordered]@{
                eligible = ($stageStatus -eq 'success')
                resumableFromStageId = $(if ($stageClarificationRequested) { $stageId } else { $nextPipelineStageId })
            }
        })
    Write-HardeningJsonFile -Path $traceRecordPath -Value $traceRecord
    Write-HardeningJsonFile -Path $policyEvaluationsPath -Value ([ordered]@{
            traceId = $trace
            evaluations = $policyEvaluationEntries.ToArray()
        })
    Write-HardeningJsonFile -Path $checkpointStatePath -Value $checkpointState

    if ($stageSucceeded) {
        foreach ($handoff in @($pipeline.handoffs | Where-Object { $_.fromStage -eq $stageId -and $selectedStageIds.Contains([string] $_.toStage) })) {
            Write-HandoffArtifact `
                -Root $resolvedRepoRoot `
                -TraceIdValue $trace `
                -PipelineId ([string] $pipeline.id) `
                -FromStage ([string] $handoff.fromStage) `
                -ToStage ([string] $handoff.toStage) `
                -RequiredArtifacts @($handoff.requiredArtifacts) `
                -ArtifactMap $artifactMap `
                -HandoffsDirectory $handoffsDirectory
        }
    }

    if (-not $stageSucceeded -and $onFailure -eq 'stop' -and -not $effectiveContinueOnStageFailure) {
        break
    }

    if ($stageBlockedByApproval) {
        break
    }

    if ($stageClarificationRequested) {
        break
    }

    if (-not $stageSucceeded -and $onFailure -eq 'stop' -and $effectiveContinueOnStageFailure) {
        $runWarnings.Add(("Stage {0} configured with stop-on-failure, but execution continued due ContinueOnStageFailure=true." -f $stageId)) | Out-Null
    }

    if ($effectiveWriteRunState) {
        Write-RunStateArtifact `
            -Path $runStatePath `
            -TraceIdValue $trace `
            -PipelineId ([string] $pipeline.id) `
            -Status 'running' `
            -CurrentStageId $stageId `
            -StartedAt $pipelineStartedAt `
            -StageResults $stageResults `
            -Warnings $runWarnings `
            -Failures $runFailures `
            -ArtifactMap $artifactMap `
            -AgentUsage $agentUsage `
            -Root $resolvedRepoRoot
    }
}

$pipelineFinishedAt = Get-Date
$failedStages = @($stageResults | Where-Object { $_.status -ne 'success' }).Count
$clarificationStages = @($stageResults | Where-Object { [bool] (Get-OptionalPropertyValue -Object $_.execution -PropertyName 'clarificationRequired' -DefaultValue $false) }).Count

$missingCompletionStages = @()
$missingCompletionArtifacts = @()
if ($clarificationStages -eq 0) {
    foreach ($requiredStage in @($completionRequiredStages)) {
        $requiredStageId = [string] $requiredStage
        $stageOk = @($stageResults | Where-Object { $_.stageId -eq $requiredStageId -and $_.status -eq 'success' }).Count -gt 0
        if (-not $stageOk) {
            $missingCompletionStages += $requiredStageId
        }
    }

    foreach ($requiredArtifact in @($completionRequiredArtifacts)) {
        $requiredName = [string] $requiredArtifact
        if (-not $artifactMap.ContainsKey($requiredName)) {
            $missingCompletionArtifacts += $requiredName
        }
    }
}

if ($missingCompletionStages.Count -gt 0) {
    $runFailures.Add(("Missing required successful stages: {0}" -f ($missingCompletionStages -join ', '))) | Out-Null
}

if ($missingCompletionArtifacts.Count -gt 0) {
    $runFailures.Add(("Missing required completion artifacts: {0}" -f ($missingCompletionArtifacts -join ', '))) | Out-Null
}

$hardFailedStages = @($stageResults | Where-Object { $_.status -eq 'failed' }).Count
$hasHardFailures = ($hardFailedStages -gt 0) -or ($runFailures.Count -gt 0)
$overallStatus = if (-not $hasHardFailures -and $clarificationStages -gt 0) {
    'partial'
}
elseif (-not $hasHardFailures) {
    'success'
}
elseif ($WarningOnly) {
    'partial'
}
else {
    'failed'
}
$guardrailNotes = if ($clarificationStages -gt 0) {
    'Clarification is required before planning or execution can continue safely.'
}
elseif ($SkipGuardrails) {
    'Executed with guardrails disabled.'
}
else {
    'Guardrails enforced for paths, commands, and budgets.'
}

$runArtifactPath = Join-Path $runDirectory 'run-artifact.json'
$stagesForArtifact = @()
foreach ($stageResultItem in $stageResults) {
    $stagesForArtifact += $stageResultItem
}
$runSummary = [pscustomobject]@{
    stageCount = $stageResults.Count
    failedStages = $failedStages
    warningCount = $runWarnings.Count
    policyWarningCount = @($policyEvaluationEntries | Where-Object { $_.action -eq 'warn' }).Count
    policyBlockCount = @($policyEvaluationEntries | Where-Object { $_.action -eq 'block' }).Count
    estimatedCostUsd = 0
    totalDurationMs = [int] ($pipelineFinishedAt - $pipelineStartedAt).TotalMilliseconds
    notes = $guardrailNotes
}
$traceRecord.status = $overallStatus
$traceRecord.updatedAt = $pipelineFinishedAt.ToString('o')
$traceRecord.summary.totalDurationMs = [int] ($pipelineFinishedAt - $pipelineStartedAt).TotalMilliseconds
$checkpointState.status = $overallStatus
$checkpointState.updatedAt = $pipelineFinishedAt.ToString('o')
$runArtifact = [pscustomobject]@{
    traceId = $trace
    pipelineId = [string] $pipeline.id
    status = $overallStatus
    startedAt = $pipelineStartedAt.ToString('o')
    finishedAt = $pipelineFinishedAt.ToString('o')
    stages = $stagesForArtifact
    summary = $runSummary
    traceRecordPath = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $traceRecordPath
    policyEvaluationsPath = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $policyEvaluationsPath
    checkpointStatePath = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $checkpointStatePath
    resume = [pscustomobject]$resumeInfo
    approvals = $approvalEntries.ToArray()
}

Set-Content -LiteralPath $runArtifactPath -Value ($runArtifact | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
Write-HardeningJsonFile -Path $traceRecordPath -Value $traceRecord
Write-HardeningJsonFile -Path $policyEvaluationsPath -Value ([ordered]@{
        traceId = $trace
        evaluations = $policyEvaluationEntries.ToArray()
    })
Write-HardeningJsonFile -Path $checkpointStatePath -Value $checkpointState

if ($effectiveWriteRunState) {
    Write-RunStateArtifact `
        -Path $runStatePath `
        -TraceIdValue $trace `
        -PipelineId ([string] $pipeline.id) `
        -Status $overallStatus `
        -CurrentStageId '' `
        -StartedAt $pipelineStartedAt `
        -StageResults $stageResults `
        -Warnings $runWarnings `
        -Failures $runFailures `
        -ArtifactMap $artifactMap `
        -AgentUsage $agentUsage `
        -Root $resolvedRepoRoot
}

Write-StyledOutput ''
Write-StyledOutput 'Agent pipeline execution summary'
Write-StyledOutput ("  traceId: {0}" -f $trace)
Write-StyledOutput ("  pipeline: {0}" -f $pipeline.id)
Write-StyledOutput ("  status: {0}" -f $overallStatus)
Write-StyledOutput ("  stages: total={0} failed={1}" -f $stageResults.Count, $failedStages)
Write-StyledOutput ("  run artifact: {0}" -f (Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $runArtifactPath))

if ($runFailures.Count -gt 0) {
    $failureLabel = if ($WarningOnly) { '  failure-warnings:' } else { '  failures:' }
    Write-StyledOutput $failureLabel
    foreach ($failure in $runFailures) {
        $prefix = if ($WarningOnly) { '[WARN]' } else { '[FAIL]' }
        Write-StyledOutput ("    {0} {1}" -f $prefix, $failure)
    }
}

if ($runWarnings.Count -gt 0) {
    Write-StyledOutput '  warnings:'
    foreach ($warning in $runWarnings) {
        Write-StyledOutput ("    [WARN] {0}" -f $warning)
    }
}

Complete-ExecutionSession -Name 'run-agent-pipeline' -Status $(if ($overallStatus -eq 'failed') { 'failed' } elseif ($overallStatus -eq 'partial') { 'warning' } else { 'passed' }) -Summary ([ordered]@{
        'Trace id' = $trace
        'Stages total' = $stageResults.Count
        'Stages failed' = $failedStages
        'Warnings' = $runWarnings.Count
        'Failures' = $runFailures.Count
    }) | Out-Null

if ($overallStatus -eq 'failed') {
    exit 1
}

exit 0