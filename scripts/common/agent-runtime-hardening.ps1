<#
.SYNOPSIS
    Shared runtime helper for Super Agent hardening contracts.

.DESCRIPTION
    Provides deterministic helpers for policy evaluation, model routing,
    trace scaffolding, checkpoint state, and resume selection.

.EXAMPLE
    . ./scripts/common/agent-runtime-hardening.ps1
    $policyCatalog = Get-AgentRuntimePolicyCatalog -Root $RepoRoot

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reads a hardening JSON file with orchestration-safe depth.
function Read-HardeningJsonFile {
    param([Parameter(Mandatory = $true)][string] $Path)
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Writes a hardening JSON artifact and creates parent folders when needed.
function Write-HardeningJsonFile {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][object] $Value
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value ($Value | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
}

# Reads an optional property from hashtables or PSCustomObjects safely.
function Get-HardeningOptionalValue {
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

# Resolves a versioned hardening catalog path from explicit or default input.
function Resolve-HardeningCatalogPath {
    param(
        [Parameter(Mandatory = $true)][string] $Root,
        [string] $RequestedPath,
        [Parameter(Mandatory = $true)][string] $DefaultRelativePath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return (Resolve-RepoPath -Root $Root -Path $RequestedPath)
    }

    return (Resolve-RepoPath -Root $Root -Path $DefaultRelativePath)
}

# Loads the runtime policy catalog and returns both path and parsed content.
function Get-AgentRuntimePolicyCatalog {
    param([Parameter(Mandatory = $true)][string] $Root, [string] $CatalogPath)

    $resolvedPath = Resolve-HardeningCatalogPath -Root $Root -RequestedPath $CatalogPath -DefaultRelativePath '.github/governance/agent-runtime-policy.catalog.json'
    return [pscustomobject]@{
        Path = $resolvedPath
        Catalog = Read-HardeningJsonFile -Path $resolvedPath
    }
}

# Loads the model routing catalog and returns both path and parsed content.
function Get-AgentModelRoutingCatalog {
    param([Parameter(Mandatory = $true)][string] $Root, [string] $CatalogPath)

    $resolvedPath = Resolve-HardeningCatalogPath -Root $Root -RequestedPath $CatalogPath -DefaultRelativePath '.github/governance/agent-model-routing.catalog.json'
    return [pscustomobject]@{
        Path = $resolvedPath
        Catalog = Read-HardeningJsonFile -Path $resolvedPath
    }
}

# Resolves the effective model for a stage/agent from routing rules and defaults.
function Resolve-AgentModelRoutingDecision {
    param(
        [object] $Catalog,
        [string] $StageId,
        [string] $AgentId,
        [string] $AgentRole,
        [string] $StageMode,
        [string] $AgentModel
    )

    $rules = @((Get-HardeningOptionalValue -Object $Catalog -PropertyName 'rules' -DefaultValue @()))
    foreach ($rule in $rules) {
        $stageIds = @((Get-HardeningOptionalValue -Object $rule -PropertyName 'stageIds' -DefaultValue @()) | ForEach-Object { [string] $_ })
        $agentIds = @((Get-HardeningOptionalValue -Object $rule -PropertyName 'agentIds' -DefaultValue @()) | ForEach-Object { [string] $_ })
        $roles = @((Get-HardeningOptionalValue -Object $rule -PropertyName 'roles' -DefaultValue @()) | ForEach-Object { [string] $_ })
        $modes = @((Get-HardeningOptionalValue -Object $rule -PropertyName 'modes' -DefaultValue @()) | ForEach-Object { [string] $_ })

        if ($stageIds.Count -gt 0 -and -not ($stageIds -contains $StageId)) { continue }
        if ($agentIds.Count -gt 0 -and -not ($agentIds -contains $AgentId)) { continue }
        if ($roles.Count -gt 0 -and -not ($roles -contains $AgentRole)) { continue }
        if ($modes.Count -gt 0 -and -not ($modes -contains $StageMode)) { continue }

        $model = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'model' -DefaultValue '')
        if (-not [string]::IsNullOrWhiteSpace($model)) {
            return [ordered]@{
                model = $model
                source = 'catalog-rule'
                ruleId = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'id' -DefaultValue '')
                reason = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'reason' -DefaultValue '')
            }
        }
    }

    $catalogDefaultModel = [string] (Get-HardeningOptionalValue -Object (Get-HardeningOptionalValue -Object $Catalog -PropertyName 'defaults' -DefaultValue $null) -PropertyName 'fallbackModel' -DefaultValue '')
    if (-not [string]::IsNullOrWhiteSpace($AgentModel)) {
        return [ordered]@{
            model = [string] $AgentModel
            source = 'agent-default'
            ruleId = ''
            reason = 'Using the model defined on the agent contract.'
        }
    }

    return [ordered]@{
        model = $catalogDefaultModel
        source = 'catalog-default'
        ruleId = ''
        reason = 'Using the catalog default fallback model.'
    }
}

