<#
.SYNOPSIS
    Validates multi-agent contracts and orchestration assets.

.DESCRIPTION
    Performs deterministic validation for versioned multi-agent assets:
    - JSON schema validation for contracts, pipeline, templates, and eval fixtures
    - Cross-file integrity between agent manifest, skill files, and pipeline stages
    - Baseline guardrail checks for allowed paths, fallback links, and completion criteria

    Returns exit code 1 when failures are found, otherwise 0.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER Verbose
    Prints detailed diagnostics during validation.

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-orchestration.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-orchestration.ps1 -Verbose

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$VerbosePreference = if ($script:IsVerboseEnabled) { 'Continue' } else { 'SilentlyContinue' }
$InformationPreference = 'Continue'
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics when verbose mode is enabled.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    Write-Verbose -Message $Message
}

# Registers a validation failure and prints a standardized failure message.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-Information ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning and prints a standardized warning message.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-Information ("[WARN] {0}" -f $Message)
}

# Builds an absolute path from repository root and relative path input.
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

# Resolves the repository root using explicit and fallback location candidates.
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
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Validates that a required file or directory exists.
function Test-RequiredPath {
    param(
        [string] $Root,
        [string] $RelativePath,
        [ValidateSet('File', 'Directory')] [string] $Type = 'File'
    )

    $absolute = Resolve-RepoPath -Root $Root -Path $RelativePath
    $exists = if ($Type -eq 'Directory') {
        Test-Path -LiteralPath $absolute -PathType Container
    }
    else {
        Test-Path -LiteralPath $absolute -PathType Leaf
    }

    if ($exists) {
        Write-VerboseLog ("Required {0}: {1}" -f $Type.ToLowerInvariant(), $RelativePath)
        return $absolute
    }

    Add-ValidationFailure ("Missing required {0}: {1}" -f $Type.ToLowerInvariant(), $RelativePath)
    return $null
}

# Validates a JSON document against a JSON schema and returns the parsed object.
function Test-JsonSchemaDocument {
    param(
        [string] $Root,
        [string] $DocumentPath,
        [string] $SchemaPath
    )

    $documentAbsolute = Test-RequiredPath -Root $Root -RelativePath $DocumentPath -Type File
    $schemaAbsolute = Test-RequiredPath -Root $Root -RelativePath $SchemaPath -Type File

    if ($null -eq $documentAbsolute -or $null -eq $schemaAbsolute) {
        return $null
    }

    $jsonRaw = $null
    try {
        $jsonRaw = Get-Content -Raw -LiteralPath $documentAbsolute
    }
    catch {
        Add-ValidationFailure ("Could not read JSON document {0}: {1}" -f $DocumentPath, $_.Exception.Message)
        return $null
    }

    try {
        $isValid = Test-Json -Json $jsonRaw -SchemaFile $schemaAbsolute -ErrorAction Stop
        if (-not $isValid) {
            Add-ValidationFailure ("Schema validation failed: {0} <= {1}" -f $DocumentPath, $SchemaPath)
            return $null
        }
    }
    catch {
        Add-ValidationFailure ("Schema validation exception in {0}: {1}" -f $DocumentPath, $_.Exception.Message)
        return $null
    }

    try {
        $jsonObject = $jsonRaw | ConvertFrom-Json -Depth 200
        Write-VerboseLog ("Schema validation passed: {0} <= {1}" -f $DocumentPath, $SchemaPath)
        return $jsonObject
    }
    catch {
        Add-ValidationFailure ("JSON parse failed in {0}: {1}" -f $DocumentPath, $_.Exception.Message)
        return $null
    }
}

