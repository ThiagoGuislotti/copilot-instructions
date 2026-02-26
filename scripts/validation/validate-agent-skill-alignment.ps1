<#
.SYNOPSIS
    Validates alignment between agent contracts, skills, pipeline, and eval fixtures.

.DESCRIPTION
    Performs deterministic cross-file checks for:
    - `.codex/orchestration/agents.manifest.json`
    - `.codex/orchestration/pipelines/default.pipeline.json`
    - `.codex/orchestration/evals/golden-tests.json`
    - `.codex/skills/*`

    Checks include:
    - agent ids, roles, and fallback references
    - agent skill folder and required files (`SKILL.md`, `agents/openai.yaml`)
    - skill frontmatter consistency with agent skill id
    - skill references to mandatory instruction entry files
    - pipeline stage agent-role alignment
    - eval requiredAgents integrity against agents and pipeline

    Exit code:
    - 0 when all required checks pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER AgentManifestPath
    Agent manifest JSON path relative to repository root.

.PARAMETER PipelinePath
    Pipeline JSON path relative to repository root.

.PARAMETER EvalFixturePath
    Evals JSON path relative to repository root.

.PARAMETER SkillsRootPath
    Skill directory path relative to repository root.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-skill-alignment.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-skill-alignment.ps1 -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $AgentManifestPath = '.codex/orchestration/agents.manifest.json',
    [string] $PipelinePath = '.codex/orchestration/pipelines/default.pipeline.json',
    [string] $EvalFixturePath = '.codex/orchestration/evals/golden-tests.json',
    [string] $SkillsRootPath = '.codex/skills',
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-Output ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-Output ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-Output ("[WARN] {0}" -f $Message)
}

# Resolves a path from repo root.
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

# Resolves repository root from input and fallback candidates.
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
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
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

# Loads and parses a required JSON document.
function Get-RequiredJsonDocument {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in {0}: {1}" -f $Label, $_.Exception.Message)
        return $null
    }
}

# Parses SKILL.md frontmatter and returns key/value map.
function Get-SkillFrontmatterMap {
    param(
        [string] $SkillFilePath
    )

    $lines = @(Get-Content -LiteralPath $SkillFilePath)
    if ($lines.Count -lt 3) {
        Add-ValidationFailure ("Invalid SKILL.md frontmatter (too short): {0}" -f $SkillFilePath)
        return @{}
    }

    if ($lines[0].Trim() -ne '---') {
        Add-ValidationFailure ("Missing SKILL.md frontmatter start marker: {0}" -f $SkillFilePath)
        return @{}
    }

    $endIndex = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            $endIndex = $index
            break
        }
    }

    if ($endIndex -lt 1) {
        Add-ValidationFailure ("Missing SKILL.md frontmatter end marker: {0}" -f $SkillFilePath)
        return @{}
    }

    $map = @{}
    foreach ($line in $lines[1..($endIndex - 1)]) {
        $match = [regex]::Match($line, '^\s*(?<key>[A-Za-z0-9_-]+)\s*:\s*(?<value>.*)\s*$')
        if (-not $match.Success) {
            continue
        }

        $key = $match.Groups['key'].Value
        $value = $match.Groups['value'].Value.Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $map[$key] = $value
    }

    return $map
}

# Builds an agent id map and validates duplicates.
function Get-AgentMap {
    param(
        [object[]] $AgentList
    )

    $map = @{}
    foreach ($agent in $AgentList) {
        $agentId = [string] $agent.id
        if ([string]::IsNullOrWhiteSpace($agentId)) {
            Add-ValidationFailure 'Agent manifest contains an entry with blank id.'
            continue
        }

        if ($map.ContainsKey($agentId)) {
            Add-ValidationFailure ("Duplicate agent id in manifest: {0}" -f $agentId)
            continue
        }

        $map[$agentId] = $agent
    }

    return $map
}