# Extracts planned command text from the current task-plan artifact map.
function Get-ArtifactPlannedCommands {
    param([hashtable] $ArtifactMap)

    if ($null -eq $ArtifactMap -or -not $ArtifactMap.ContainsKey('task-plan-data')) {
        return @()
    }

    $taskPlanDataPath = [string] $ArtifactMap['task-plan-data']
    if (-not (Test-Path -LiteralPath $taskPlanDataPath -PathType Leaf)) {
        return @()
    }

    $taskPlanData = Read-HardeningJsonFile -Path $taskPlanDataPath
    $commands = New-Object System.Collections.Generic.List[string]
    foreach ($workItem in @($taskPlanData.workItems)) {
        foreach ($command in @((Get-HardeningOptionalValue -Object $workItem -PropertyName 'commands' -DefaultValue @()))) {
            $commandText = [string] (Get-HardeningOptionalValue -Object $command -PropertyName 'command' -DefaultValue '')
            if (-not [string]::IsNullOrWhiteSpace($commandText)) {
                $commands.Add($commandText) | Out-Null
            }
        }
    }

    return @($commands | Select-Object -Unique)
}

# Reads the normalized request text from the orchestration artifact map.
function Get-NormalizedRequestText {
    param([hashtable] $ArtifactMap)

    if ($null -eq $ArtifactMap -or -not $ArtifactMap.ContainsKey('normalized-request')) {
        return ''
    }

    $path = [string] $ArtifactMap['normalized-request']
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return ''
    }

    return (Get-Content -Raw -LiteralPath $path)
}

# Tests whether a policy rule applies to the current stage/agent context.
function Test-PolicyRuleAppliesToContext {
    param(
        [object] $Rule,
        [string] $StageId,
        [string] $AgentId,
        [string] $StageMode
    )

    $stageIds = @((Get-HardeningOptionalValue -Object $Rule -PropertyName 'stageIds' -DefaultValue @()) | ForEach-Object { [string] $_ })
    $agentIds = @((Get-HardeningOptionalValue -Object $Rule -PropertyName 'agentIds' -DefaultValue @()) | ForEach-Object { [string] $_ })
    $modes = @((Get-HardeningOptionalValue -Object $Rule -PropertyName 'modes' -DefaultValue @()) | ForEach-Object { [string] $_ })

    if ($stageIds.Count -gt 0 -and -not ($stageIds -contains $StageId)) { return $false }
    if ($agentIds.Count -gt 0 -and -not ($agentIds -contains $AgentId)) { return $false }
    if ($modes.Count -gt 0 -and -not ($modes -contains $StageMode)) { return $false }

    return $true
}