# Validates agent manifest integrity and skill references.
function Test-AgentManifestIntegrity {
    param(
        [string] $Root,
        [object] $Manifest
    )

    $agentIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $roles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    if ($null -eq $Manifest) {
        return [pscustomobject]@{
            AgentIds = $agentIds
            Roles = $roles
        }
    }

    $agents = @($Manifest.agents)
    foreach ($agent in $agents) {
        $agentId = [string] $agent.id
        if (-not $agentIds.Add($agentId)) {
            Add-ValidationFailure ("Duplicate agent id in manifest: {0}" -f $agentId)
        }

        $role = [string] $agent.role
        if (-not [string]::IsNullOrWhiteSpace($role)) {
            $roles.Add($role) | Out-Null
        }

        $skillName = [string] $agent.skill
        $skillMarkdown = Resolve-RepoPath -Root $Root -Path (".codex/skills/{0}/SKILL.md" -f $skillName)
        if (-not (Test-Path -LiteralPath $skillMarkdown -PathType Leaf)) {
            Add-ValidationFailure ("Agent {0} references missing skill markdown: .codex/skills/{1}/SKILL.md" -f $agentId, $skillName)
        }

        $skillOpenAi = Resolve-RepoPath -Root $Root -Path (".codex/skills/{0}/agents/openai.yaml" -f $skillName)
        if (-not (Test-Path -LiteralPath $skillOpenAi -PathType Leaf)) {
            Add-ValidationFailure ("Agent {0} references missing skill config: .codex/skills/{1}/agents/openai.yaml" -f $agentId, $skillName)
        }

        foreach ($path in @($agent.allowedPaths)) {
            $pathText = [string] $path
            if ([string]::IsNullOrWhiteSpace($pathText)) {
                Add-ValidationFailure ("Agent {0} has blank allowed path entry." -f $agentId)
                continue
            }

            if ($pathText -eq '*' -or $pathText -eq '/**') {
                Add-ValidationFailure ("Agent {0} uses overly broad allowed path pattern: {1}" -f $agentId, $pathText)
            }
        }
    }

    foreach ($agent in $agents) {
        $agentId = [string] $agent.id
        $fallbackProperty = $agent.PSObject.Properties['fallbackAgentId']
        if ($null -eq $fallbackProperty) {
            continue
        }

        $fallback = [string] $fallbackProperty.Value
        if ([string]::IsNullOrWhiteSpace($fallback)) {
            continue
        }

        if (-not $agentIds.Contains($fallback)) {
            Add-ValidationFailure ("Agent {0} references unknown fallbackAgentId: {1}" -f $agentId, $fallback)
        }
    }

    foreach ($requiredRole in @('planner', 'executor', 'reviewer')) {
        if (-not $roles.Contains($requiredRole)) {
            Add-ValidationFailure ("Agent manifest missing required role: {0}" -f $requiredRole)
        }
    }

    if (-not $roles.Contains('tester')) {
        Add-ValidationWarning 'Agent manifest does not define role: tester'
    }

    return [pscustomobject]@{
        AgentIds = $agentIds
        Roles = $roles
    }
}

# Validates pipeline stage links, handoffs, and completion criteria.
function Test-PipelineManifestIntegrity {
    param(
        [string] $Root,
        [object] $Pipeline,
        [System.Collections.Generic.HashSet[string]] $AgentIds
    )

    if ($null -eq $Pipeline) {
        return
    }

    $stageIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $stageOutputs = @{}
    $orderedStageIds = New-Object System.Collections.Generic.List[string]
    $pipelineStages = @($Pipeline.stages)

    foreach ($stage in $pipelineStages) {
        $stageId = [string] $stage.id
        if (-not $stageIds.Add($stageId)) {
            Add-ValidationFailure ("Duplicate pipeline stage id: {0}" -f $stageId)
        }
        $orderedStageIds.Add($stageId) | Out-Null

        $agentId = [string] $stage.agentId
        if (-not $AgentIds.Contains($agentId)) {
            Add-ValidationFailure ("Pipeline stage {0} references unknown agentId: {1}" -f $stageId, $agentId)
        }

        $executionScriptPath = [string] $stage.execution.scriptPath
        if ([string]::IsNullOrWhiteSpace($executionScriptPath)) {
            Add-ValidationFailure ("Pipeline stage {0} has empty execution.scriptPath." -f $stageId)
        }
        else {
            $absoluteScriptPath = Resolve-RepoPath -Root $Root -Path $executionScriptPath
            if (-not (Test-Path -LiteralPath $absoluteScriptPath -PathType Leaf)) {
                Add-ValidationFailure ("Pipeline stage {0} execution script not found: {1}" -f $stageId, $executionScriptPath)
            }
        }

        $outputSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($artifact in @($stage.outputArtifacts)) {
            $outputSet.Add([string] $artifact) | Out-Null
        }
        $stageOutputs[$stageId] = $outputSet
    }

    if ($pipelineStages.Count -gt 0) {
        $firstMode = [string] $pipelineStages[0].mode
        $lastMode = [string] $pipelineStages[$pipelineStages.Count - 1].mode

        if ($firstMode -ne 'plan') {
            Add-ValidationFailure ("Pipeline first stage must be mode 'plan', found '{0}'." -f $firstMode)
        }

        if ($lastMode -ne 'review') {
            Add-ValidationFailure ("Pipeline last stage must be mode 'review', found '{0}'." -f $lastMode)
        }

        $firstStageInputs = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($inputArtifact in @($pipelineStages[0].inputArtifacts)) {
            $firstStageInputs.Add([string] $inputArtifact) | Out-Null
        }
        if (-not $firstStageInputs.Contains('request')) {
            Add-ValidationFailure "Pipeline first stage must consume 'request' artifact."
        }
    }

    foreach ($handoff in @($Pipeline.handoffs)) {
        $fromStage = [string] $handoff.fromStage
        $toStage = [string] $handoff.toStage

        if (-not $stageIds.Contains($fromStage)) {
            Add-ValidationFailure ("Handoff references unknown fromStage: {0}" -f $fromStage)
            continue
        }

        if (-not $stageIds.Contains($toStage)) {
            Add-ValidationFailure ("Handoff references unknown toStage: {0}" -f $toStage)
            continue
        }

        $fromOutputSet = $stageOutputs[$fromStage]
        foreach ($requiredArtifact in @($handoff.requiredArtifacts)) {
            $requiredName = [string] $requiredArtifact
            if (-not $fromOutputSet.Contains($requiredName)) {
                Add-ValidationFailure ("Handoff {0}->{1} requires artifact not produced by {0}: {2}" -f $fromStage, $toStage, $requiredName)
            }

            $targetStage = @($pipelineStages | Where-Object { $_.id -eq $toStage } | Select-Object -First 1)
            if ($null -ne $targetStage) {
                $targetInputSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($inputArtifact in @($targetStage.inputArtifacts)) {
                    $targetInputSet.Add([string] $inputArtifact) | Out-Null
                }

                if (-not $targetInputSet.Contains($requiredName)) {
                    Add-ValidationFailure ("Handoff {0}->{1} requires artifact not consumed by target stage {1}: {2}" -f $fromStage, $toStage, $requiredName)
                }
            }
        }
    }

    foreach ($requiredStage in @($Pipeline.completionCriteria.requiredStages)) {
        $requiredStageName = [string] $requiredStage
        if (-not $stageIds.Contains($requiredStageName)) {
            Add-ValidationFailure ("Completion criteria references unknown stage: {0}" -f $requiredStageName)
        }
    }

    $allOutputs = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($set in $stageOutputs.Values) {
        foreach ($item in $set) {
            $allOutputs.Add($item) | Out-Null
        }
    }

    foreach ($requiredArtifact in @($Pipeline.completionCriteria.requiredArtifacts)) {
        $artifactName = [string] $requiredArtifact
        if (-not $allOutputs.Contains($artifactName)) {
            Add-ValidationFailure ("Completion criteria references artifact not produced by any stage: {0}" -f $artifactName)
        }
    }
}

