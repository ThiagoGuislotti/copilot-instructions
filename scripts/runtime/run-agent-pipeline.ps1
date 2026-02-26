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

.PARAMETER DetailedOutput
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate agent flow"

.EXAMPLE
    pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Validate orchestration only" -SkipGuardrails

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
    [switch] $DetailedOutput
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $DetailedOutput

# Writes verbose diagnostics with a stable prefix.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE] {0}" -f $Message)
    }
}

# Builds an absolute path from repository root and relative input path.
function Resolve-RepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

# Resolves repository root using explicit and fallback location candidates.
function Resolve-RepositoryRoot {
    param(
        [string] $RequestedRoot
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $RequestedRoot).Path
        }
        catch {
            throw "Invalid RepoRoot path: $RequestedRoot"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ScriptRoot)) {
        $candidates += (Resolve-Path -LiteralPath (Join-Path $script:ScriptRoot '..\..')).Path
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $i++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

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

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$validationScriptPath = Join-Path $resolvedRepoRoot 'scripts/validation/validate-agent-orchestration.ps1'
if (-not (Test-Path -LiteralPath $validationScriptPath -PathType Leaf)) {
    throw "Required validator not found: $validationScriptPath"
}

& $validationScriptPath -RepoRoot $resolvedRepoRoot
if ($LASTEXITCODE -ne 0) {
    throw 'Agent orchestration validation failed. Fix contracts before running pipeline.'
}

$resolvedAgentsManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AgentsManifestPath
$resolvedPipelinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $PipelinePath
$resolvedRunRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $RunRoot

$agentsManifest = Read-JsonFile -Path $resolvedAgentsManifestPath
$pipeline = Read-JsonFile -Path $resolvedPipelinePath

$trace = if ([string]::IsNullOrWhiteSpace($TraceId)) {
    "run-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
}
else {
    $TraceId
}

$runDirectory = Join-Path $resolvedRunRoot $trace
$artifactsDirectory = Join-Path $runDirectory 'artifacts'
$stagesDirectory = Join-Path $runDirectory 'stages'
$handoffsDirectory = Join-Path $runDirectory 'handoffs'

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

foreach ($stage in @($pipeline.stages)) {
    $stageId = [string] $stage.id
    $agentId = [string] $stage.agentId
    $stageMode = [string] $stage.mode
    $onFailure = [string] $stage.onFailure
    $maxAttempts = if ($onFailure -eq 'retry-once') { 2 } else { 1 }

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

    $attempt = 0
    $stageSucceeded = $false
    $lastFailureMessage = $null
    $stageStartedAt = Get-Date
    $stageFinishedAt = $stageStartedAt
    $stageDurationMs = 0
    $producedArtifactNames = @()
    $changedDelta = @()

    while ($attempt -lt $maxAttempts -and -not $stageSucceeded) {
        $attempt++
        Write-Output ("[INFO] Stage {0} (agent={1}, mode={2}) attempt {3}/{4}" -f $stageId, $agentId, $stageMode, $attempt, $maxAttempts)

        $inputMissing = @()
        foreach ($inputArtifact in @($stage.inputArtifacts)) {
            $name = [string] $inputArtifact
            if (-not $artifactMap.ContainsKey($name)) {
                $inputMissing += $name
            }
        }

        if ($inputMissing.Count -gt 0) {
            $lastFailureMessage = ("Missing input artifacts for stage {0}: {1}" -f $stageId, ($inputMissing -join ', '))
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
            continue
        }

        if (-not $SkipGuardrails) {
            $usage.steps = [int] $usage.steps + 1
            if ([int] $usage.steps -gt [int] $budget.maxSteps) {
                $lastFailureMessage = ("Agent {0} exceeded maxSteps ({1})." -f $agentId, $budget.maxSteps)
                Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
                continue
            }
        }

        $execution = $stage.execution
        $scriptPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path ([string] $execution.scriptPath)
        $scriptPathRelative = Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $scriptPath

        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            $lastFailureMessage = ("Stage {0} script not found: {1}" -f $stageId, $scriptPathRelative)
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
            continue
        }

        $syntheticCommand = "pwsh -File $scriptPathRelative"
        if (-not $SkipGuardrails -and (Test-IsBlockedCommand -CommandText $syntheticCommand -BlockedCommands @($agent.blockedCommands))) {
            $lastFailureMessage = ("Blocked command for agent {0}: {1}" -f $agentId, $syntheticCommand)
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
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
        & $scriptPath `
            -RepoRoot $resolvedRepoRoot `
            -RunDirectory $runDirectory `
            -TraceId $trace `
            -StageId $stageId `
            -AgentId $agentId `
            -RequestPath $requestPath `
            -InputArtifactManifestPath $inputManifestPath `
            -OutputArtifactManifestPath $outputManifestPath `
            -DetailedOutput:$DetailedOutput
        $stageExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        $stageFinishedAt = Get-Date
        $stageDurationMs = [int] ($stageFinishedAt - $stageStartedAt).TotalMilliseconds

        $timeoutSeconds = if ($null -eq $execution.timeoutSeconds) { 1800 } else { [int] $execution.timeoutSeconds }
        if ($stageDurationMs -gt ($timeoutSeconds * 1000)) {
            $lastFailureMessage = ("Stage {0} exceeded timeoutSeconds ({1}). Duration={2}ms." -f $stageId, $timeoutSeconds, $stageDurationMs)
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
            continue
        }

        if ($stageExitCode -ne 0) {
            $lastFailureMessage = ("Stage {0} failed with exit code {1}." -f $stageId, $stageExitCode)
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
            continue
        }

        if (-not (Test-Path -LiteralPath $outputManifestPath -PathType Leaf)) {
            $lastFailureMessage = ("Stage {0} output manifest not found: {1}" -f $stageId, (Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $outputManifestPath))
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
            continue
        }

        $outputManifest = Read-JsonFile -Path $outputManifestPath
        $stageArtifactMap = Convert-ManifestToArtifactMap -Manifest $outputManifest -Root $resolvedRepoRoot

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
            Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
            continue
        }

        foreach ($entry in $stageArtifactMap.GetEnumerator()) {
            $artifactMap[$entry.Key] = $entry.Value
        }
        $producedArtifactNames = @($stageArtifactMap.Keys)

        $afterSet = if ($SkipGuardrails) { $null } else { Get-WorkingTreePathSet -Root $resolvedRepoRoot }
        if (-not $SkipGuardrails -and $null -ne $beforeSet -and $null -ne $afterSet) {
            $changedDelta = @()
            foreach ($pathAfter in $afterSet) {
                if (-not $beforeSet.Contains($pathAfter)) {
                    $changedDelta += $pathAfter
                }
            }

            $disallowed = @()
            foreach ($relativeChangedPath in $changedDelta) {
                if (-not (Test-IsPathAllowed -RelativePath $relativeChangedPath -AllowedPatterns @($agent.allowedPaths))) {
                    $disallowed += $relativeChangedPath
                }
            }

            if ($disallowed.Count -gt 0) {
                $lastFailureMessage = ("Agent {0} changed disallowed paths: {1}" -f $agentId, ($disallowed -join ', '))
                Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
                continue
            }

            $usage.fileEdits = [int] $usage.fileEdits + $changedDelta.Count
            if ([int] $usage.fileEdits -gt [int] $budget.maxFileEdits) {
                $lastFailureMessage = ("Agent {0} exceeded maxFileEdits ({1}). Current={2}" -f $agentId, $budget.maxFileEdits, $usage.fileEdits)
                Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
                continue
            }

            $usage.durationMs = [int] $usage.durationMs + $stageDurationMs
            $maxDurationMs = [int] $budget.maxDurationMinutes * 60000
            if ([int] $usage.durationMs -gt $maxDurationMs) {
                $lastFailureMessage = ("Agent {0} exceeded maxDurationMinutes ({1}). CurrentDurationMs={2}" -f $agentId, $budget.maxDurationMinutes, $usage.durationMs)
                Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
                continue
            }

            if ([int] $usage.tokenUsage -gt [int] $budget.maxTokens) {
                $lastFailureMessage = ("Agent {0} exceeded maxTokens ({1})." -f $agentId, $budget.maxTokens)
                Write-Output ("[ERROR] {0}" -f $lastFailureMessage)
                continue
            }
        }

        $stageSucceeded = $true
    }

    if (-not $stageSucceeded) {
        $runFailures.Add($lastFailureMessage) | Out-Null
    }

    $stageStatus = if ($stageSucceeded) { 'success' } else { 'failed' }
    $stageOutputArtifacts = if ($stageSucceeded) { @($producedArtifactNames) } else { @() }
    $stageFailureCount = if ($stageSucceeded) { 0 } else { 1 }
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
    }
    $stageResults.Add($stageResult) | Out-Null

    if ($stageSucceeded) {
        foreach ($handoff in @($pipeline.handoffs | Where-Object { $_.fromStage -eq $stageId })) {
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

    if (-not $stageSucceeded -and $onFailure -eq 'stop') {
        break
    }
}

$pipelineFinishedAt = Get-Date
$failedStages = @($stageResults | Where-Object { $_.status -ne 'success' }).Count

$missingCompletionStages = @()
foreach ($requiredStage in @($pipeline.completionCriteria.requiredStages)) {
    $requiredStageId = [string] $requiredStage
    $stageOk = @($stageResults | Where-Object { $_.stageId -eq $requiredStageId -and $_.status -eq 'success' }).Count -gt 0
    if (-not $stageOk) {
        $missingCompletionStages += $requiredStageId
    }
}

$missingCompletionArtifacts = @()
foreach ($requiredArtifact in @($pipeline.completionCriteria.requiredArtifacts)) {
    $requiredName = [string] $requiredArtifact
    if (-not $artifactMap.ContainsKey($requiredName)) {
        $missingCompletionArtifacts += $requiredName
    }
}

if ($missingCompletionStages.Count -gt 0) {
    $runFailures.Add(("Missing required successful stages: {0}" -f ($missingCompletionStages -join ', '))) | Out-Null
}

if ($missingCompletionArtifacts.Count -gt 0) {
    $runFailures.Add(("Missing required completion artifacts: {0}" -f ($missingCompletionArtifacts -join ', '))) | Out-Null
}

$overallStatus = if (($failedStages -eq 0) -and ($runFailures.Count -eq 0)) { 'success' } else { 'failed' }
$guardrailNotes = if ($SkipGuardrails) {
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
    estimatedCostUsd = 0
    totalDurationMs = [int] ($pipelineFinishedAt - $pipelineStartedAt).TotalMilliseconds
    notes = $guardrailNotes
}
$runArtifact = [pscustomobject]@{
    traceId = $trace
    pipelineId = [string] $pipeline.id
    status = $overallStatus
    startedAt = $pipelineStartedAt.ToString('o')
    finishedAt = $pipelineFinishedAt.ToString('o')
    stages = $stagesForArtifact
    summary = $runSummary
}

Set-Content -LiteralPath $runArtifactPath -Value ($runArtifact | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline

Write-Output ''
Write-Output 'Agent pipeline execution summary'
Write-Output ("  traceId: {0}" -f $trace)
Write-Output ("  pipeline: {0}" -f $pipeline.id)
Write-Output ("  status: {0}" -f $overallStatus)
Write-Output ("  stages: total={0} failed={1}" -f $stageResults.Count, $failedStages)
Write-Output ("  run artifact: {0}" -f (Convert-ToRepoRelativePath -Root $resolvedRepoRoot -Path $runArtifactPath))

if ($runFailures.Count -gt 0) {
    Write-Output '  failures:'
    foreach ($failure in $runFailures) {
        Write-Output ("    - {0}" -f $failure)
    }
}

if ($overallStatus -ne 'success') {
    exit 1
}

exit 0