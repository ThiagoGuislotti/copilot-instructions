<#
.SYNOPSIS
    Resolves the shared runtime execution contract for repository runtime scripts.

.DESCRIPTION
    Centralizes repository root detection, runtime profile resolution, effective
    runtime location discovery, default target resolution, and canonical source
    layout discovery so install/sync/doctor/healthcheck flows can share one
    contract without duplicating runtime path logic.

.PARAMETER RequestedRepoRoot
    Optional repository root supplied by the caller. When omitted, the standard
    repository root detection rules apply.

.PARAMETER ProfileName
    Optional runtime profile name. Supported values come from
    `.github/governance/runtime-install-profiles.json`.

.PARAMETER FallbackProfileName
    Optional fallback profile used when the caller omits `ProfileName`. Install
    typically leaves this empty so the catalog default applies; direct runtime
    utilities usually pass `all`.

.PARAMETER RequestedTargetGithubPath
    Optional override for the resolved GitHub runtime target path.

.PARAMETER RequestedTargetCodexPath
    Optional override for the resolved Codex runtime target path.

.PARAMETER RequestedTargetAgentsSkillsPath
    Optional override for the resolved picker-visible agent skills target path.

.PARAMETER RequestedTargetCopilotSkillsPath
    Optional override for the resolved GitHub Copilot native skills target path.

.EXAMPLE
    $context = Resolve-RuntimeExecutionContext -RequestedRepoRoot . -FallbackProfileName 'all'

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

$ErrorActionPreference = 'Stop'

# Resolves the effective runtime execution context shared by install/sync/runtime scripts.
function Resolve-RuntimeExecutionContext {
    param(
        [string] $RequestedRepoRoot,
        [string] $ProfileName,
        [string] $FallbackProfileName,
        [string] $RequestedTargetGithubPath,
        [string] $RequestedTargetCodexPath,
        [string] $RequestedTargetAgentsSkillsPath,
        [string] $RequestedTargetCopilotSkillsPath,
        [string] $RequestedTargetClaudePath
    )

    $resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RequestedRepoRoot
    $resolvedRuntimeProfile = Resolve-RuntimeInstallProfile -ResolvedRepoRoot $resolvedRepoRoot -ProfileName $ProfileName -FallbackProfileName $FallbackProfileName
    $effectiveRuntimeLocations = Get-EffectiveRuntimeLocations

    $resolvedTargetGithubPath = if ([string]::IsNullOrWhiteSpace($RequestedTargetGithubPath)) {
        Resolve-GithubRuntimePath
    }
    else {
        $RequestedTargetGithubPath
    }

    $resolvedTargetCodexPath = if ([string]::IsNullOrWhiteSpace($RequestedTargetCodexPath)) {
        Resolve-CodexRuntimePath
    }
    else {
        $RequestedTargetCodexPath
    }

    $resolvedTargetAgentsSkillsPath = if ([string]::IsNullOrWhiteSpace($RequestedTargetAgentsSkillsPath)) {
        Resolve-AgentsSkillsPath
    }
    else {
        $RequestedTargetAgentsSkillsPath
    }

    $resolvedTargetCopilotSkillsPath = if ([string]::IsNullOrWhiteSpace($RequestedTargetCopilotSkillsPath)) {
        Resolve-CopilotSkillsPath
    }
    else {
        $RequestedTargetCopilotSkillsPath
    }

    $resolvedTargetClaudePath = if ([string]::IsNullOrWhiteSpace($RequestedTargetClaudePath)) {
        Resolve-ClaudeRuntimePath
    }
    else {
        $RequestedTargetClaudePath
    }

    $sourceGithubRoot = Join-Path $resolvedRepoRoot '.github'
    $sourceCodexRoot = Join-Path $resolvedRepoRoot '.codex'
    $sourceScriptsRoot = Join-Path $resolvedRepoRoot 'scripts'

    return [pscustomobject]@{
        ResolvedRepoRoot = $resolvedRepoRoot
        RuntimeProfile = $resolvedRuntimeProfile
        EffectiveRuntimeLocations = $effectiveRuntimeLocations
        Targets = [pscustomobject]@{
            GithubRuntimeRoot = $resolvedTargetGithubPath
            CodexRuntimeRoot = $resolvedTargetCodexPath
            AgentsSkillsRoot = $resolvedTargetAgentsSkillsPath
            CopilotSkillsRoot = $resolvedTargetCopilotSkillsPath
            ClaudeRuntimeRoot = $resolvedTargetClaudePath
        }
        Sources = [pscustomobject]@{
            GithubRoot = $sourceGithubRoot
            CodexRoot = $sourceCodexRoot
            ScriptsRoot = $sourceScriptsRoot
            GithubSkillsRoot = Join-Path $sourceGithubRoot 'skills'
            CodexSkillsRoot = Join-Path $sourceCodexRoot 'skills'
            ClaudeSkillsRoot = Join-Path $resolvedRepoRoot '.claude' 'skills'
            CodexMcpRoot = Join-Path $sourceCodexRoot 'mcp'
            CodexScriptsRoot = Join-Path $sourceCodexRoot 'scripts'
            CodexOrchestrationRoot = Join-Path $sourceCodexRoot 'orchestration'
            CommonScriptsRoot = Join-Path $sourceScriptsRoot 'common'
            SecurityScriptsRoot = Join-Path $sourceScriptsRoot 'security'
            MaintenanceScriptsRoot = Join-Path $sourceScriptsRoot 'maintenance'
        }
    }
}

# Builds a standard runtime target argument map for downstream script invocation.
function New-RuntimeTargetArgumentMap {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Context,
        [switch] $IncludeRepoRoot,
        [switch] $IncludeRuntimeProfile
    )

    $arguments = @{}
    if ($IncludeRepoRoot) {
        $arguments.RepoRoot = $Context.ResolvedRepoRoot
    }

    $arguments.TargetGithubPath = $Context.Targets.GithubRuntimeRoot
    $arguments.TargetCodexPath = $Context.Targets.CodexRuntimeRoot
    $arguments.TargetAgentsSkillsPath = $Context.Targets.AgentsSkillsRoot
    $arguments.TargetCopilotSkillsPath = $Context.Targets.CopilotSkillsRoot

    if ($IncludeRuntimeProfile) {
        $arguments.RuntimeProfile = $Context.RuntimeProfile.Name
    }

    return $arguments
}

# Builds a standard runtime target argument map with target paths resolved
# against a repository root for downstream script invocation/reporting.
function New-ResolvedRuntimeTargetArgumentMap {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Context,
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [switch] $IncludeRepoRoot,
        [switch] $IncludeRuntimeProfile
    )

    $arguments = New-RuntimeTargetArgumentMap -Context $Context -IncludeRepoRoot:$IncludeRepoRoot -IncludeRuntimeProfile:$IncludeRuntimeProfile
    $arguments.TargetGithubPath = Resolve-RepoPath -Root $ResolvedRepoRoot -Path $Context.Targets.GithubRuntimeRoot
    $arguments.TargetCodexPath = Resolve-RepoPath -Root $ResolvedRepoRoot -Path $Context.Targets.CodexRuntimeRoot
    $arguments.TargetAgentsSkillsPath = Resolve-RepoPath -Root $ResolvedRepoRoot -Path $Context.Targets.AgentsSkillsRoot
    $arguments.TargetCopilotSkillsPath = Resolve-RepoPath -Root $ResolvedRepoRoot -Path $Context.Targets.CopilotSkillsRoot

    return $arguments
}