# Validates the handoff template against pipeline stage ids.
function Test-HandoffTemplateIntegrity {
    param(
        [object] $HandoffTemplate,
        [object] $Pipeline
    )

    if ($null -eq $HandoffTemplate) {
        return
    }

    if (@($HandoffTemplate.artifacts).Count -eq 0) {
        Add-ValidationFailure 'Handoff template must include at least one artifact entry.'
    }

    if ($null -eq $Pipeline) {
        return
    }

    $stageIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($stage in @($Pipeline.stages)) {
        $stageIds.Add([string] $stage.id) | Out-Null
    }

    $fromStage = [string] $HandoffTemplate.fromStage
    $toStage = [string] $HandoffTemplate.toStage

    if (-not $stageIds.Contains($fromStage)) {
        Add-ValidationFailure ("Handoff template references unknown fromStage: {0}" -f $fromStage)
    }

    if (-not $stageIds.Contains($toStage)) {
        Add-ValidationFailure ("Handoff template references unknown toStage: {0}" -f $toStage)
    }
}

# Validates the run artifact template against pipeline and agent ids.
function Test-RunArtifactTemplateIntegrity {
    param(
        [object] $RunTemplate,
        [object] $Pipeline,
        [System.Collections.Generic.HashSet[string]] $AgentIds
    )

    if ($null -eq $RunTemplate) {
        return
    }

    $runStages = @($RunTemplate.stages)
    if ($runStages.Count -eq 0) {
        Add-ValidationFailure 'Run artifact template must include at least one stage entry.'
        return
    }

    $pipelineStageIds = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    if ($null -ne $Pipeline) {
        foreach ($stage in @($Pipeline.stages)) {
            $pipelineStageIds.Add([string] $stage.id) | Out-Null
        }
    }

    foreach ($runStage in $runStages) {
        $stageId = [string] $runStage.stageId
        $agentId = [string] $runStage.agentId

        if (($pipelineStageIds.Count -gt 0) -and (-not $pipelineStageIds.Contains($stageId))) {
            Add-ValidationFailure ("Run artifact template references unknown stageId: {0}" -f $stageId)
        }

        if (-not $AgentIds.Contains($agentId)) {
            Add-ValidationFailure ("Run artifact template references unknown agentId: {0}" -f $agentId)
        }
    }

    $summaryStageCount = [int] $RunTemplate.summary.stageCount
    if ($summaryStageCount -ne $runStages.Count) {
        Add-ValidationFailure ("Run artifact summary stageCount ({0}) must match stages length ({1})." -f $summaryStageCount, $runStages.Count)
    }
}

