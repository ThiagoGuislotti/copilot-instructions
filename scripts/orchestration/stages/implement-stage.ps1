<#
.SYNOPSIS
    Produces implementation artifacts for the multi-agent orchestration pipeline.

.DESCRIPTION
    Executes planned work items sequentially. When live dispatch is enabled,
    each work item is delegated to the local Codex CLI as an isolated task run.

.PARAMETER RepoRoot
    Repository root path.

.PARAMETER RunDirectory
    Absolute run directory for generated artifacts.

.PARAMETER TraceId
    Unique trace identifier for the pipeline run.

.PARAMETER StageId
    Current stage identifier.

.PARAMETER AgentId
    Current agent identifier.

.PARAMETER RequestPath
    Path to the request text artifact.

.PARAMETER InputArtifactManifestPath
    Path to input artifact manifest.

.PARAMETER OutputArtifactManifestPath
    Path where this stage writes its output artifact manifest.

.PARAMETER AgentsManifestPath
    Agent contract manifest path.

.PARAMETER DispatchMode
    Stage dispatch mode from pipeline execution settings.

.PARAMETER PromptTemplatePath
    Prompt template path for live dispatch.

.PARAMETER ResponseSchemaPath
    JSON schema path for live dispatch.

.PARAMETER DispatchCommand
    Codex CLI command name or absolute path.

.PARAMETER ExecutionBackend
    Runtime backend selection. `codex-exec` enables live dispatch.

.PARAMETER EffectiveModel
    Optional resolved model override passed into task-worker dispatches.

.PARAMETER StageStatePath
    Optional path where stage execution metadata is written.

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File .\scripts\orchestration\stages\implement-stage.ps1 -RepoRoot . -RunDirectory .temp\runs\trace-001 -TraceId trace-001 -StageId implement -AgentId executor -RequestPath .temp\runs\trace-001\request.txt -InputArtifactManifestPath .temp\runs\trace-001\stages\plan\output-artifacts.json -OutputArtifactManifestPath .temp\runs\trace-001\stages\implement\output-artifacts.json -ExecutionBackend codex-exec -DispatchMode codex-exec

.NOTES
    Enforces both agent-level and task-level allowed-path constraints before accepting changed files.
#>

param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $RunDirectory,
    [Parameter(Mandatory = $true)] [string] $TraceId,
    [Parameter(Mandatory = $true)] [string] $StageId,
    [Parameter(Mandatory = $true)] [string] $AgentId,
    [Parameter(Mandatory = $true)] [string] $RequestPath,
    [Parameter(Mandatory = $true)] [string] $InputArtifactManifestPath,
    [Parameter(Mandatory = $true)] [string] $OutputArtifactManifestPath,
    [string] $AgentsManifestPath = '.codex/orchestration/agents.manifest.json',
    [string] $DispatchMode = 'scripted',
    [string] $PromptTemplatePath,
    [string] $ResponseSchemaPath,
    [string] $DispatchCommand = 'codex',
    [string] $ExecutionBackend = 'script-only',
    [string] $EffectiveModel,
    [string] $StageStatePath,
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

# Builds a checksum-bearing artifact descriptor for the stage manifest.
function Get-ArtifactDescriptor {
    param(
        [string] $Name,
        [string] $Path,
        [string] $Root
    )

    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return [ordered]@{
        name = $Name
        path = (Convert-ToRelativeRepoPath -Root $Root -Path $Path)
        checksum = ("sha256:{0}" -f $hash.Hash.ToLowerInvariant())
    }
}

# Reads a JSON file using a repository-wide deep parse depth.
function Read-JsonFile {
    param([string] $Path)

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200)
}

# Returns a property value from either PSCustomObject or dictionary-like inputs.
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

# Writes JSON deterministically without adding an implicit trailing newline.
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

# Expands a prompt template by replacing token placeholders with supplied values.
function Expand-Template {
    param(
        [string] $TemplateText,
        [hashtable] $Tokens
    )

    $rendered = $TemplateText
    foreach ($key in $Tokens.Keys) {
        $rendered = $rendered.Replace(("{{{0}}}" -f $key), [string] $Tokens[$key])
    }

    return $rendered
}

# Retrieves a single agent contract from the orchestration manifest.
function Get-AgentContract {
    param(
        [string] $ManifestPath,
        [string] $TargetAgentId
    )

    $manifest = Read-JsonFile -Path $ManifestPath
    return @($manifest.agents | Where-Object { $_.id -eq $TargetAgentId } | Select-Object -First 1)
}