# Evaluates pre/post stage policy rules and returns warning/block outcomes.
function Invoke-StagePolicyEvaluation {
    param(
        [Parameter(Mandatory = $true)][object] $Catalog,
        [Parameter(Mandatory = $true)][ValidateSet('pre-stage', 'post-stage')][string] $Phase,
        [Parameter(Mandatory = $true)][string] $TraceId,
        [Parameter(Mandatory = $true)][string] $StageId,
        [Parameter(Mandatory = $true)][string] $AgentId,
        [Parameter(Mandatory = $true)][string] $StageMode,
        [Parameter(Mandatory = $true)][string] $EffectiveModel,
        [Parameter(Mandatory = $true)][string] $RequestText,
        [string] $NormalizedRequestText = '',
        [string[]] $PlannedCommands = @(),
        [string[]] $ChangedPaths = @(),
        [bool] $ApprovalRequired = $false,
        [bool] $ApprovalSatisfied = $true
    )

    $evaluations = New-Object System.Collections.Generic.List[object]
    $blocked = $false

    foreach ($rule in @((Get-HardeningOptionalValue -Object $Catalog -PropertyName 'rules' -DefaultValue @()))) {
        $rulePhase = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'phase' -DefaultValue '')
        if ($rulePhase -ne $Phase) { continue }
        if (-not (Test-PolicyRuleAppliesToContext -Rule $rule -StageId $StageId -AgentId $AgentId -StageMode $StageMode)) { continue }

        $kind = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'kind' -DefaultValue '')
        $action = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'action' -DefaultValue 'warn')
        $pattern = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'pattern' -DefaultValue '')
        $values = @((Get-HardeningOptionalValue -Object $rule -PropertyName 'values' -DefaultValue @()) | ForEach-Object { [string] $_ })
        $caseSensitive = [bool] (Get-HardeningOptionalValue -Object $rule -PropertyName 'caseSensitive' -DefaultValue $false)
        $matchedValues = New-Object System.Collections.Generic.List[string]

        switch ($kind) {
            'request-pattern' {
                $combinedRequest = ((@($RequestText, $NormalizedRequestText) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine)
                if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                    $options = if ($caseSensitive) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
                    if ([System.Text.RegularExpressions.Regex]::IsMatch($combinedRequest, $pattern, $options)) {
                        $matchedValues.Add('request-text') | Out-Null
                    }
                }
            }
            'planned-command-pattern' {
                if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                    $options = if ($caseSensitive) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
                    foreach ($commandText in @($PlannedCommands)) {
                        if ([System.Text.RegularExpressions.Regex]::IsMatch([string] $commandText, $pattern, $options)) {
                            $matchedValues.Add([string] $commandText) | Out-Null
                        }
                    }
                }
            }
            'changed-path-pattern' {
                if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                    $options = if ($caseSensitive) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
                    foreach ($changedPath in @($ChangedPaths)) {
                        if ([System.Text.RegularExpressions.Regex]::IsMatch([string] $changedPath, $pattern, $options)) {
                            $matchedValues.Add([string] $changedPath) | Out-Null
                        }
                    }
                }
            }
            'model-pattern' {
                if (-not [string]::IsNullOrWhiteSpace($pattern)) {
                    $options = if ($caseSensitive) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
                    if ([System.Text.RegularExpressions.Regex]::IsMatch($EffectiveModel, $pattern, $options)) {
                        $matchedValues.Add($EffectiveModel) | Out-Null
                    }
                }
            }
            'approval-state' {
                $approvalState = if ($ApprovalRequired -and -not $ApprovalSatisfied) { 'required-unsatisfied' } elseif ($ApprovalRequired -and $ApprovalSatisfied) { 'required-satisfied' } else { 'not-required' }
                if ($values -contains $approvalState) {
                    $matchedValues.Add($approvalState) | Out-Null
                }
            }
        }

        if ($matchedValues.Count -eq 0) { continue }
        if ($action -eq 'block') { $blocked = $true }

        $evaluations.Add([ordered]@{
            traceId = $TraceId
            stageId = $StageId
            agentId = $AgentId
            phase = $Phase
            ruleId = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'id' -DefaultValue '')
            kind = $kind
            action = $action
            message = [string] (Get-HardeningOptionalValue -Object $rule -PropertyName 'message' -DefaultValue '')
            matchedValues = @($matchedValues.ToArray())
            evaluatedAt = (Get-Date).ToString('o')
        }) | Out-Null
    }

    return [ordered]@{
        blocked = $blocked
        evaluations = @($evaluations.ToArray())
        warningCount = @($evaluations | Where-Object { $_.action -eq 'warn' }).Count
        blockCount = @($evaluations | Where-Object { $_.action -eq 'block' }).Count
    }
}

# Creates the initial trace record scaffold for a pipeline run.
function Initialize-TraceRecord {
    param([string] $TraceId, [string] $PipelineId, [datetime] $StartedAt)

    return [ordered]@{
        traceId = $TraceId
        pipelineId = $PipelineId
        startedAt = $StartedAt.ToString('o')
        updatedAt = $StartedAt.ToString('o')
        status = 'running'
        stages = @()
        summary = [ordered]@{
            stageCount = 0
            blockedPolicyCount = 0
            warningPolicyCount = 0
            totalDispatchCount = 0
            totalDurationMs = 0
        }
    }
}