# Validates that one skill definition aligns with agent and instruction contracts.
function Test-AgentSkillLink {
    param(
        [string] $SkillsRoot,
        [object] $Agent
    )

    $agentId = [string] $Agent.id
    $skillName = [string] $Agent.skill

    if ([string]::IsNullOrWhiteSpace($skillName)) {
        Add-ValidationFailure ("Agent '{0}' has empty skill reference." -f $agentId)
        return
    }

    $skillFolder = Join-Path $SkillsRoot $skillName
    $skillFile = Join-Path $skillFolder 'SKILL.md'
    $openAiFile = Join-Path $skillFolder 'agents\openai.yaml'

    if (-not (Test-Path -LiteralPath $skillFolder -PathType Container)) {
        Add-ValidationFailure ("Agent '{0}' references missing skill folder: {1}" -f $agentId, $skillFolder)
        return
    }

    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        Add-ValidationFailure ("Agent '{0}' skill missing SKILL.md: {1}" -f $agentId, $skillFile)
        return
    }

    if (-not (Test-Path -LiteralPath $openAiFile -PathType Leaf)) {
        Add-ValidationFailure ("Agent '{0}' skill missing agents/openai.yaml: {1}" -f $agentId, $openAiFile)
    }

    $frontmatterMap = Get-SkillFrontmatterMap -SkillFilePath $skillFile
    if ($frontmatterMap.ContainsKey('name')) {
        if ([string] $frontmatterMap['name'] -ne $skillName) {
            Add-ValidationFailure ("Skill frontmatter name mismatch for agent '{0}': expected '{1}' found '{2}'." -f $agentId, $skillName, $frontmatterMap['name'])
        }
    }
    else {
        Add-ValidationFailure ("Skill frontmatter missing 'name': {0}" -f $skillFile)
    }

    $skillText = Get-Content -Raw -LiteralPath $skillFile
    foreach ($requiredReference in @('.github/AGENTS.md', '.github/copilot-instructions.md', '.github/instruction-routing.catalog.yml')) {
        if ($skillText -notmatch [regex]::Escape($requiredReference)) {
            Add-ValidationFailure ("Skill for agent '{0}' missing required reference '{1}': {2}" -f $agentId, $requiredReference, $skillFile)
        }
    }

    if ($skillText -notmatch '\.github/instructions/') {
        Add-ValidationWarning ("Skill for agent '{0}' has no explicit .github/instructions reference: {1}" -f $agentId, $skillFile)
    }
}

# Validates pipeline stage mode-role alignment against agent roles.
function Test-StageRoleAlignment {
    param(
        [object[]] $StageList,
        [hashtable] $AgentMap
    )

    $expectedRoleByMode = @{
        plan = 'planner'
        execute = 'executor'
        validate = 'tester'
        review = 'reviewer'
    }

    foreach ($stage in $StageList) {
        $stageId = [string] $stage.id
        $agentId = [string] $stage.agentId
        $mode = ([string] $stage.mode).ToLowerInvariant()

        if (-not $AgentMap.ContainsKey($agentId)) {
            Add-ValidationFailure ("Pipeline stage '{0}' references unknown agent id: {1}" -f $stageId, $agentId)
            continue
        }

        if (-not $expectedRoleByMode.ContainsKey($mode)) {
            Add-ValidationWarning ("Pipeline stage '{0}' has non-standard mode '{1}'." -f $stageId, $mode)
            continue
        }

        $agentRole = ([string] $AgentMap[$agentId].role).ToLowerInvariant()
        $expectedRole = $expectedRoleByMode[$mode]
        if ($agentRole -ne $expectedRole) {
            Add-ValidationFailure ("Pipeline stage '{0}' mode '{1}' expects role '{2}' but agent '{3}' has role '{4}'." -f $stageId, $mode, $expectedRole, $agentId, $agentRole)
        }
    }
}