# Validates eval fixtures against pipeline and manifest ids.
function Test-EvalFixturesIntegrity {
    param(
        [object] $EvalFixtures,
        [object] $Pipeline,
        [System.Collections.Generic.HashSet[string]] $AgentIds
    )

    if ($null -eq $EvalFixtures -or $null -eq $Pipeline) {
        return
    }

    $pipelineId = [string] $Pipeline.id
    $pipelineOrder = @($Pipeline.stages | ForEach-Object { [string] $_.id })
    $pipelineOrderText = $pipelineOrder -join '|'

    foreach ($caseItem in @($EvalFixtures.cases)) {
        $caseId = [string] $caseItem.id
        $expectedPipelineId = [string] $caseItem.expectedPipelineId
        if ($expectedPipelineId -ne $pipelineId) {
            Add-ValidationFailure ("Eval case {0} expectedPipelineId mismatch. Expected {1}, found {2}" -f $caseId, $pipelineId, $expectedPipelineId)
        }

        $expectedOrder = @($caseItem.expectedStageOrder | ForEach-Object { [string] $_ })
        $expectedOrderText = $expectedOrder -join '|'
        if ($expectedOrderText -ne $pipelineOrderText) {
            Add-ValidationWarning ("Eval case {0} stage order diverges from pipeline order." -f $caseId)
        }

        foreach ($requiredAgent in @($caseItem.requiredAgents)) {
            $requiredAgentId = [string] $requiredAgent
            if (-not $AgentIds.Contains($requiredAgentId)) {
                Add-ValidationFailure ("Eval case {0} references unknown required agent: {1}" -f $caseId, $requiredAgentId)
            }
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$requiredDirectories = @(
    '.codex/orchestration',
    '.codex/orchestration/pipelines',
    '.codex/orchestration/templates',
    '.codex/orchestration/evals',
    '.github/schemas',
    'scripts/orchestration/stages'
)

foreach ($relativeDirectory in $requiredDirectories) {
    Test-RequiredPath -Root $resolvedRepoRoot -RelativePath $relativeDirectory -Type Directory | Out-Null
}

$requiredFiles = @(
    'scripts/runtime/run-agent-pipeline.ps1',
    'scripts/orchestration/stages/plan-stage.ps1',
    'scripts/orchestration/stages/implement-stage.ps1',
    'scripts/orchestration/stages/validate-stage.ps1',
    'scripts/orchestration/stages/review-stage.ps1'
)

foreach ($relativeFile in $requiredFiles) {
    Test-RequiredPath -Root $resolvedRepoRoot -RelativePath $relativeFile -Type File | Out-Null
}

$agentsManifest = Test-JsonSchemaDocument -Root $resolvedRepoRoot -DocumentPath '.codex/orchestration/agents.manifest.json' -SchemaPath '.github/schemas/agent.contract.schema.json'
$pipelineManifest = Test-JsonSchemaDocument -Root $resolvedRepoRoot -DocumentPath '.codex/orchestration/pipelines/default.pipeline.json' -SchemaPath '.github/schemas/agent.pipeline.schema.json'
$handoffTemplate = Test-JsonSchemaDocument -Root $resolvedRepoRoot -DocumentPath '.codex/orchestration/templates/handoff.template.json' -SchemaPath '.github/schemas/agent.handoff.schema.json'
$runArtifactTemplate = Test-JsonSchemaDocument -Root $resolvedRepoRoot -DocumentPath '.codex/orchestration/templates/run-artifact.template.json' -SchemaPath '.github/schemas/agent.run-artifact.schema.json'
$evalFixtures = Test-JsonSchemaDocument -Root $resolvedRepoRoot -DocumentPath '.codex/orchestration/evals/golden-tests.json' -SchemaPath '.github/schemas/agent.evals.schema.json'

$manifestStats = Test-AgentManifestIntegrity -Root $resolvedRepoRoot -Manifest $agentsManifest
Test-PipelineManifestIntegrity -Root $resolvedRepoRoot -Pipeline $pipelineManifest -AgentIds $manifestStats.AgentIds
Test-HandoffTemplateIntegrity -HandoffTemplate $handoffTemplate -Pipeline $pipelineManifest
Test-RunArtifactTemplateIntegrity -RunTemplate $runArtifactTemplate -Pipeline $pipelineManifest -AgentIds $manifestStats.AgentIds
Test-EvalFixturesIntegrity -EvalFixtures $evalFixtures -Pipeline $pipelineManifest -AgentIds $manifestStats.AgentIds

Write-StyledOutput ''
Write-StyledOutput 'Agent orchestration validation summary'
Write-StyledOutput ("  Agents: {0}" -f $manifestStats.AgentIds.Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'All agent orchestration validations passed.'
exit 0