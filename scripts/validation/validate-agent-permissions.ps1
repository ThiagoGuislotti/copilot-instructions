<#
.SYNOPSIS
    Validates permission alignment between agent contracts and governance matrix.

.DESCRIPTION
    Enforces consistency between:
    - `.codex/orchestration/agents.manifest.json`
    - `.codex/orchestration/pipelines/default.pipeline.json`
    - `.github/governance/agent-skill-permissions.matrix.json`

    Checks include:
    - agent role/skill alignment
    - required blocked command prefixes
    - allowed path scope alignment
    - budget contract alignment
    - stage script path allowance by agent

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when enforcing mode is enabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER MatrixPath
    Permission matrix JSON path relative to repository root.

.PARAMETER AgentManifestPath
    Agent manifest JSON path relative to repository root.

.PARAMETER PipelinePath
    Pipeline JSON path relative to repository root.

.PARAMETER WarningOnly
    When true (default), findings are emitted as warnings and do not fail execution.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-permissions.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-agent-permissions.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $MatrixPath = '.github/governance/agent-skill-permissions.matrix.json',
    [string] $AgentManifestPath = '.codex/orchestration/agents.manifest.json',
    [string] $PipelinePath = '.codex/orchestration/pipelines/default.pipeline.json',
    [bool] $WarningOnly = $true,
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
$script:IsWarningOnly = [bool] $WarningOnly
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    if ($script:IsWarningOnly) {
        $script:Warnings.Add($Message) | Out-Null
        Write-StyledOutput ("[WARN] {0}" -f $Message)
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
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

# Reads and parses a required JSON document.
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

# Converts glob syntax to a regex pattern.
function Convert-GlobToRegex {
    param(
        [string] $Glob
    )

    $normalized = $Glob.Replace('\', '/')
    $escaped = [System.Text.RegularExpressions.Regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return "^{0}$" -f $escaped
}

# Matches text against one or more glob patterns.
function Test-GlobMatch {
    param(
        [string] $Text,
        [string[]] $Patterns
    )

    $normalizedText = $Text.Replace('\', '/')
    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        $regexPattern = Convert-GlobToRegex -Glob $pattern
        if ($normalizedText -match $regexPattern) {
            return $true
        }
    }

    return $false
}

# Converts input values to a string array while handling null and scalar values.
function Convert-ToStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @([string] $Value)
    }

    return @($Value | ForEach-Object { [string] $_ })
}

# Builds an agent-id map from matrix entries.
function Get-AgentMatrixMap {
    param(
        [object[]] $MatrixAgents
    )

    $map = @{}
    foreach ($entry in $MatrixAgents) {
        $agentId = [string] $entry.agentId
        if ([string]::IsNullOrWhiteSpace($agentId)) {
            Add-ValidationFailure 'agent-skill-permissions matrix has an entry with blank agentId.'
            continue
        }

        if ($map.ContainsKey($agentId)) {
            Add-ValidationFailure ("Duplicate agentId in matrix: {0}" -f $agentId)
            continue
        }

        $map[$agentId] = $entry
    }

    return $map
}

# Validates one agent against matrix entry.
function Test-AgentPermissionContract {
    param(
        [object] $Agent,
        [object] $MatrixEntry,
        [string[]] $RequiredBlockedCommands
    )

    $agentId = [string] $Agent.id

    $agentRole = [string] $Agent.role
    $matrixRole = [string] $MatrixEntry.role
    if (-not [string]::IsNullOrWhiteSpace($matrixRole) -and $agentRole -ne $matrixRole) {
        Add-ValidationFailure ("Role mismatch for agent '{0}': manifest='{1}' matrix='{2}'." -f $agentId, $agentRole, $matrixRole)
    }

    $agentSkill = [string] $Agent.skill
    $matrixSkill = [string] $MatrixEntry.skill
    if (-not [string]::IsNullOrWhiteSpace($matrixSkill) -and $agentSkill -ne $matrixSkill) {
        Add-ValidationFailure ("Skill mismatch for agent '{0}': manifest='{1}' matrix='{2}'." -f $agentId, $agentSkill, $matrixSkill)
    }

    $manifestAllowedPaths = Convert-ToStringArray -Value $Agent.allowedPaths
    $matrixAllowedPaths = Convert-ToStringArray -Value $MatrixEntry.allowedPathGlobs
    foreach ($manifestPath in $manifestAllowedPaths) {
        if (-not (Test-GlobMatch -Text $manifestPath -Patterns $matrixAllowedPaths)) {
            Add-ValidationFailure ("Agent '{0}' path not allowed by matrix: {1}" -f $agentId, $manifestPath)
        }
    }

    $blockedCommands = Convert-ToStringArray -Value $Agent.blockedCommands
    foreach ($requiredBlockedCommand in $RequiredBlockedCommands) {
        $hasRequiredCommand = $false
        foreach ($blockedCommand in $blockedCommands) {
            if ($blockedCommand.Trim().ToLowerInvariant() -eq $requiredBlockedCommand.Trim().ToLowerInvariant()) {
                $hasRequiredCommand = $true
                break
            }
        }

        if (-not $hasRequiredCommand) {
            Add-ValidationFailure ("Agent '{0}' missing required blocked command: {1}" -f $agentId, $requiredBlockedCommand)
        }
    }

    $requiredBudget = $MatrixEntry.requiredBudget
    $agentBudget = $Agent.budget
    foreach ($budgetField in @('maxSteps', 'maxDurationMinutes', 'maxFileEdits', 'maxTokens')) {
        $matrixValue = [int] $requiredBudget.$budgetField
        $agentValue = [int] $agentBudget.$budgetField
        if ($matrixValue -ne $agentValue) {
            Add-ValidationFailure ("Budget mismatch for agent '{0}' field '{1}': manifest={2} matrix={3}" -f $agentId, $budgetField, $agentValue, $matrixValue)
        }
    }
}

# Validates stage script assignments against matrix stage globs and global prefixes.
function Test-StagePermissionContract {
    param(
        [object[]] $StageList,
        [hashtable] $MatrixMap,
        [string[]] $AllowedStagePrefixes
    )

    foreach ($stage in $StageList) {
        $stageId = [string] $stage.id
        $agentId = [string] $stage.agentId
        $scriptPath = [string] $stage.execution.scriptPath

        if (-not $MatrixMap.ContainsKey($agentId)) {
            Add-ValidationFailure ("Stage '{0}' references agent without matrix entry: {1}" -f $stageId, $agentId)
            continue
        }

        $hasAllowedPrefix = $false
        foreach ($prefix in $AllowedStagePrefixes) {
            if ([string]::IsNullOrWhiteSpace($prefix)) {
                continue
            }

            $normalizedPrefix = $prefix.Replace('\', '/')
            $normalizedScriptPath = $scriptPath.Replace('\', '/')
            if ($normalizedScriptPath.StartsWith($normalizedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $hasAllowedPrefix = $true
                break
            }
        }

        if (-not $hasAllowedPrefix) {
            Add-ValidationFailure ("Stage '{0}' uses script outside global allowed prefixes: {1}" -f $stageId, $scriptPath)
        }

        $matrixEntry = $MatrixMap[$agentId]
        $allowedStageGlobs = Convert-ToStringArray -Value $matrixEntry.allowedStageScriptGlobs
        if (-not (Test-GlobMatch -Text $scriptPath -Patterns $allowedStageGlobs)) {
            Add-ValidationFailure ("Stage '{0}' script not allowed for agent '{1}': {2}" -f $stageId, $agentId, $scriptPath)
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedMatrixPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $MatrixPath
$resolvedAgentManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $AgentManifestPath
$resolvedPipelinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $PipelinePath

$matrix = Get-RequiredJsonDocument -Path $resolvedMatrixPath -Label 'agent permission matrix'
$agentManifest = Get-RequiredJsonDocument -Path $resolvedAgentManifestPath -Label 'agent manifest'
$pipeline = Get-RequiredJsonDocument -Path $resolvedPipelinePath -Label 'pipeline manifest'

if ($null -eq $matrix -or $null -eq $agentManifest -or $null -eq $pipeline) {
    Write-StyledOutput ''
    Write-StyledOutput 'Agent permission validation summary'
    Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
    Write-StyledOutput '  Agents checked: 0'
    Write-StyledOutput '  Stage checks: 0'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { exit 1 }
    exit 0
}

$matrixAgentMap = Get-AgentMatrixMap -MatrixAgents @($matrix.agents)
$requiredBlockedCommandPrefixes = Convert-ToStringArray -Value $matrix.globalRules.requiredBlockedCommandPrefixes
$allowedStagePrefixes = Convert-ToStringArray -Value $matrix.globalRules.allowedStageScriptPrefixes

$manifestAgents = @($agentManifest.agents)
foreach ($agent in $manifestAgents) {
    $agentId = [string] $agent.id
    if (-not $matrixAgentMap.ContainsKey($agentId)) {
        Add-ValidationFailure ("Agent missing matrix entry: {0}" -f $agentId)
        continue
    }

    Test-AgentPermissionContract -Agent $agent -MatrixEntry $matrixAgentMap[$agentId] -RequiredBlockedCommands $requiredBlockedCommandPrefixes
}

foreach ($matrixAgentId in ($matrixAgentMap.Keys | Sort-Object)) {
    $existsInManifest = @($manifestAgents | Where-Object { [string] $_.id -eq $matrixAgentId }).Count -gt 0
    if (-not $existsInManifest) {
        Add-ValidationWarning ("Matrix has agent not present in manifest: {0}" -f $matrixAgentId)
    }
}

Test-StagePermissionContract -StageList @($pipeline.stages) -MatrixMap $matrixAgentMap -AllowedStagePrefixes $allowedStagePrefixes

Write-StyledOutput ''
Write-StyledOutput 'Agent permission validation summary'
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Agents checked: {0}" -f $manifestAgents.Count)
Write-StyledOutput ("  Stage checks: {0}" -f @($pipeline.stages).Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
    exit 1
}

Write-StyledOutput 'Agent permission validation passed.'
exit 0