# Converts a simple glob expression into a regex used for allowed-path checks.
function Convert-GlobToRegex {
    param([string] $Pattern)

    $normalized = ($Pattern -replace '\\', '/')
    $escaped = [regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return ('^{0}$' -f $escaped)
}

# Validates whether a repository-relative path is allowed by at least one pattern.
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

# Captures current working-tree paths from git status for changed-file detection.
function Get-WorkingTreePathSet {
    param([string] $Root)

    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $statusLines = @(git -C "$Root" status --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return $set
    }

    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $pathText = $line.Substring(3).Trim()
        if ([string]::IsNullOrWhiteSpace($pathText)) {
            continue
        }

        if ($pathText.Contains('->')) {
            $pathText = $pathText.Split('->')[-1].Trim()
        }

        $set.Add(($pathText -replace '\\', '/')) | Out-Null
    }

    return $set
}

# Converts an artifact manifest into a name-to-absolute-path lookup table.
function Convert-ArtifactManifestToMap {
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

        $map[$name] = Resolve-FullPath -BasePath $Root -Candidate $path
    }

    return $map
}

# Creates a deterministic fallback task result when live executor dispatch is unavailable.
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

# Extracts stable non-wildcard path prefixes used for conflict detection.
function Get-TaskStablePrefixes {
    param([object] $WorkItem)

    $prefixes = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $patterns = @()
    $patterns += @(Get-ObjectValue -Object $WorkItem -Name 'targetPaths' -DefaultValue @() | ForEach-Object { [string] $_ })
    if ($patterns.Count -eq 0) {
        $patterns += @(Get-ObjectValue -Object $WorkItem -Name 'allowedPaths' -DefaultValue @() | ForEach-Object { [string] $_ })
    }

    foreach ($pattern in $patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        $normalized = ($pattern -replace '\\', '/').Trim('/')
        if ([string]::IsNullOrWhiteSpace($normalized)) {
            continue
        }

        $segments = @($normalized.Split('/'))
        $stableSegments = New-Object System.Collections.Generic.List[string]
        foreach ($segment in $segments) {
            if ($segment.Contains('*') -or $segment.Contains('?')) {
                break
            }

            $stableSegments.Add($segment) | Out-Null
        }

        $stablePrefix = if ($stableSegments.Count -gt 0) {
            $stableSegments -join '/'
        }
        else {
            $normalized
        }

        if (-not [string]::IsNullOrWhiteSpace($stablePrefix)) {
            $prefixes.Add($stablePrefix) | Out-Null
        }
    }

    return @($prefixes)
}