# Appends a stage trace entry and refreshes aggregate summary counters.
function Add-TraceStageEntry {
    param([object] $TraceRecord, [object] $StageEntry)

    $TraceRecord.stages += $StageEntry
    $TraceRecord.updatedAt = (Get-Date).ToString('o')
    $TraceRecord.summary.stageCount = @($TraceRecord.stages).Count
    $TraceRecord.summary.blockedPolicyCount = @($TraceRecord.stages | ForEach-Object { [int] $_.policy.blockCount } | Measure-Object -Sum).Sum
    $TraceRecord.summary.warningPolicyCount = @($TraceRecord.stages | ForEach-Object { [int] $_.policy.warningCount } | Measure-Object -Sum).Sum
    $TraceRecord.summary.totalDispatchCount = @($TraceRecord.stages | ForEach-Object { [int] $_.dispatch.dispatchCount } | Measure-Object -Sum).Sum
    $TraceRecord.summary.totalDurationMs = @($TraceRecord.stages | ForEach-Object { [int] $_.durationMs } | Measure-Object -Sum).Sum
}

# Creates the initial checkpoint state scaffold for a pipeline run.
function Initialize-CheckpointState {
    param([string] $TraceId, [string] $PipelineId, [datetime] $StartedAt)

    return [ordered]@{
        traceId = $TraceId
        pipelineId = $PipelineId
        startedAt = $StartedAt.ToString('o')
        updatedAt = $StartedAt.ToString('o')
        status = 'running'
        lastSuccessfulStageId = ''
        resumableFromStageId = ''
        stages = @()
    }
}

# Updates checkpoint state for one stage and advances the resumable pointer.
function Set-CheckpointStageStatus {
    param(
        [object] $CheckpointState,
        [string] $StageId,
        [int] $StageIndex,
        [string] $Status,
        [bool] $CheckpointEligible,
        [string] $NextStageId
    )

    $remainingStages = @($CheckpointState.stages | Where-Object { $_.stageId -ne $StageId })
    $remainingStages += [ordered]@{
        stageId = $StageId
        stageIndex = $StageIndex
        status = $Status
        checkpointEligible = $CheckpointEligible
        updatedAt = (Get-Date).ToString('o')
    }

    $CheckpointState.stages = @($remainingStages | Sort-Object stageIndex)
    $CheckpointState.updatedAt = (Get-Date).ToString('o')

    if ($Status -eq 'success' -and $CheckpointEligible) {
        $CheckpointState.lastSuccessfulStageId = $StageId
        $CheckpointState.resumableFromStageId = $NextStageId
    }

    if ([string]::IsNullOrWhiteSpace($NextStageId) -and $Status -eq 'success') {
        $CheckpointState.resumableFromStageId = ''
    }
}

# Selects the next resumable stage from checkpoint state and pipeline order.
function Get-ResumeCheckpointDecision {
    param(
        [Parameter(Mandatory = $true)][object] $CheckpointState,
        [Parameter(Mandatory = $true)][object[]] $PipelineStages,
        [string] $RequestedStartStageId
    )

    $orderedStageIds = @($PipelineStages | ForEach-Object { [string] $_.id })
    if (-not [string]::IsNullOrWhiteSpace($RequestedStartStageId)) {
        if (-not ($orderedStageIds -contains $RequestedStartStageId)) {
            throw ("Requested start stage is not present in the pipeline: {0}" -f $RequestedStartStageId)
        }

        return [ordered]@{
            startStageId = $RequestedStartStageId
            completedStageIds = @($CheckpointState.stages | Where-Object { $_.status -eq 'success' } | ForEach-Object { [string] $_.stageId })
        }
    }

    $resumableFrom = [string] (Get-HardeningOptionalValue -Object $CheckpointState -PropertyName 'resumableFromStageId' -DefaultValue '')
    if (-not [string]::IsNullOrWhiteSpace($resumableFrom)) {
        return [ordered]@{
            startStageId = $resumableFrom
            completedStageIds = @($CheckpointState.stages | Where-Object { $_.status -eq 'success' } | ForEach-Object { [string] $_.stageId })
        }
    }

    throw 'Checkpoint state does not declare a resumableFromStageId.'
}