# Validates eval requiredAgents references against agents and pipeline stages.
function Test-EvalAgentReference {
    param(
        [object[]] $EvalCaseList,
        [hashtable] $AgentMap,
        [System.Collections.Generic.HashSet[string]] $PipelineAgentSet
    )

    foreach ($evalCase in $EvalCaseList) {
        $caseId = [string] $evalCase.id
        foreach ($requiredAgent in @($evalCase.requiredAgents)) {
            $requiredAgentId = [string] $requiredAgent
            if (-not $AgentMap.ContainsKey($requiredAgentId)) {
                Add-ValidationFailure ("Eval case '{0}' references unknown required agent: {1}" -f $caseId, $requiredAgentId)
                continue
            }

            if (-not $PipelineAgentSet.Contains($requiredAgentId)) {
                Add-ValidationFailure ("Eval case '{0}' requires agent not present in pipeline stages: {1}" -f $caseId, $requiredAgentId)
            }
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedAgentManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AgentManifestPath
$resolvedPipelinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $PipelinePath
$resolvedEvalPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $EvalFixturePath
$resolvedSkillsRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $SkillsRootPath

$agentManifest = Get-RequiredJsonDocument -Path $resolvedAgentManifestPath -Label 'agents manifest'
$pipelineManifest = Get-RequiredJsonDocument -Path $resolvedPipelinePath -Label 'pipeline manifest'
$evalFixture = Get-RequiredJsonDocument -Path $resolvedEvalPath -Label 'eval fixture'

if (-not (Test-Path -LiteralPath $resolvedSkillsRoot -PathType Container)) {
    Add-ValidationFailure ("Skills root not found: {0}" -f $resolvedSkillsRoot)
}

if ($script:Failures.Count -gt 0) {
    Write-Output ''
    Write-Output 'Agent-skill alignment validation summary'
    Write-Output '  Agents checked: 0'
    Write-Output '  Stage checks: 0'
    Write-Output '  Eval case checks: 0'
    Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-Output ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$agentList = @($agentManifest.agents)
if ($agentList.Count -eq 0) {
    Add-ValidationFailure 'Agent manifest has no agents.'
}

$stageList = @($pipelineManifest.stages)
if ($stageList.Count -eq 0) {
    Add-ValidationFailure 'Pipeline has no stages.'
}

$evalCaseList = @($evalFixture.cases)
if ($evalCaseList.Count -eq 0) {
    Add-ValidationFailure 'Eval fixture has no cases.'
}

$agentMap = Get-AgentMap -AgentList $agentList
foreach ($agent in $agentList) {
    $fallbackAgentId = [string] $agent.fallbackAgentId
    if (-not [string]::IsNullOrWhiteSpace($fallbackAgentId) -and -not $agentMap.ContainsKey($fallbackAgentId)) {
        Add-ValidationFailure ("Agent '{0}' references unknown fallback agent '{1}'." -f $agent.id, $fallbackAgentId)
    }
}

foreach ($agent in $agentList) {
    Test-AgentSkillLink -SkillsRoot $resolvedSkillsRoot -Agent $agent
}

$pipelineAgentSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($stage in $stageList) {
    $pipelineAgentSet.Add([string] $stage.agentId) | Out-Null

    $scriptPath = [string] $stage.execution.scriptPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        Add-ValidationFailure ("Pipeline stage '{0}' has empty execution.scriptPath." -f $stage.id)
    }
    else {
        $resolvedStageScriptPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $scriptPath
        if (-not (Test-Path -LiteralPath $resolvedStageScriptPath -PathType Leaf)) {
            Add-ValidationFailure ("Pipeline stage '{0}' script not found: {1}" -f $stage.id, $scriptPath)
        }
    }
}

Test-StageRoleAlignment -StageList $stageList -AgentMap $agentMap
Test-EvalAgentReference -EvalCaseList $evalCaseList -AgentMap $agentMap -PipelineAgentSet $pipelineAgentSet

Write-Output ''
Write-Output 'Agent-skill alignment validation summary'
Write-Output ("  Agents checked: {0}" -f $agentList.Count)
Write-Output ("  Stage checks: {0}" -f $stageList.Count)
Write-Output ("  Eval case checks: {0}" -f $evalCaseList.Count)
Write-Output ("  Warnings: {0}" -f $script:Warnings.Count)
Write-Output ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-Output 'Agent-skill alignment validation passed.'
exit 0