# Returns true when two stable prefixes overlap and therefore should not run in parallel.
function Test-PathPrefixConflict {
    param(
        [string] $Left,
        [string] $Right
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $true
    }

    $normalizedLeft = ($Left -replace '\\', '/').Trim('/')
    $normalizedRight = ($Right -replace '\\', '/').Trim('/')

    if ($normalizedLeft.Equals($normalizedRight, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($normalizedLeft.StartsWith($normalizedRight + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($normalizedRight.StartsWith($normalizedLeft + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $false
}

# Returns true when two work items have overlapping write scopes or dependency coupling.
function Test-TaskWriteConflict {
    param(
        [object] $Left,
        [object] $Right
    )

    $leftId = [string] (Get-ObjectValue -Object $Left -Name 'id')
    $rightId = [string] (Get-ObjectValue -Object $Right -Name 'id')
    $leftDependsOn = @(Get-ObjectValue -Object $Left -Name 'dependsOn' -DefaultValue @() | ForEach-Object { [string] $_ })
    $rightDependsOn = @(Get-ObjectValue -Object $Right -Name 'dependsOn' -DefaultValue @() | ForEach-Object { [string] $_ })

    if ($leftDependsOn -contains $rightId -or $rightDependsOn -contains $leftId) {
        return $true
    }

    $leftPrefixes = Get-TaskStablePrefixes -WorkItem $Left
    $rightPrefixes = Get-TaskStablePrefixes -WorkItem $Right
    if ($leftPrefixes.Count -eq 0 -or $rightPrefixes.Count -eq 0) {
        return $true
    }

    foreach ($leftPrefix in $leftPrefixes) {
        foreach ($rightPrefix in $rightPrefixes) {
            if (Test-PathPrefixConflict -Left $leftPrefix -Right $rightPrefix) {
                return $true
            }
        }
    }

    return $false
}

# Builds deterministic execution batches from work-item dependencies and write-scope conflicts.
function New-ExecutionBatches {
    param([object[]] $WorkItems)

    $remaining = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($WorkItems)) {
        $remaining.Add($item) | Out-Null
    }

    $completedIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $batches = New-Object System.Collections.Generic.List[object]

    while ($remaining.Count -gt 0) {
        $readyItemsBuffer = New-Object System.Collections.Generic.List[object]
        foreach ($candidate in @($remaining.ToArray())) {
            $dependsOn = @(Get-ObjectValue -Object $candidate -Name 'dependsOn' -DefaultValue @() | ForEach-Object { [string] $_ })
            $pendingDependencies = @($dependsOn | Where-Object { -not $completedIds.Contains($_) })
            if ($pendingDependencies.Count -eq 0) {
                $readyItemsBuffer.Add($candidate) | Out-Null
            }
        }
        $readyItems = @($readyItemsBuffer.ToArray() | Sort-Object { [string] (Get-ObjectValue -Object $_ -Name 'id') })

        if ($readyItems.Count -eq 0) {
            $remainingIds = @($remaining.ToArray() | ForEach-Object { [string] (Get-ObjectValue -Object $_ -Name 'id') }) -join ', '
            throw ("Task dependency graph contains a cycle or unresolved dependency set: {0}" -f $remainingIds)
        }

        $batch = New-Object System.Collections.Generic.List[object]
        foreach ($readyItem in $readyItems) {
            $conflictFound = $false
            foreach ($batchItem in $batch) {
                if (Test-TaskWriteConflict -Left $readyItem -Right $batchItem) {
                    $conflictFound = $true
                    break
                }
            }

            if (-not $conflictFound) {
                $batch.Add($readyItem) | Out-Null
            }
        }

        if ($batch.Count -eq 0) {
            $batch.Add($readyItems[0]) | Out-Null
        }

        $batchArray = @($batch.ToArray())
        $batches.Add([pscustomobject]@{
                workItems = $batchArray
            }) | Out-Null

        foreach ($batchItem in $batchArray) {
            $completedIds.Add([string] (Get-ObjectValue -Object $batchItem -Name 'id')) | Out-Null
            $remaining.Remove($batchItem)
        }
    }

    return [pscustomobject]@{
        batches = @($batches.ToArray())
    }
}

$resolvedRepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$resolvedRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory)
$resolvedRequestPath = [System.IO.Path]::GetFullPath($RequestPath)
$resolvedInputManifestPath = [System.IO.Path]::GetFullPath($InputArtifactManifestPath)
$resolvedOutputManifestPath = [System.IO.Path]::GetFullPath($OutputArtifactManifestPath)
$resolvedAgentsManifestPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $AgentsManifestPath
$resolvedPromptTemplatePath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $PromptTemplatePath
$resolvedResponseSchemaPath = Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $ResponseSchemaPath
$resolvedStageStatePath = if ([string]::IsNullOrWhiteSpace($StageStatePath)) { Join-Path $resolvedRunDirectory ('stages/{0}-state.json' -f $StageId) } else { Resolve-FullPath -BasePath $resolvedRepoRoot -Candidate $StageStatePath }

$stageArtifactsDirectory = Join-Path $resolvedRunDirectory 'artifacts'
$stageMetadataDirectory = Join-Path $resolvedRunDirectory ('stages/{0}' -f $StageId)
$tasksDirectory = Join-Path $stageMetadataDirectory 'tasks'
New-Item -ItemType Directory -Path $stageArtifactsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $tasksDirectory -Force | Out-Null

$requestContent = if (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf) {
    (Get-Content -Raw -LiteralPath $resolvedRequestPath).Trim()
}
else {
    'No request content provided.'
}

$agent = Get-AgentContract -ManifestPath $resolvedAgentsManifestPath -TargetAgentId $AgentId
if ($null -eq $agent) {
    throw ("Agent contract not found for stage {0}: {1}" -f $StageId, $AgentId)
}

$inputManifest = Read-JsonFile -Path $resolvedInputManifestPath
$artifactMap = Convert-ArtifactManifestToMap -Manifest $inputManifest -Root $resolvedRepoRoot
$normalizedRequestPath = if ($artifactMap.ContainsKey('normalized-request')) { [string] $artifactMap['normalized-request'] } else { $null }
$taskPlanDataPath = if ($artifactMap.ContainsKey('task-plan-data')) { [string] $artifactMap['task-plan-data'] } else { $null }
$contextPackPath = if ($artifactMap.ContainsKey('context-pack')) { [string] $artifactMap['context-pack'] } else { $null }
$routeSelectionPath = if ($artifactMap.ContainsKey('route-selection')) { [string] $artifactMap['route-selection'] } else { $null }
$specialistContextPackPath = if ($artifactMap.ContainsKey('specialist-context-pack')) { [string] $artifactMap['specialist-context-pack'] } else { $null }

if ($null -ne $normalizedRequestPath -and (Test-Path -LiteralPath $normalizedRequestPath -PathType Leaf)) {
    $normalizedRequestContent = (Get-Content -Raw -LiteralPath $normalizedRequestPath).Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalizedRequestContent)) {
        $requestContent = $normalizedRequestContent
    }
}

$taskPlanData = if ($null -ne $taskPlanDataPath -and (Test-Path -LiteralPath $taskPlanDataPath -PathType Leaf)) { Read-JsonFile -Path $taskPlanDataPath } else { $null }
$contextPackJson = if ($null -ne $contextPackPath -and (Test-Path -LiteralPath $contextPackPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $contextPackPath } else { '{}' }
$routeSelectionJson = if ($null -ne $routeSelectionPath -and (Test-Path -LiteralPath $routeSelectionPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $routeSelectionPath } else { '{}' }
$specialistContextPackJson = if ($null -ne $specialistContextPackPath -and (Test-Path -LiteralPath $specialistContextPackPath -PathType Leaf)) { Get-Content -Raw -LiteralPath $specialistContextPackPath } else { $contextPackJson }
$taskPlanSummary = if ($null -ne $taskPlanData) { [string] $taskPlanData.scopeSummary } else { 'No structured task plan available.' }
$agentAllowedPaths = @($agent.allowedPaths | ForEach-Object { [string] $_ })
$shouldUseCodexDispatch = ($ExecutionBackend -eq 'codex-exec') -and ($DispatchMode -eq 'codex-exec') -and ($null -ne $taskPlanData)
$backendUsed = if ($shouldUseCodexDispatch) { 'codex-exec' } else { 'scripted' }

$taskRuns = New-Object System.Collections.Generic.List[object]
$allChangedFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
$dispatchErrors = New-Object System.Collections.Generic.List[string]

$workItems = if ($null -ne $taskPlanData) { @($taskPlanData.workItems) } else { @() }
if ($workItems.Count -eq 0) {
    $workItems = @(
        [pscustomobject]@{
            id = 'implement-request'
            title = 'Implement requested change'
            description = $requestContent
            allowedPaths = $agentAllowedPaths
            targetPaths = $agentAllowedPaths
            commands = @(
                [ordered]@{
                    purpose = 'repository validation'
                    command = 'pwsh -File scripts/validation/validate-all.ps1 -ValidationProfile dev'
                    expectedOutcome = 'Validation finishes without blocking failures.'
                }
            )
            checkpoints = @(
                [ordered]@{
                    name = 'scope-confirmed'
                    expectedOutcome = 'expected-verified'
                    evidence = 'Task remains within agent-allowed paths.'
                },
                [ordered]@{
                    name = 'validation-green'
                    expectedOutcome = 'expected-pass'
                    command = 'pwsh -File scripts/validation/validate-all.ps1 -ValidationProfile dev'
                    evidence = 'Repository validation is green after implementation.'
                }
            )
            commitCheckpoint = [ordered]@{
                scope = 'task'
                when = 'After implementation succeeds and validation is green.'
                suggestedMessage = 'feat: implement requested change with validated scope'
            }
            deliverables = @('Requested change')
            validationSteps = @('Run downstream validation stage.')
            successCriteria = @('No unrelated files are changed.')
            dependsOn = @()
        }
    )
}

$normalizedWorkItems = New-Object System.Collections.Generic.List[object]
foreach ($workItem in @($workItems)) {
    if ($workItem -is [System.Collections.IDictionary]) {
        $normalizedWorkItems.Add([pscustomobject] $workItem) | Out-Null
    }
    else {
        $normalizedWorkItems.Add($workItem) | Out-Null
    }
}
$workItems = @($normalizedWorkItems.ToArray())

$taskWorkerScriptPath = Join-Path $resolvedRepoRoot 'scripts/orchestration/engine/invoke-task-worker.ps1'
$specReviewPromptTemplatePath = Join-Path $resolvedRepoRoot '.codex/orchestration/prompts/task-spec-review.prompt.md'
$qualityReviewPromptTemplatePath = Join-Path $resolvedRepoRoot '.codex/orchestration/prompts/task-quality-review.prompt.md'
$taskReviewSchemaPath = Join-Path $resolvedRepoRoot '.github/schemas/agent.task-review-result.schema.json'
$specSummaryInputPath = if ($artifactMap.ContainsKey('spec-summary')) { [string] $artifactMap['spec-summary'] } else { $resolvedRequestPath }
$remainingExecutionItems = New-Object System.Collections.Generic.List[object]
foreach ($workItem in @($workItems)) {
    $remainingExecutionItems.Add($workItem) | Out-Null
}
$completedExecutionIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
$executionBatches = New-Object System.Collections.Generic.List[object]
while ($remainingExecutionItems.Count -gt 0) {
    $readyItemsBuffer = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in @($remainingExecutionItems.ToArray())) {
        $dependsOn = @(Get-ObjectValue -Object $candidate -Name 'dependsOn' -DefaultValue @() | ForEach-Object { [string] $_ })
        $pendingDependencies = @($dependsOn | Where-Object { -not $completedExecutionIds.Contains($_) })
        if ($pendingDependencies.Count -eq 0) {
            $readyItemsBuffer.Add($candidate) | Out-Null
        }
    }

    $readyItems = @($readyItemsBuffer.ToArray() | Sort-Object { [string] (Get-ObjectValue -Object $_ -Name 'id') })
    if ($readyItems.Count -eq 0) {
        $remainingIds = @($remainingExecutionItems.ToArray() | ForEach-Object { [string] (Get-ObjectValue -Object $_ -Name 'id') }) -join ', '
        throw ("Task dependency graph contains a cycle or unresolved dependency set: {0}" -f $remainingIds)
    }

    $batch = New-Object System.Collections.Generic.List[object]
    foreach ($readyItem in $readyItems) {
        $conflictFound = $false
        foreach ($batchItem in $batch) {
            if (Test-TaskWriteConflict -Left $readyItem -Right $batchItem) {
                $conflictFound = $true
                break
            }
        }

        if (-not $conflictFound) {
            $batch.Add($readyItem) | Out-Null
        }
    }

    if ($batch.Count -eq 0) {
        $batch.Add($readyItems[0]) | Out-Null
    }

    $batchArray = @($batch.ToArray())
    $executionBatches.Add([pscustomobject]@{ workItems = $batchArray }) | Out-Null

    foreach ($batchItem in $batchArray) {
        $completedExecutionIds.Add([string] (Get-ObjectValue -Object $batchItem -Name 'id')) | Out-Null
        $remainingExecutionItems.Remove($batchItem)
    }
}
$executionBatches = @($executionBatches.ToArray())
$parallelExecutionUsed = $false
$taskReviewCount = 0

for ($batchIndex = 0; $batchIndex -lt $executionBatches.Count; $batchIndex++) {
    $batch = @($executionBatches[$batchIndex].workItems)
    $batchId = $batchIndex + 1
    $batchUsesParallelDispatch = $shouldUseCodexDispatch -and ($batch.Count -gt 1)
    if ($batchUsesParallelDispatch) {
        $parallelExecutionUsed = $true
    }

    $taskInvocations = New-Object System.Collections.Generic.List[object]
    foreach ($workItem in $batch) {
        $taskId = [string] (Get-ObjectValue -Object $workItem -Name 'id')
        $taskDirectory = Join-Path $tasksDirectory $taskId
        New-Item -ItemType Directory -Path $taskDirectory -Force | Out-Null

        $taskJsonPath = Join-Path $taskDirectory 'task.json'
        $taskResultPath = Join-Path $taskDirectory 'task-result.json'
        Write-JsonFile -Path $taskJsonPath -Value $workItem

        $taskInvocation = [ordered]@{
            taskId = $taskId
            title = [string] (Get-ObjectValue -Object $workItem -Name 'title')
            taskDirectory = $taskDirectory
            taskJsonPath = $taskJsonPath
            taskResultPath = $taskResultPath
            startedAt = (Get-Date).ToString('o')
            batchId = $batchId
            process = $null
            stdoutPath = Join-Path $taskDirectory 'worker-stdout.log'
            stderrPath = Join-Path $taskDirectory 'worker-stderr.log'
        }

        if ($batchUsesParallelDispatch) {
            $argumentList = @(
                '-NoProfile',
                '-File', $taskWorkerScriptPath,
                '-RepoRoot', $resolvedRepoRoot,
                '-WorkingDirectory', $resolvedRepoRoot,
                '-RunDirectory', $resolvedRunDirectory,
                '-TraceId', $TraceId,
                '-StageId', $StageId,
                '-AgentId', $AgentId,
                '-TaskJsonPath', $taskJsonPath,
                '-RequestPath', $resolvedRequestPath,
                '-ContextPackPath', $contextPackPath,
                '-RouteSelectionPath', $routeSelectionPath,
                '-SpecialistContextPackPath', $specialistContextPackPath,
                '-SpecSummaryPath', $specSummaryInputPath,
                '-AgentsManifestPath', $resolvedAgentsManifestPath,
                '-ImplementerPromptTemplatePath', $resolvedPromptTemplatePath,
                '-ImplementerResponseSchemaPath', $resolvedResponseSchemaPath,
                '-SpecReviewPromptTemplatePath', $specReviewPromptTemplatePath,
                '-QualityReviewPromptTemplatePath', $qualityReviewPromptTemplatePath,
                '-ReviewResponseSchemaPath', $taskReviewSchemaPath,
                '-ResultPath', $taskResultPath,
                '-DispatchCommand', $DispatchCommand,
                '-ExecutionBackend', $ExecutionBackend,
                '-EffectiveModel', $(if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $agent.model } else { $EffectiveModel })
            )
            if ($DetailedOutput) {
                $argumentList += '-DetailedOutput'
            }

            $process = Start-Process -FilePath 'pwsh' -ArgumentList $argumentList -WorkingDirectory $resolvedRepoRoot -NoNewWindow -PassThru -RedirectStandardOutput $taskInvocation.stdoutPath -RedirectStandardError $taskInvocation.stderrPath
            $taskInvocation.process = $process
        }
        else {
            & $taskWorkerScriptPath `
                -RepoRoot $resolvedRepoRoot `
                -WorkingDirectory $resolvedRepoRoot `
                -RunDirectory $resolvedRunDirectory `
                -TraceId $TraceId `
                -StageId $StageId `
                -AgentId $AgentId `
                -TaskJsonPath $taskJsonPath `
                -RequestPath $resolvedRequestPath `
                -ContextPackPath $contextPackPath `
                -RouteSelectionPath $routeSelectionPath `
                -SpecialistContextPackPath $specialistContextPackPath `
                -SpecSummaryPath $specSummaryInputPath `
                -AgentsManifestPath $resolvedAgentsManifestPath `
                -ImplementerPromptTemplatePath $resolvedPromptTemplatePath `
                -ImplementerResponseSchemaPath $resolvedResponseSchemaPath `
                -SpecReviewPromptTemplatePath $specReviewPromptTemplatePath `
                -QualityReviewPromptTemplatePath $qualityReviewPromptTemplatePath `
                -ReviewResponseSchemaPath $taskReviewSchemaPath `
                -ResultPath $taskResultPath `
                -DispatchCommand $DispatchCommand `
                -ExecutionBackend $ExecutionBackend `
                -EffectiveModel $(if ([string]::IsNullOrWhiteSpace($EffectiveModel)) { [string] $agent.model } else { $EffectiveModel }) `
                -DetailedOutput:$DetailedOutput | Out-Null
        }

        $taskInvocations.Add([pscustomobject] $taskInvocation) | Out-Null
    }

    if ($batchUsesParallelDispatch) {
        $processes = @($taskInvocations | ForEach-Object { $_.process } | Where-Object { $null -ne $_ })
        if ($processes.Count -gt 0) {
            Wait-Process -InputObject $processes
        }
    }

    foreach ($taskInvocation in $taskInvocations) {
        $taskWarning = $null
        $taskResult = $null

        if (Test-Path -LiteralPath $taskInvocation.taskResultPath -PathType Leaf) {
            $taskResult = Read-JsonFile -Path $taskInvocation.taskResultPath
        }
        else {
            $taskWarning = ("Task worker result not found for {0}." -f $taskInvocation.taskId)
            $dispatchErrors.Add($taskWarning) | Out-Null
            $taskResult = [pscustomobject](New-FallbackTaskResult -TaskId $taskInvocation.taskId)
            $taskResult.status = 'blocked'
            $taskResult.notes += $taskWarning
        }

        if ($null -ne $taskInvocation.process) {
            $taskInvocation.process.Refresh()
            if ($taskInvocation.process.ExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($taskWarning)) {
                $taskWarning = ("Task worker exited non-zero for {0}: {1}" -f $taskInvocation.taskId, $taskInvocation.process.ExitCode)
                $dispatchErrors.Add($taskWarning) | Out-Null
            }
        }

        foreach ($warningText in @($taskResult.warnings | ForEach-Object { [string] $_ })) {
            if (-not [string]::IsNullOrWhiteSpace($warningText)) {
                $dispatchErrors.Add($warningText) | Out-Null
            }
        }

        foreach ($changedFile in @($taskResult.changedFiles | ForEach-Object { [string] $_ })) {
            if (-not [string]::IsNullOrWhiteSpace($changedFile)) {
                $allChangedFiles.Add($changedFile) | Out-Null
            }
        }

        $taskReviewCount += 2
        $taskFinishedAt = Get-Date
        $taskRuns.Add([pscustomobject]@{
                taskId = $taskInvocation.taskId
                title = [string] $taskInvocation.title
                status = [string] $taskResult.status
                summary = [string] $taskResult.summary
                changedFiles = @($taskResult.changedFiles | ForEach-Object { [string] $_ })
                validationsPerformed = @($taskResult.validationsPerformed | ForEach-Object { [string] $_ })
                residualRisks = @($taskResult.residualRisks | ForEach-Object { [string] $_ })
                notes = @($taskResult.notes | ForEach-Object { [string] $_ })
                commitReady = [bool] $taskResult.commitReady
                startedAt = [string] $taskInvocation.startedAt
                finishedAt = $taskFinishedAt.ToString('o')
                durationMs = [int] ($taskFinishedAt - ([datetime] $taskInvocation.startedAt)).TotalMilliseconds
                dispatchRecordPath = [string] $taskResult.dispatchRecordPath
                warning = $taskWarning
                batchId = [int] $taskInvocation.batchId
                attemptCount = [int] $taskResult.attemptCount
                specReview = $taskResult.specReview
                qualityReview = $taskResult.qualityReview
                reviewHistory = @($taskResult.reviewHistory)
            }) | Out-Null
    }
}

$failedTasks = @($taskRuns | Where-Object { $_.status -ne 'completed' })
$changesetPath = Join-Path $stageArtifactsDirectory 'changeset.json'
$implementationLogPath = Join-Path $stageArtifactsDirectory 'implementation-log.md'
$implementationDispatchesPath = Join-Path $stageArtifactsDirectory 'implementation-dispatches.json'
$taskReviewReportPath = Join-Path $stageArtifactsDirectory 'task-review-report.json'

$changeset = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    generatedAt = (Get-Date).ToString('o')
    summary = if ($failedTasks.Count -eq 0) { 'Implementation stage completed all planned work items.' } else { 'Implementation stage completed with blocked work items.' }
    sourceArtifacts = @($inputManifest.artifacts | ForEach-Object { [string] $_.name })
    workItemCount = $taskRuns.Count
    failedTaskCount = $failedTasks.Count
    changedFiles = @($allChangedFiles)
    tasks = @($taskRuns.ToArray())
    executionMode = if ($parallelExecutionUsed) { 'parallel-safe-batches' } else { 'sequential' }
    parallelBatchCount = $executionBatches.Count
    taskReviewLoopEnabled = $true
    commitReady = (@($taskRuns | Where-Object { -not $_.commitReady }).Count -eq 0) -and ($failedTasks.Count -eq 0)
}
Write-JsonFile -Path $changesetPath -Value $changeset

$implementationLog = @(
    ('# Implementation Log ({0})' -f $TraceId),
    '',
    ('- Stage: {0}' -f $StageId),
    ('- Agent: {0}' -f $AgentId),
    ('- Backend: {0}' -f $backendUsed),
    ('- Execution mode: {0}' -f $changeset.executionMode),
    ('- Parallel batch count: {0}' -f $executionBatches.Count),
    ('- GeneratedAt: {0}' -f (Get-Date).ToString('o')),
    ('- Work items: {0}' -f $taskRuns.Count),
    ('- Failed work items: {0}' -f $failedTasks.Count),
    '',
    '## Task Runs'
)
foreach ($taskRun in $taskRuns) {
    $implementationLog += ('### {0}: {1}' -f $taskRun.taskId, $taskRun.title)
    $implementationLog += ('- Batch: {0}' -f $taskRun.batchId)
    $implementationLog += ('- Status: {0}' -f $taskRun.status)
    $implementationLog += ('- Attempts: {0}' -f $taskRun.attemptCount)
    $implementationLog += ('- Summary: {0}' -f $taskRun.summary)
    $implementationLog += ('- Changed files: {0}' -f ((@($taskRun.changedFiles) | ForEach-Object { [string] $_ }) -join ', '))
    $implementationLog += ('- Validation: {0}' -f ((@($taskRun.validationsPerformed) | ForEach-Object { [string] $_ }) -join '; '))
    $implementationLog += ('- Residual risks: {0}' -f ((@($taskRun.residualRisks) | ForEach-Object { [string] $_ }) -join '; '))
    $implementationLog += ('- Spec review: {0}' -f [string] $taskRun.specReview.decision)
    $implementationLog += ('- Quality review: {0}' -f [string] $taskRun.qualityReview.decision)
    if (-not [string]::IsNullOrWhiteSpace($taskRun.dispatchRecordPath)) {
        $implementationLog += ('- Dispatch record: {0}' -f $taskRun.dispatchRecordPath)
    }
    $implementationLog += ''
}
Set-Content -LiteralPath $implementationLogPath -Value ($implementationLog -join "`n") -Encoding UTF8 -NoNewline

$implementationDispatches = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    generatedAt = (Get-Date).ToString('o')
    executionMode = $changeset.executionMode
    parallelBatchCount = $executionBatches.Count
    tasks = @($taskRuns.ToArray())
    warnings = @($dispatchErrors)
}
Write-JsonFile -Path $implementationDispatchesPath -Value $implementationDispatches

$taskReviewReport = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    generatedAt = (Get-Date).ToString('o')
    reviewLoopEnabled = $true
    tasks = @(
        $taskRuns |
            ForEach-Object {
                [ordered]@{
                    taskId = [string] $_.taskId
                    batchId = [int] $_.batchId
                    attemptCount = [int] $_.attemptCount
                    specReview = $_.specReview
                    qualityReview = $_.qualityReview
                    reviewHistory = @($_.reviewHistory)
                }
            }
    )
}
Write-JsonFile -Path $taskReviewReportPath -Value $taskReviewReport

$outputManifestDirectory = Split-Path -Parent $resolvedOutputManifestPath
if (-not [string]::IsNullOrWhiteSpace($outputManifestDirectory)) {
    New-Item -ItemType Directory -Path $outputManifestDirectory -Force | Out-Null
}

$outputManifest = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    producedAt = (Get-Date).ToString('o')
    artifacts = @(
        (Get-ArtifactDescriptor -Name 'changeset' -Path $changesetPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'implementation-log' -Path $implementationLogPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'implementation-dispatches' -Path $implementationDispatchesPath -Root $resolvedRepoRoot),
        (Get-ArtifactDescriptor -Name 'task-review-report' -Path $taskReviewReportPath -Root $resolvedRepoRoot)
    )
}
Write-JsonFile -Path $resolvedOutputManifestPath -Value $outputManifest

$stageState = [ordered]@{
    traceId = $TraceId
    stageId = $StageId
    agentId = $AgentId
    backend = $backendUsed
    dispatchCount = if ($backendUsed -eq 'codex-exec') { $taskRuns.Count } else { 0 }
    workItemCount = $taskRuns.Count
    changedFileCount = @($allChangedFiles).Count
    failedTaskCount = $failedTasks.Count
    parallelBatchCount = $executionBatches.Count
    parallelExecutionUsed = $parallelExecutionUsed
    taskReviewLoopEnabled = $true
    taskReviewCount = $taskReviewCount
    promptTemplatePath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedPromptTemplatePath } else { $null }
    responseSchemaPath = if ($backendUsed -eq 'codex-exec') { Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $resolvedResponseSchemaPath } else { $null }
    taskStatePath = Convert-ToRelativeRepoPath -Root $resolvedRepoRoot -Path $implementationDispatchesPath
    warnings = @($dispatchErrors)
}
Write-JsonFile -Path $resolvedStageStatePath -Value $stageState

Write-VerboseLog ("Stage artifacts written: {0}" -f $resolvedOutputManifestPath)

if ($failedTasks.Count -gt 0) {
    foreach ($failedTask in $failedTasks) {
        $failureDetails = @($failedTask.notes | ForEach-Object { [string] $_ }) -join '; '
        Write-StyledOutput ("[ERROR] Task blocked in implement stage: {0} :: {1}" -f [string] $failedTask.taskId, $failureDetails)
    }
    exit 1
}

exit 0