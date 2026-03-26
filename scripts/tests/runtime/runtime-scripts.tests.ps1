<#
.SYNOPSIS
    Runtime tests for critical scripts without external test frameworks.

.DESCRIPTION
    Validates script contracts and smoke behavior for runtime scripts used
    by bootstrap, healthcheck, self-heal, and cleanup flows.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/runtime-scripts.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
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
# Fails the current runtime test when the supplied condition is false.
function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

# Fails the current test when the collection does not contain the expected value.
function Assert-Contains {
    param(
        [string[]] $Collection,
        [string] $Value,
        [string] $Message
    )

    if (-not ($Collection -contains $Value)) {
        throw $Message
    }
}

# Fails the current test when the collection does not contain any expected value.
function Assert-ContainsAny {
    param(
        [string[]] $Collection,
        [string[]] $ExpectedValues,
        [string] $Message
    )

    foreach ($expectedValue in @($ExpectedValues)) {
        if ($Collection -contains $expectedValue) {
            return
        }
    }

    throw $Message
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$runtimeScriptRoot = Join-Path $resolvedRepoRoot 'scripts/runtime'

$exitCode = 0

try {
    $scriptPath = Join-Path $runtimeScriptRoot 'bootstrap.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'bootstrap missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'TargetGithubPath' -Message 'bootstrap missing TargetGithubPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCodexPath' -Message 'bootstrap missing TargetCodexPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetAgentsSkillsPath' -Message 'bootstrap missing TargetAgentsSkillsPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCopilotSkillsPath' -Message 'bootstrap missing TargetCopilotSkillsPath parameter.'
    Assert-Contains -Collection $keys -Value 'RuntimeProfile' -Message 'bootstrap missing RuntimeProfile parameter.'
    Assert-Contains -Collection $keys -Value 'Mirror' -Message 'bootstrap missing Mirror parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'healthcheck.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'ValidationProfile' -Message 'healthcheck missing ValidationProfile parameter.'
    Assert-Contains -Collection $keys -Value 'WarningOnly' -Message 'healthcheck missing WarningOnly parameter.'
    Assert-Contains -Collection $keys -Value 'TargetGithubPath' -Message 'healthcheck missing TargetGithubPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCodexPath' -Message 'healthcheck missing TargetCodexPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetAgentsSkillsPath' -Message 'healthcheck missing TargetAgentsSkillsPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCopilotSkillsPath' -Message 'healthcheck missing TargetCopilotSkillsPath parameter.'
    Assert-Contains -Collection $keys -Value 'RuntimeProfile' -Message 'healthcheck missing RuntimeProfile parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'self-heal.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'Mirror' -Message 'self-heal missing Mirror parameter.'
    Assert-Contains -Collection $keys -Value 'ApplyMcpConfig' -Message 'self-heal missing ApplyMcpConfig parameter.'
    Assert-Contains -Collection $keys -Value 'TargetGithubPath' -Message 'self-heal missing TargetGithubPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCodexPath' -Message 'self-heal missing TargetCodexPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetAgentsSkillsPath' -Message 'self-heal missing TargetAgentsSkillsPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCopilotSkillsPath' -Message 'self-heal missing TargetCopilotSkillsPath parameter.'
    Assert-Contains -Collection $keys -Value 'RuntimeProfile' -Message 'self-heal missing RuntimeProfile parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'CodexHome' -Message 'clean-codex-runtime missing CodexHome parameter.'
    Assert-Contains -Collection $keys -Value 'IncludeSessions' -Message 'clean-codex-runtime missing IncludeSessions parameter.'
    Assert-Contains -Collection $keys -Value 'SessionRetentionDays' -Message 'clean-codex-runtime missing SessionRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'LogRetentionDays' -Message 'clean-codex-runtime missing LogRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'MaxSessionFileSizeMB' -Message 'clean-codex-runtime missing MaxSessionFileSizeMB parameter.'
    Assert-Contains -Collection $keys -Value 'OversizedSessionGraceHours' -Message 'clean-codex-runtime missing OversizedSessionGraceHours parameter.'
    Assert-Contains -Collection $keys -Value 'MaxSessionStorageGB' -Message 'clean-codex-runtime missing MaxSessionStorageGB parameter.'
    Assert-Contains -Collection $keys -Value 'SessionStorageGraceHours' -Message 'clean-codex-runtime missing SessionStorageGraceHours parameter.'
    Assert-Contains -Collection $keys -Value 'ExportPlanningSummary' -Message 'clean-codex-runtime missing ExportPlanningSummary parameter.'
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'clean-codex-runtime missing RepoRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'clean-vscode-user-runtime.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'GlobalVscodeUserPath' -Message 'clean-vscode-user-runtime missing GlobalVscodeUserPath parameter.'
    Assert-Contains -Collection $keys -Value 'WorkspaceStorageRetentionDays' -Message 'clean-vscode-user-runtime missing WorkspaceStorageRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'ChatSessionRetentionDays' -Message 'clean-vscode-user-runtime missing ChatSessionRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'ChatEditingSessionRetentionDays' -Message 'clean-vscode-user-runtime missing ChatEditingSessionRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'TranscriptRetentionDays' -Message 'clean-vscode-user-runtime missing TranscriptRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'HistoryRetentionDays' -Message 'clean-vscode-user-runtime missing HistoryRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'SettingsBackupRetentionDays' -Message 'clean-vscode-user-runtime missing SettingsBackupRetentionDays parameter.'
    Assert-Contains -Collection $keys -Value 'MaxChatSessionFileSizeMB' -Message 'clean-vscode-user-runtime missing MaxChatSessionFileSizeMB parameter.'
    Assert-Contains -Collection $keys -Value 'MaxCopilotWorkspaceIndexSizeMB' -Message 'clean-vscode-user-runtime missing MaxCopilotWorkspaceIndexSizeMB parameter.'
    Assert-Contains -Collection $keys -Value 'OversizedFileGraceHours' -Message 'clean-vscode-user-runtime missing OversizedFileGraceHours parameter.'
    Assert-Contains -Collection $keys -Value 'RecentRunWindowHours' -Message 'clean-vscode-user-runtime missing RecentRunWindowHours parameter.'
    Assert-Contains -Collection $keys -Value 'ExportPlanningSummary' -Message 'clean-vscode-user-runtime missing ExportPlanningSummary parameter.'
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'clean-vscode-user-runtime missing RepoRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'set-codex-runtime-preferences.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'set-codex-runtime-preferences missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'TargetConfigPath' -Message 'set-codex-runtime-preferences missing TargetConfigPath parameter.'
    Assert-Contains -Collection $keys -Value 'ReasoningEffort' -Message 'set-codex-runtime-preferences missing ReasoningEffort parameter.'
    Assert-Contains -Collection $keys -Value 'MultiAgentMode' -Message 'set-codex-runtime-preferences missing MultiAgentMode parameter.'
    Assert-Contains -Collection $keys -Value 'CreateBackup' -Message 'set-codex-runtime-preferences missing CreateBackup parameter.'
    Assert-Contains -Collection $keys -Value 'PreviewOnly' -Message 'set-codex-runtime-preferences missing PreviewOnly parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'sync-vscode-global-mcp.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'sync-vscode-global-mcp missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'WorkspaceVscodePath' -Message 'sync-vscode-global-mcp missing WorkspaceVscodePath parameter.'
    Assert-Contains -Collection $keys -Value 'GlobalVscodeUserPath' -Message 'sync-vscode-global-mcp missing GlobalVscodeUserPath parameter.'
    Assert-Contains -Collection $keys -Value 'WorkspaceHelperPath' -Message 'sync-vscode-global-mcp missing WorkspaceHelperPath parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'sync-vscode-global-mcp missing CatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'ProfilePath' -Message 'sync-vscode-global-mcp missing ProfilePath parameter.'
    Assert-Contains -Collection $keys -Value 'SyncWorkspaceHelper' -Message 'sync-vscode-global-mcp missing SyncWorkspaceHelper parameter.'
    Assert-Contains -Collection $keys -Value 'CreateBackup' -Message 'sync-vscode-global-mcp missing CreateBackup parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'setup-vscode-profiles.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'DryRun' -Message 'setup-vscode-profiles missing DryRun parameter.'
    Assert-Contains -Collection $keys -Value 'ListProfiles' -Message 'setup-vscode-profiles missing ListProfiles parameter.'
    Assert-Contains -Collection $keys -Value 'ProfileName' -Message 'setup-vscode-profiles missing ProfileName parameter.'
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'setup-vscode-profiles missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'ProfilesRoot' -Message 'setup-vscode-profiles missing ProfilesRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SkipMcpSync' -Message 'setup-vscode-profiles missing SkipMcpSync parameter.'
    Assert-Contains -Collection $keys -Value 'McpProfileName' -Message 'setup-vscode-profiles missing McpProfileName parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-github-instruction-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-github-instruction-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-github-instruction-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SharedRoot' -Message 'render-github-instruction-surfaces missing SharedRoot parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'render-github-instruction-surfaces missing OutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-mcp-runtime-artifacts.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-mcp-runtime-artifacts missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'render-mcp-runtime-artifacts missing CatalogPath parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-vscode-mcp-template.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-vscode-mcp-template missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'render-vscode-mcp-template missing CatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'OutputPath' -Message 'render-vscode-mcp-template missing OutputPath parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'sync-codex-mcp-config.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'sync-codex-mcp-config missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'sync-codex-mcp-config missing CatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'ManifestPath' -Message 'sync-codex-mcp-config missing ManifestPath parameter.'
    Assert-Contains -Collection $keys -Value 'TargetConfigPath' -Message 'sync-codex-mcp-config missing TargetConfigPath parameter.'
    Assert-Contains -Collection $keys -Value 'CreateBackup' -Message 'sync-codex-mcp-config missing CreateBackup parameter.'
    Assert-Contains -Collection $keys -Value 'DryRun' -Message 'sync-codex-mcp-config missing DryRun parameter.'

    foreach ($hookScriptName in @('common.ps1', 'session-start.ps1', 'subagent-start.ps1', 'pre-tool-use.ps1')) {
        $scriptPath = Join-Path $runtimeScriptRoot ('hooks\' + $hookScriptName)
        Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) ("Missing runtime hook script: {0}" -f $hookScriptName)
    }

    $scriptPath = Join-Path $runtimeScriptRoot 'render-provider-skill-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-provider-skill-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-provider-skill-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'Provider' -Message 'render-provider-skill-surfaces missing Provider parameter.'
    Assert-Contains -Collection $keys -Value 'CodexOutputRoot' -Message 'render-provider-skill-surfaces missing CodexOutputRoot parameter.'
    Assert-Contains -Collection $keys -Value 'ClaudeOutputRoot' -Message 'render-provider-skill-surfaces missing ClaudeOutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-provider-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-provider-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'render-provider-surfaces missing CatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'RendererId' -Message 'render-provider-surfaces missing RendererId parameter.'
    Assert-Contains -Collection $keys -Value 'ConsumerName' -Message 'render-provider-surfaces missing ConsumerName parameter.'
    Assert-Contains -Collection $keys -Value 'EnableCodexRuntime' -Message 'render-provider-surfaces missing EnableCodexRuntime parameter.'
    Assert-Contains -Collection $keys -Value 'EnableClaudeRuntime' -Message 'render-provider-surfaces missing EnableClaudeRuntime parameter.'
    Assert-Contains -Collection $keys -Value 'SummaryOnly' -Message 'render-provider-surfaces missing SummaryOnly parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-vscode-profile-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-vscode-profile-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-vscode-profile-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'render-vscode-profile-surfaces missing OutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-vscode-workspace-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-vscode-workspace-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-vscode-workspace-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'render-vscode-workspace-surfaces missing OutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-codex-compatibility-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-codex-compatibility-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-codex-compatibility-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'ScriptsOutputRoot' -Message 'render-codex-compatibility-surfaces missing ScriptsOutputRoot parameter.'
    Assert-Contains -Collection $keys -Value 'McpOutputRoot' -Message 'render-codex-compatibility-surfaces missing McpOutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-codex-orchestration-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-codex-orchestration-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-codex-orchestration-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'render-codex-orchestration-surfaces missing OutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'render-claude-runtime-surfaces.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'render-claude-runtime-surfaces missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'SourceRoot' -Message 'render-claude-runtime-surfaces missing SourceRoot parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'render-claude-runtime-surfaces missing OutputRoot parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'update-local-context-index.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'update-local-context-index missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'update-local-context-index missing CatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'update-local-context-index missing OutputRoot parameter.'
    Assert-Contains -Collection $keys -Value 'ForceFullRebuild' -Message 'update-local-context-index missing ForceFullRebuild parameter.'
    Assert-Contains -Collection $keys -Value 'DetailedOutput' -Message 'update-local-context-index missing DetailedOutput parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'query-local-context-index.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'query-local-context-index missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'QueryText' -Message 'query-local-context-index missing QueryText parameter.'
    Assert-Contains -Collection $keys -Value 'CatalogPath' -Message 'query-local-context-index missing CatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'OutputRoot' -Message 'query-local-context-index missing OutputRoot parameter.'
    Assert-Contains -Collection $keys -Value 'Top' -Message 'query-local-context-index missing Top parameter.'
    Assert-Contains -Collection $keys -Value 'JsonOutput' -Message 'query-local-context-index missing JsonOutput parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'run-agent-pipeline.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RequestText' -Message 'run-agent-pipeline missing RequestText parameter.'
    Assert-Contains -Collection $keys -Value 'ExecutionBackend' -Message 'run-agent-pipeline missing ExecutionBackend parameter.'
    Assert-Contains -Collection $keys -Value 'DispatchCommand' -Message 'run-agent-pipeline missing DispatchCommand parameter.'
    Assert-Contains -Collection $keys -Value 'ApprovedStageIds' -Message 'run-agent-pipeline missing ApprovedStageIds parameter.'
    Assert-Contains -Collection $keys -Value 'ApprovedAgentIds' -Message 'run-agent-pipeline missing ApprovedAgentIds parameter.'
    Assert-Contains -Collection $keys -Value 'ApprovedBy' -Message 'run-agent-pipeline missing ApprovedBy parameter.'
    Assert-Contains -Collection $keys -Value 'ApprovalJustification' -Message 'run-agent-pipeline missing ApprovalJustification parameter.'
    Assert-Contains -Collection $keys -Value 'WriteRunState' -Message 'run-agent-pipeline missing WriteRunState parameter.'
    Assert-Contains -Collection $keys -Value 'StopAfterStageId' -Message 'run-agent-pipeline missing StopAfterStageId parameter.'
    Assert-Contains -Collection $keys -Value 'StartAtStageId' -Message 'run-agent-pipeline missing StartAtStageId parameter.'
    Assert-Contains -Collection $keys -Value 'ResumeFromRunDirectory' -Message 'run-agent-pipeline missing ResumeFromRunDirectory parameter.'
    Assert-Contains -Collection $keys -Value 'PolicyCatalogPath' -Message 'run-agent-pipeline missing PolicyCatalogPath parameter.'
    Assert-Contains -Collection $keys -Value 'ModelRoutingCatalogPath' -Message 'run-agent-pipeline missing ModelRoutingCatalogPath parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'resume-agent-pipeline.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RunDirectory' -Message 'resume-agent-pipeline missing RunDirectory parameter.'
    Assert-Contains -Collection $keys -Value 'StartAtStageId' -Message 'resume-agent-pipeline missing StartAtStageId parameter.'
    Assert-Contains -Collection $keys -Value 'ApprovedAgentIds' -Message 'resume-agent-pipeline missing ApprovedAgentIds parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'replay-agent-run.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RunDirectory' -Message 'replay-agent-run missing RunDirectory parameter.'
    Assert-Contains -Collection $keys -Value 'OutputPath' -Message 'replay-agent-run missing OutputPath parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'evaluate-agent-pipeline.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'EvalsPath' -Message 'evaluate-agent-pipeline missing EvalsPath parameter.'
    Assert-Contains -Collection $keys -Value 'OutputPath' -Message 'evaluate-agent-pipeline missing OutputPath parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'export-planning-summary.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'export-planning-summary missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'OutputPath' -Message 'export-planning-summary missing OutputPath parameter.'
    Assert-Contains -Collection $keys -Value 'PrintOnly' -Message 'export-planning-summary missing PrintOnly parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'invoke-super-agent-housekeeping.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'WorkspacePath' -Message 'invoke-super-agent-housekeeping missing WorkspacePath parameter.'
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'invoke-super-agent-housekeeping missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'IntervalHours' -Message 'invoke-super-agent-housekeeping missing IntervalHours parameter.'
    Assert-Contains -Collection $keys -Value 'StateFilePath' -Message 'invoke-super-agent-housekeeping missing StateFilePath parameter.'
    Assert-Contains -Collection $keys -Value 'Apply' -Message 'invoke-super-agent-housekeeping missing Apply parameter.'
    Assert-Contains -Collection $keys -Value 'BypassThrottle' -Message 'invoke-super-agent-housekeeping missing BypassThrottle parameter.'
    Assert-Contains -Collection $keys -Value 'RecordOnlyPath' -Message 'invoke-super-agent-housekeeping missing RecordOnlyPath parameter.'
    Assert-Contains -Collection $keys -Value 'DetailedOutput' -Message 'invoke-super-agent-housekeeping missing DetailedOutput parameter.'

    $scriptPath = Join-Path $resolvedRepoRoot 'scripts/git-hooks/setup-global-git-aliases.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'setup-global-git-aliases missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'TargetCodexPath' -Message 'setup-global-git-aliases missing TargetCodexPath parameter.'
    Assert-Contains -Collection $keys -Value 'Uninstall' -Message 'setup-global-git-aliases missing Uninstall parameter.'

    $scriptPath = Join-Path $resolvedRepoRoot 'scripts/git-hooks/setup-git-hooks.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RepoRoot' -Message 'setup-git-hooks missing RepoRoot parameter.'
    Assert-Contains -Collection $keys -Value 'EofHygieneMode' -Message 'setup-git-hooks missing EofHygieneMode parameter.'
    Assert-Contains -Collection $keys -Value 'EofHygieneScope' -Message 'setup-git-hooks missing EofHygieneScope parameter.'
    Assert-Contains -Collection $keys -Value 'Uninstall' -Message 'setup-git-hooks missing Uninstall parameter.'

    $scriptPath = Join-Path $runtimeScriptRoot 'install.ps1'
    $command = Get-Command -Name $scriptPath -ErrorAction Stop
    $keys = @($command.Parameters.Keys)
    Assert-Contains -Collection $keys -Value 'RuntimeProfile' -Message 'install missing RuntimeProfile parameter.'
    Assert-Contains -Collection $keys -Value 'GitHookEofMode' -Message 'install missing GitHookEofMode parameter.'
    Assert-Contains -Collection $keys -Value 'GitHookEofScope' -Message 'install missing GitHookEofScope parameter.'
    Assert-Contains -Collection $keys -Value 'CodexReasoningEffort' -Message 'install missing CodexReasoningEffort parameter.'
    Assert-Contains -Collection $keys -Value 'CodexMultiAgentMode' -Message 'install missing CodexMultiAgentMode parameter.'

    $operationalScriptDirectories = @(
        (Join-Path $resolvedRepoRoot 'scripts/runtime'),
        (Join-Path $resolvedRepoRoot 'scripts/validation'),
        (Join-Path $resolvedRepoRoot 'scripts/git-hooks'),
        (Join-Path $resolvedRepoRoot 'scripts/governance'),
        (Join-Path $resolvedRepoRoot 'scripts/maintenance'),
        (Join-Path $resolvedRepoRoot 'scripts/security')
    )
    foreach ($scriptDirectory in $operationalScriptDirectories) {
        foreach ($operationalScript in @(Get-ChildItem -LiteralPath $scriptDirectory -Filter *.ps1 -File | Sort-Object Name)) {
            $command = Get-Command -Name $operationalScript.FullName -ErrorAction Stop
            $keys = @($command.Parameters.Keys)
            Assert-ContainsAny -Collection $keys -ExpectedValues @('Verbose', 'DetailedLogs', 'DetailedOutput') -Message ("Operational script is missing a verbose-style parameter: {0}" -f $operationalScript.FullName)
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $tempRepoRoot = Join-Path $tempRoot 'repo'
    $workspaceVscode = Join-Path $tempRepoRoot '.vscode'
    $codexRoot = Join-Path $tempRepoRoot '.codex'
    $catalogRoot = Join-Path $tempRepoRoot '.github\governance'
    $catalogPath = Join-Path $catalogRoot 'mcp-runtime.catalog.json'
    $globalUserPath = Join-Path $tempRoot 'Code\User'
    $globalMcpPath = Join-Path $globalUserPath 'mcp.json'
    $workspaceHelperPath = Join-Path $workspaceVscode 'mcp-vscode-global.json'
    $profilePath = Join-Path $workspaceVscode 'profiles\profile-frontend.json'
    $scriptPath = Join-Path $runtimeScriptRoot 'sync-vscode-global-mcp.ps1'
    $renderScriptPath = Join-Path $runtimeScriptRoot 'render-mcp-runtime-artifacts.ps1'
    try {
        New-Item -ItemType Directory -Path $workspaceVscode -Force | Out-Null
        New-Item -ItemType Directory -Path $codexRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $catalogRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path -Path $profilePath -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path $globalUserPath -Force | Out-Null
        Set-Content -LiteralPath $catalogPath -Value @(
            '{',
            '  "version": 1,',
            '  "inputs": [',
            '    { "id": "Authorization", "type": "promptString", "description": "Token", "password": true }',
            '  ],',
            '  "servers": [',
            '    {',
            '      "id": "example/server",',
            '      "targets": { "vscode": { "include": true, "enabledByDefault": true } },',
            '      "definition": {',
            '        "type": "stdio",',
            '        "command": "pwsh",',
            '        "args": ["%USERPROFILE%/tools/run.ps1"],',
            '        "gallery": "https://example.invalid/gallery",',
            '        "version": "1.0.0"',
            '      }',
            '    },',
            '    {',
            '      "id": "disabled/by-default",',
            '      "targets": { "vscode": { "include": true, "enabledByDefault": false } },',
            '      "definition": {',
            '        "type": "http",',
            '        "url": "https://example.invalid/mcp",',
            '        "gallery": "https://example.invalid/gallery",',
            '        "version": "1.0.0"',
            '      }',
            '    },',
            '    {',
            '      "id": "enabled/by-default",',
            '      "targets": { "vscode": { "include": true, "enabledByDefault": true } },',
            '      "definition": {',
            '        "type": "http",',
            '        "url": "https://example.invalid/enabled",',
            '        "gallery": "https://example.invalid/gallery",',
            '        "version": "1.0.0"',
            '      }',
            '    },',
            '    {',
            '      "id": "codex-only",',
            '      "codexName": "codex-only",',
            '      "targets": { "codex": { "include": true } },',
            '      "definition": {',
            '        "type": "http",',
            '        "url": "https://example.invalid/codex"',
            '      }',
            '    }',
            '  ]',
            '}'
        )
        Set-Content -LiteralPath $profilePath -Value @(
            '{',
            '  "name": "Frontend",',
            '  "description": "Example profile",',
            '  "mcp": {',
            '    "servers": {',
            '      "disabled/by-default": { "enabled": true },',
            '      "enabled/by-default": { "enabled": false }',
            '    }',
            '  }',
            '}'
        )
        Set-Content -LiteralPath $globalMcpPath -Value '{}' 

        & $scriptPath -RepoRoot $tempRepoRoot -WorkspaceVscodePath $workspaceVscode -GlobalVscodeUserPath $globalUserPath -WorkspaceHelperPath $workspaceHelperPath -CatalogPath $catalogPath -ProfilePath $profilePath -CreateBackup | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'sync-vscode-global-mcp smoke test failed.'
        Assert-True (Test-Path -LiteralPath $globalMcpPath -PathType Leaf) 'sync-vscode-global-mcp did not create the global mcp.json file.'
        Assert-True (Test-Path -LiteralPath $workspaceHelperPath -PathType Leaf) 'sync-vscode-global-mcp did not create the workspace helper file.'
        Assert-True (@(Get-ChildItem -LiteralPath $globalUserPath -Filter 'mcp.json.*.bak' -File).Count -eq 1) 'sync-vscode-global-mcp did not create a global mcp.json backup.'
        $renderedGlobalMcp = Get-Content -LiteralPath $globalMcpPath -Raw
        $renderedHelper = Get-Content -LiteralPath $workspaceHelperPath -Raw
        $renderedDocument = $renderedGlobalMcp | ConvertFrom-Json -Depth 100
        Assert-True ($renderedGlobalMcp -notmatch '%USERPROFILE%') 'sync-vscode-global-mcp did not replace %USERPROFILE% in the global MCP file.'
        Assert-True ($renderedGlobalMcp -match 'tools[/\\\\]run\.ps1') 'sync-vscode-global-mcp did not preserve the rendered MCP command path.'
        Assert-True ($null -ne $renderedDocument.servers.'disabled/by-default') 'sync-vscode-global-mcp lost the profile-enabled server entry.'
        Assert-True (-not ($renderedDocument.servers.'disabled/by-default'.PSObject.Properties.Name -contains 'disabled')) 'sync-vscode-global-mcp did not enable a server selected by the profile.'
        Assert-True (($renderedDocument.servers.'enabled/by-default'.disabled -eq $true)) 'sync-vscode-global-mcp did not disable a server rejected by the profile.'
        Assert-True ($renderedGlobalMcp -eq $renderedHelper) 'sync-vscode-global-mcp did not keep the workspace helper aligned with the global MCP output.'

        & $renderScriptPath -RepoRoot $tempRepoRoot -CatalogPath $catalogPath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-mcp-runtime-artifacts smoke test failed.'
        $renderedTemplatePath = Join-Path $workspaceVscode 'mcp.tamplate.jsonc'
        $renderedManifestPath = Join-Path $tempRepoRoot '.codex\mcp\servers.manifest.json'
        Assert-True (Test-Path -LiteralPath $renderedTemplatePath -PathType Leaf) 'render-mcp-runtime-artifacts did not write the VS Code template.'
        Assert-True (Test-Path -LiteralPath $renderedManifestPath -PathType Leaf) 'render-mcp-runtime-artifacts did not write the Codex manifest.'
        $renderedManifest = Get-Content -LiteralPath $renderedManifestPath -Raw | ConvertFrom-Json -Depth 100
        Assert-True (@($renderedManifest.servers).Count -gt 0) 'render-mcp-runtime-artifacts should emit manifest servers.'

        $renderProviderSkillsScriptPath = Join-Path $runtimeScriptRoot 'render-provider-skill-surfaces.ps1'
        $renderProviderSurfacesScriptPath = Join-Path $runtimeScriptRoot 'render-provider-surfaces.ps1'
        $renderGithubInstructionScriptPath = Join-Path $runtimeScriptRoot 'render-github-instruction-surfaces.ps1'
        $renderVscodeProfilesScriptPath = Join-Path $runtimeScriptRoot 'render-vscode-profile-surfaces.ps1'
        $renderVscodeWorkspaceScriptPath = Join-Path $runtimeScriptRoot 'render-vscode-workspace-surfaces.ps1'
        $renderCodexCompatibilityScriptPath = Join-Path $runtimeScriptRoot 'render-codex-compatibility-surfaces.ps1'
        $renderCodexOrchestrationScriptPath = Join-Path $runtimeScriptRoot 'render-codex-orchestration-surfaces.ps1'
        $renderClaudeRuntimeScriptPath = Join-Path $runtimeScriptRoot 'render-claude-runtime-surfaces.ps1'
        $setupProfilesScriptPath = Join-Path $runtimeScriptRoot 'setup-vscode-profiles.ps1'
        $sharedDefinitionRoot = Join-Path $tempRepoRoot 'definitions\shared'
        $sharedPomlSourceRoot = Join-Path $sharedDefinitionRoot 'prompts\poml'
        $providerSourceRoot = Join-Path $tempRepoRoot 'definitions\providers'
        $githubProviderSourceRoot = Join-Path $providerSourceRoot 'github'
        $codexCompatibilitySourceRoot = Join-Path $providerSourceRoot 'codex'
        $codexSkillSource = Join-Path $providerSourceRoot 'codex\skills\demo-skill'
        $codexMcpSourceRoot = Join-Path $providerSourceRoot 'codex\mcp'
        $codexScriptsSourceRoot = Join-Path $providerSourceRoot 'codex\scripts'
        $claudeSkillSource = Join-Path $providerSourceRoot 'claude\skills\demo-skill'
        $codexOrchestrationSourceRoot = Join-Path $providerSourceRoot 'codex\orchestration'
        $claudeRuntimeSourceRoot = Join-Path $providerSourceRoot 'claude\runtime'
        $vscodeWorkspaceSourceRoot = Join-Path $providerSourceRoot 'vscode\workspace'
        $codexSkillOutput = Join-Path $tempRepoRoot '.codex\skills'
        $codexMcpOutputRoot = Join-Path $tempRepoRoot '.codex\mcp'
        $codexScriptsOutputRoot = Join-Path $tempRepoRoot '.codex\scripts'
        $claudeSkillOutput = Join-Path $tempRepoRoot '.claude\skills'
        $codexOrchestrationOutputRoot = Join-Path $tempRepoRoot '.codex\orchestration'
        $claudeRuntimeOutputRoot = Join-Path $tempRepoRoot '.claude'
        $profileDefinitionRoot = Join-Path $providerSourceRoot 'vscode\profiles'
        $profileOutputRoot = Join-Path $tempRepoRoot '.vscode\profiles'
        $vscodeWorkspaceOutputRoot = Join-Path $tempRepoRoot '.vscode'
        $githubInstructionOutputRoot = Join-Path $tempRepoRoot '.github'

        New-Item -ItemType Directory -Path $codexSkillSource -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $codexSkillSource 'agents') -Force | Out-Null
        New-Item -ItemType Directory -Path $codexMcpSourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $codexScriptsSourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $claudeSkillSource -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $codexOrchestrationSourceRoot 'pipelines') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $codexOrchestrationSourceRoot 'prompts') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $codexOrchestrationSourceRoot 'templates') -Force | Out-Null
        New-Item -ItemType Directory -Path $claudeRuntimeSourceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $vscodeWorkspaceSourceRoot 'snippets') -Force | Out-Null
        New-Item -ItemType Directory -Path $profileDefinitionRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sharedDefinitionRoot 'instructions') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sharedPomlSourceRoot 'templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $sharedDefinitionRoot 'templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $githubProviderSourceRoot 'root') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $githubProviderSourceRoot 'agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $githubProviderSourceRoot 'prompts') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $githubProviderSourceRoot 'chatmodes') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $githubProviderSourceRoot 'hooks\scripts') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRepoRoot 'scripts\runtime') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $codexSkillSource 'SKILL.md') -Value '# Demo Codex Skill' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexSkillSource 'agents\openai.yaml') -Value 'name: demo-skill' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexMcpSourceRoot 'README.md') -Value '# Demo Codex MCP' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexMcpSourceRoot 'codex.config.template.toml') -Value '[mcp_servers.demo]' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexMcpSourceRoot 'vscode.mcp.template.json') -Value '{ "servers": {} }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexScriptsSourceRoot 'README.md') -Value '# Demo Codex Scripts' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexScriptsSourceRoot 'render-vscode-mcp.ps1') -Value @(
            "[CmdletBinding()]",
            "param([string] `$OutputPath)",
            "`$ErrorActionPreference = 'Stop'",
            "function Resolve-CanonicalRuntimeScriptPath {",
            "    param([Parameter(Mandatory = `$true)][string] `$ScriptName)",
            "    return [System.IO.Path]::GetFullPath((Join-Path `$PSScriptRoot (Join-Path '..\\..\\scripts\\runtime' `$ScriptName)))",
            "}",
            "& (Resolve-CanonicalRuntimeScriptPath -ScriptName 'render-vscode-mcp-template.ps1') @PSBoundParameters",
            "exit `$LASTEXITCODE"
        ) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $codexScriptsSourceRoot 'sync-mcp-to-codex-config.ps1') -Value @(
            "[CmdletBinding()]",
            "param([string] `$TargetConfigPath)",
            "`$ErrorActionPreference = 'Stop'",
            "function Resolve-CanonicalRuntimeScriptPath {",
            "    param([Parameter(Mandatory = `$true)][string] `$ScriptName)",
            "    return [System.IO.Path]::GetFullPath((Join-Path `$PSScriptRoot (Join-Path '..\\..\\scripts\\runtime' `$ScriptName)))",
            "}",
            "& (Resolve-CanonicalRuntimeScriptPath -ScriptName 'sync-codex-mcp-config.ps1') @PSBoundParameters",
            "exit `$LASTEXITCODE"
        ) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $claudeSkillSource 'SKILL.md') -Value '# Demo Claude Skill' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexOrchestrationSourceRoot 'README.md') -Value '# Demo Codex Orchestration' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexOrchestrationSourceRoot 'agents.manifest.json') -Value '{ "agents": [] }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexOrchestrationSourceRoot 'pipelines\default.pipeline.json') -Value '{ "stages": [] }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexOrchestrationSourceRoot 'prompts\super-agent-intake-stage.prompt.md') -Value '# Intake Prompt' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $codexOrchestrationSourceRoot 'templates\run-artifact.template.json') -Value '{ "traceId": "" }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $claudeRuntimeSourceRoot 'settings.json') -Value '{ "permissions": { "allow": [] } }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $vscodeWorkspaceSourceRoot 'README.md') -Value '# Demo VS Code Workspace' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $vscodeWorkspaceSourceRoot 'base.code-workspace') -Value '{ "folders": [] }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $vscodeWorkspaceSourceRoot 'settings.tamplate.jsonc') -Value '{ "editor.tabSize": 4 }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $vscodeWorkspaceSourceRoot 'snippets\demo.tamplate.code-snippets') -Value '{ "demo": { "prefix": "demo", "body": ["demo"] } }' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $profileDefinitionRoot 'profile-base.json') -Value @(
            '{',
            '  "name": "Base",',
            '  "description": "Base profile"',
            '}'
        )
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'root\AGENTS.md') -Value '# Demo Agents' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'root\COMMANDS.md') -Value '# Demo Commands' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'root\copilot-instructions.md') -Value '# Demo Instructions' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'root\instruction-routing.catalog.yml') -Value 'routes: []' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'agents\super-agent.agent.md') -Value '# Agent' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $sharedDefinitionRoot 'instructions\super-agent.instructions.md') -Value '# Instruction' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'prompts\route-instructions.prompt.md') -Value '# Prompt' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $sharedPomlSourceRoot 'prompt-engineering-poml.md') -Value '# POML Guide' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $sharedPomlSourceRoot 'templates\changelog-entry.poml') -Value '<poml />' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'chatmodes\demo.chatmode.md') -Value '# Chatmode' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'hooks\super-agent.bootstrap.json') -Value '{}' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'hooks\super-agent.selector.json') -Value '{}' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'hooks\scripts\common.ps1') -Value '# hook common' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'hooks\scripts\session-start.ps1') -Value '# hook session' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'hooks\scripts\subagent-start.ps1') -Value '# hook subagent' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $githubProviderSourceRoot 'hooks\scripts\pre-tool-use.ps1') -Value '# hook pretool' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $sharedDefinitionRoot 'templates\readme-template.md') -Value '# Readme Template' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $tempRepoRoot 'scripts\runtime\render-vscode-mcp-template.ps1') -Value @(
            "param([string] `$OutputPath)",
            "New-Item -ItemType Directory -Path (Split-Path -Path `$OutputPath -Parent) -Force | Out-Null",
            'Set-Content -LiteralPath $OutputPath -Value ''{ "demo": true }'' -Encoding UTF8 -NoNewline'
        ) -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $tempRepoRoot 'scripts\runtime\sync-codex-mcp-config.ps1') -Value @(
            "param([string] `$TargetConfigPath)",
            "New-Item -ItemType Directory -Path (Split-Path -Path `$TargetConfigPath -Parent) -Force | Out-Null",
            "Set-Content -LiteralPath `$TargetConfigPath -Value '[mcp_servers.demo]' -Encoding UTF8 -NoNewline"
        ) -Encoding UTF8

        & $renderProviderSkillsScriptPath -RepoRoot $tempRepoRoot -Provider codex,claude | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-provider-skill-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexSkillOutput 'demo-skill\SKILL.md') -PathType Leaf) 'render-provider-skill-surfaces did not write Codex skill output.'
        Assert-True (Test-Path -LiteralPath (Join-Path $claudeSkillOutput 'demo-skill\SKILL.md') -PathType Leaf) 'render-provider-skill-surfaces did not write Claude skill output.'

        & $renderCodexCompatibilityScriptPath -RepoRoot $tempRepoRoot | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-codex-compatibility-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexMcpOutputRoot 'README.md') -PathType Leaf) 'render-codex-compatibility-surfaces did not write the projected Codex MCP README.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexMcpOutputRoot 'codex.config.template.toml') -PathType Leaf) 'render-codex-compatibility-surfaces did not write the projected Codex config template.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexMcpOutputRoot 'vscode.mcp.template.json') -PathType Leaf) 'render-codex-compatibility-surfaces did not write the projected Codex VS Code template.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexScriptsOutputRoot 'render-vscode-mcp.ps1') -PathType Leaf) 'render-codex-compatibility-surfaces did not write the projected Codex wrapper surface.'

        $wrapperRenderOutputPath = Join-Path $tempRepoRoot '.temp\wrapper-vscode-mcp.json'
        $wrapperConfigOutputPath = Join-Path $tempRepoRoot '.temp\wrapper-config.toml'
        & (Join-Path $codexScriptsOutputRoot 'render-vscode-mcp.ps1') -OutputPath $wrapperRenderOutputPath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'Projected render-vscode-mcp wrapper smoke test failed.'
        Assert-True (Test-Path -LiteralPath $wrapperRenderOutputPath -PathType Leaf) 'Projected render-vscode-mcp wrapper did not forward to the canonical runtime script.'

        & (Join-Path $codexScriptsOutputRoot 'sync-mcp-to-codex-config.ps1') -TargetConfigPath $wrapperConfigOutputPath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'Projected sync-mcp-to-codex-config wrapper smoke test failed.'
        Assert-True (Test-Path -LiteralPath $wrapperConfigOutputPath -PathType Leaf) 'Projected sync-mcp-to-codex-config wrapper did not forward to the canonical runtime script.'

        & $renderVscodeProfilesScriptPath -RepoRoot $tempRepoRoot | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-vscode-profile-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $profileOutputRoot 'profile-base.json') -PathType Leaf) 'render-vscode-profile-surfaces did not write the projected VS Code profile.'

        & $renderGithubInstructionScriptPath -RepoRoot $tempRepoRoot | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-github-instruction-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'AGENTS.md') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected GitHub root files.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'instructions\super-agent.instructions.md') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected GitHub instruction surface.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'chatmodes\demo.chatmode.md') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected GitHub chatmode surface.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'prompts\route-instructions.prompt.md') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected GitHub prompt entrypoint surface.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'prompts\poml\prompt-engineering-poml.md') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected shared POML guide.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'prompts\poml\templates\changelog-entry.poml') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected shared POML template.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'hooks\scripts\session-start.ps1') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected GitHub hook wrapper.'
        Assert-True (Test-Path -LiteralPath (Join-Path $githubInstructionOutputRoot 'templates\readme-template.md') -PathType Leaf) 'render-github-instruction-surfaces did not write the projected GitHub template surface.'

        & $renderVscodeWorkspaceScriptPath -RepoRoot $tempRepoRoot | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-vscode-workspace-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $vscodeWorkspaceOutputRoot 'README.md') -PathType Leaf) 'render-vscode-workspace-surfaces did not write the projected VS Code README.'
        Assert-True (Test-Path -LiteralPath (Join-Path $vscodeWorkspaceOutputRoot 'base.code-workspace') -PathType Leaf) 'render-vscode-workspace-surfaces did not write the projected base.code-workspace.'
        Assert-True (Test-Path -LiteralPath (Join-Path $vscodeWorkspaceOutputRoot 'settings.tamplate.jsonc') -PathType Leaf) 'render-vscode-workspace-surfaces did not write the projected settings template.'
        Assert-True (Test-Path -LiteralPath (Join-Path $vscodeWorkspaceOutputRoot 'snippets\demo.tamplate.code-snippets') -PathType Leaf) 'render-vscode-workspace-surfaces did not write the projected snippets surface.'

        & $renderCodexOrchestrationScriptPath -RepoRoot $tempRepoRoot | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-codex-orchestration-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexOrchestrationOutputRoot 'README.md') -PathType Leaf) 'render-codex-orchestration-surfaces did not write the projected orchestration README.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexOrchestrationOutputRoot 'prompts\super-agent-intake-stage.prompt.md') -PathType Leaf) 'render-codex-orchestration-surfaces did not write the projected prompts surface.'
        Assert-True (Test-Path -LiteralPath (Join-Path $codexOrchestrationOutputRoot 'templates\run-artifact.template.json') -PathType Leaf) 'render-codex-orchestration-surfaces did not write the projected templates surface.'

        & $renderClaudeRuntimeScriptPath -RepoRoot $tempRepoRoot | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-claude-runtime-surfaces smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $claudeRuntimeOutputRoot 'settings.json') -PathType Leaf) 'render-claude-runtime-surfaces did not write the projected Claude settings.'

        & $renderProviderSurfacesScriptPath -RepoRoot $resolvedRepoRoot -ConsumerName bootstrap -EnableCodexRuntime -EnableClaudeRuntime -SummaryOnly | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'render-provider-surfaces bootstrap summary smoke test failed.'

        & $setupProfilesScriptPath -DryRun -SkipMcpSync -RepoRoot $tempRepoRoot -ProfilesRoot $profileDefinitionRoot -ProfileName Base | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'setup-vscode-profiles dry-run smoke test failed.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $tempRepoRoot = Join-Path $tempRoot 'repo'
    $catalogRoot = Join-Path $tempRepoRoot '.github\governance'
    $scriptsRoot = Join-Path $tempRepoRoot 'scripts\runtime'
    $updateIndexScriptPath = Join-Path $runtimeScriptRoot 'update-local-context-index.ps1'
    $queryIndexScriptPath = Join-Path $runtimeScriptRoot 'query-local-context-index.ps1'
    try {
        New-Item -ItemType Directory -Path $catalogRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $scriptsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRepoRoot '.codex') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRepoRoot '.vscode') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $catalogRoot 'local-context-index.catalog.json') -Value @(
            '{',
            '  "version": 1,',
            '  "indexRoot": ".temp/context-index",',
            '  "maxFileSizeKb": 64,',
            '  "chunking": { "maxChars": 400, "maxLines": 20 },',
            '  "queryDefaults": { "top": 3 },',
            '  "includeGlobs": ["README.md", "scripts/**/*.ps1", ".github/**/*.md"],',
            '  "excludeGlobs": [".temp/**"]',
            '}'
        )
        Set-Content -LiteralPath (Join-Path $tempRepoRoot 'README.md') -Value "# Demo`n`nSuper Agent context continuity uses a local context index." -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $tempRepoRoot '.github\AGENTS.md') -Value "# Demo Agents`n`nUse the Super Agent lifecycle." -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $scriptsRoot 'demo.ps1') -Value "Write-Output 'context compaction continuity'" -Encoding UTF8 -NoNewline

        & $updateIndexScriptPath -RepoRoot $tempRepoRoot -DetailedOutput | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'update-local-context-index smoke test failed.'

        $indexPath = Join-Path $tempRepoRoot '.temp\context-index\index.json'
        Assert-True (Test-Path -LiteralPath $indexPath -PathType Leaf) 'update-local-context-index did not write index.json.'
        $indexDocument = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json -Depth 100
        Assert-True (@($indexDocument.files).Count -gt 0) 'update-local-context-index should index at least one file.'

        $queryJson = & $queryIndexScriptPath -RepoRoot $tempRepoRoot -QueryText 'context continuity' -JsonOutput
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'query-local-context-index smoke test failed.'
        $queryResult = $queryJson | ConvertFrom-Json -Depth 100
        Assert-True ([int] $queryResult.resultCount -gt 0) 'query-local-context-index should return at least one hit for indexed content.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $targetGithub = Join-Path $tempRoot '.github'
    $targetCodex = Join-Path $tempRoot '.codex'
    $targetAgentsSkills = Join-Path $tempRoot '.agents\skills'
    $targetCopilotSkills = Join-Path $tempRoot '.copilot\skills'
    $targetGithubSkills = Join-Path $targetGithub 'skills'
    $targetCodexSkills = Join-Path $targetCodex 'skills'
    $scriptPath = Join-Path $runtimeScriptRoot 'bootstrap.ps1'
    try {
        New-Item -ItemType Directory -Path (Join-Path $targetCodexSkills 'super-agent') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetCodexSkills '.system') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetGithubSkills 'super-agent') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetGithubSkills 'using-super-agent') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetCopilotSkills 'super-agent') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetCopilotSkills 'using-super-agent') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $targetCodexSkills 'super-agent\SKILL.md') -Value 'duplicate'
        Set-Content -LiteralPath (Join-Path $targetCodexSkills '.system\SKILL.md') -Value 'system'
        Set-Content -LiteralPath (Join-Path $targetGithubSkills 'super-agent\SKILL.md') -Value 'legacy'
        Set-Content -LiteralPath (Join-Path $targetGithubSkills 'using-super-agent\SKILL.md') -Value 'legacy'
        Set-Content -LiteralPath (Join-Path $targetCopilotSkills 'super-agent\SKILL.md') -Value 'legacy'
        Set-Content -LiteralPath (Join-Path $targetCopilotSkills 'using-super-agent\SKILL.md') -Value 'legacy'

        & $scriptPath -RepoRoot $resolvedRepoRoot -TargetGithubPath $targetGithub -TargetCodexPath $targetCodex -TargetAgentsSkillsPath $targetAgentsSkills -TargetCopilotSkillsPath $targetCopilotSkills -Mirror | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'bootstrap smoke test failed.'
        Assert-True (Test-Path -LiteralPath $targetGithub -PathType Container) 'bootstrap did not create target github folder.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetGithub 'agents\super-agent.agent.md') -PathType Leaf) 'bootstrap did not project the repository-owned Copilot agent profile.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetAgentsSkills 'super-agent\SKILL.md') -PathType Leaf) 'bootstrap did not project picker-visible skills.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetGithubSkills 'super-agent'))) 'bootstrap did not remove the mirrored GitHub runtime super-agent starter duplicate.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetGithubSkills 'using-super-agent'))) 'bootstrap did not remove the mirrored GitHub runtime using-super-agent starter duplicate.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetCopilotSkills 'super-agent'))) 'bootstrap did not remove the legacy native Copilot super-agent starter.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetCopilotSkills 'using-super-agent'))) 'bootstrap did not remove the legacy native Copilot using-super-agent starter.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetCodexSkills 'super-agent'))) 'bootstrap did not remove duplicate repo-managed super-agent from .codex/skills.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetCodexSkills '.system\SKILL.md') -PathType Leaf) 'bootstrap should preserve unmanaged/system skills in .codex/skills.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetCodex 'shared-scripts') -PathType Container) 'bootstrap did not sync shared-scripts folder.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetCodex 'shared-scripts\maintenance\trim-trailing-blank-lines.ps1') -PathType Leaf) 'bootstrap did not project maintenance trim script into shared-scripts.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $targetGithub = Join-Path $tempRoot '.github'
    $targetCodex = Join-Path $tempRoot '.codex'
    $targetAgentsSkills = Join-Path $tempRoot '.agents\skills'
    $targetCopilotSkills = Join-Path $tempRoot '.copilot\skills'
    $scriptPath = Join-Path $runtimeScriptRoot 'bootstrap.ps1'
    try {
        New-Item -ItemType Directory -Path (Join-Path $targetCopilotSkills 'super-agent') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $targetGithub 'skills\super-agent') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $targetCopilotSkills 'super-agent\SKILL.md') -Value 'legacy'
        Set-Content -LiteralPath (Join-Path $targetGithub 'skills\super-agent\SKILL.md') -Value 'legacy'
        & $scriptPath -RepoRoot $resolvedRepoRoot -TargetGithubPath $targetGithub -TargetCodexPath $targetCodex -TargetAgentsSkillsPath $targetAgentsSkills -TargetCopilotSkillsPath $targetCopilotSkills -RuntimeProfile github | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'bootstrap github-profile smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetGithub 'agents\super-agent.agent.md') -PathType Leaf) 'bootstrap github profile must project repository-owned GitHub runtime files.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetGithub 'skills\super-agent'))) 'bootstrap github profile must remove mirrored GitHub runtime starter duplicates.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetCopilotSkills 'super-agent'))) 'bootstrap github profile must remove legacy native Copilot starters instead of projecting a second managed starter.'
        Assert-True (-not (Test-Path -LiteralPath $targetAgentsSkills)) 'bootstrap github profile must not project Codex picker-visible skills.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetCodex 'shared-scripts'))) 'bootstrap github profile must not project Codex shared scripts.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $scriptPath = Join-Path $runtimeScriptRoot 'export-planning-summary.ps1'
    $updateIndexScriptPath = Join-Path $runtimeScriptRoot 'update-local-context-index.ps1'
    try {
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.github') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.github\governance') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'planning\active') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'planning\specs\active') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tempRoot '.github\governance\local-context-index.catalog.json') -Value @(
            '{',
            '  "version": 1,',
            '  "indexRoot": ".temp/context-index",',
            '  "maxFileSizeKb": 256,',
            '  "chunking": {',
            '    "maxChars": 1600,',
            '    "maxLines": 40',
            '  },',
            '  "queryDefaults": {',
            '    "top": 5',
            '  },',
            '  "includeGlobs": [',
            '    "README.md",',
            '    "planning/**/*.md"',
            '  ],',
            '  "excludeGlobs": [',
            '    ".temp/**"',
            '  ]',
            '}'
        )
        Set-Content -LiteralPath (Join-Path $tempRoot 'planning\active\plan-example.md') -Value @(
            '# Example Plan',
            '',
            'State: in_progress',
            '',
            'Current urgent slice in progress: finish cleanup regression safely.',
            '',
            'Longer details that should not be dumped verbatim into the handoff summary.'
        )
        Set-Content -LiteralPath (Join-Path $tempRoot 'planning\specs\active\spec-example.md') -Value @(
            '# Example Spec',
            '',
            'Status: active',
            '',
            'Objective: keep context recovery concise and planning-anchored.'
        )
        Set-Content -LiteralPath (Join-Path $tempRoot 'README.md') -Value @(
            '# Example Runtime README',
            '',
            'This file documents cleanup regression handling and planning-anchored continuity recovery.'
        )

        & $updateIndexScriptPath -RepoRoot $tempRoot | Out-Null

        $summary = & $scriptPath -RepoRoot $tempRoot -PrintOnly
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'export-planning-summary smoke test failed.'
        Assert-True ($summary -match 'Example Plan') 'export-planning-summary did not include the active plan title.'
        Assert-True ($summary -match 'finish cleanup regression safely') 'export-planning-summary did not include the concise current focus.'
        Assert-True ($summary -match 'Example Spec') 'export-planning-summary did not include the active spec title.'
        Assert-True ($summary -match 'Suggested Local References') 'export-planning-summary should include suggested indexed references when a local context index exists.'
        Assert-True ($summary -match 'README\.md') 'export-planning-summary should reference indexed repository files outside the active plan/spec when available.'
        Assert-True ($summary -notmatch 'Full plan content') 'export-planning-summary should stay concise instead of embedding full plan content.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $scriptPath = Join-Path $runtimeScriptRoot 'export-planning-summary.ps1'
    try {
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.build\super-agent\planning\active') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.build\super-agent\specs\active') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tempRoot '.build\super-agent\planning\active\plan-global.md') -Value @(
            '# Global Runtime Plan',
            '',
            '- State: in_progress',
            '- Current urgent slice in progress: continue after compaction from .build artifacts.'
        )
        Set-Content -LiteralPath (Join-Path $tempRoot '.build\super-agent\specs\active\spec-global.md') -Value @(
            '# Global Runtime Spec',
            '',
            '## Objective',
            '',
            'Recover continuity in global-runtime mode.'
        )

        $summary = & $scriptPath -RepoRoot $tempRoot -PrintOnly
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'export-planning-summary .build fallback smoke test failed.'
        Assert-True ($summary -match 'Global Runtime Plan') 'export-planning-summary should include the .build active plan title.'
        Assert-True ($summary -match 'Global Runtime Spec') 'export-planning-summary should include the .build active spec title.'
        Assert-True ($summary -match '\.build/super-agent/planning/active') 'export-planning-summary should describe the .build planning surface when no workspace planning exists.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $scriptPath = Join-Path $runtimeScriptRoot 'invoke-super-agent-housekeeping.ps1'
    try {
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.github') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'planning\active') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'planning\specs\active') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tempRoot 'planning\active\plan-housekeeping.md') -Value @(
            '# Housekeeping Plan',
            '',
            '- State: in_progress',
            '- Current urgent slice in progress: export handoff before cleanup.'
        )
        Set-Content -LiteralPath (Join-Path $tempRoot 'planning\specs\active\spec-housekeeping.md') -Value @(
            '# Housekeeping Spec',
            '',
            '## Objective',
            '',
            'Keep context recovery planning-anchored.'
        )

        $recordPath = Join-Path $tempRoot '.temp\housekeeping-record.json'
        $statePath = Join-Path $tempRoot '.temp\housekeeping-state.json'
        & $scriptPath -WorkspacePath $tempRoot -RepoRoot $tempRoot -StateFilePath $statePath -BypassThrottle -RecordOnlyPath $recordPath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'invoke-super-agent-housekeeping record-only smoke test failed.'
        Assert-True (Test-Path -LiteralPath $recordPath -PathType Leaf) 'invoke-super-agent-housekeeping did not emit the record-only artifact.'
        Assert-True (Test-Path -LiteralPath $statePath -PathType Leaf) 'invoke-super-agent-housekeeping did not persist state in record-only mode.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $globalUserPath = Join-Path $tempRoot 'Code\User'
    $workspaceStorageRoot = Join-Path $globalUserPath 'workspaceStorage'
    $staleWorkspaceRoot = Join-Path $workspaceStorageRoot 'stale-workspace'
    $activeWorkspaceRoot = Join-Path $workspaceStorageRoot 'active-workspace'
    $chatSessionsRoot = Join-Path $activeWorkspaceRoot 'chatSessions'
    $editingSessionsRoot = Join-Path $activeWorkspaceRoot 'chatEditingSessions'
    $copilotChatRoot = Join-Path $activeWorkspaceRoot 'GitHub.copilot-chat'
    $transcriptsRoot = Join-Path $copilotChatRoot 'transcripts'
    $historyRoot = Join-Path $globalUserPath 'History'
    $emptyWindowRoot = Join-Path $globalUserPath 'globalStorage\emptyWindowChatSessions'
    $scriptPath = Join-Path $runtimeScriptRoot 'clean-vscode-user-runtime.ps1'
    try {
        New-Item -ItemType Directory -Path $staleWorkspaceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $chatSessionsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $editingSessionsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $transcriptsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $historyRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $emptyWindowRoot -Force | Out-Null

        $staleWorkspaceFile = Join-Path $staleWorkspaceRoot 'workspace.json'
        $oldChatSession = Join-Path $chatSessionsRoot 'old.jsonl'
        $oldEditingSession = Join-Path $editingSessionsRoot 'draft.tmp'
        $oldTranscript = Join-Path $transcriptsRoot 'old-transcript.jsonl'
        $oldHistoryFile = Join-Path $historyRoot 'old.history'
        $oldEmptyWindowSession = Join-Path $emptyWindowRoot 'empty-session.jsonl'
        $settingsBackup = Join-Path $globalUserPath 'settings.json.20260323-010101.bak'
        $oversizedChatSession = Join-Path $chatSessionsRoot 'oversized.jsonl'
        $oversizedWorkspaceIndex = Join-Path $copilotChatRoot 'local-index.1.db'

        Set-Content -LiteralPath $staleWorkspaceFile -Value 'stale'
        Set-Content -LiteralPath $oldChatSession -Value 'chat'
        Set-Content -LiteralPath $oldEditingSession -Value 'editing'
        Set-Content -LiteralPath $oldTranscript -Value 'transcript'
        Set-Content -LiteralPath $oldHistoryFile -Value 'history'
        Set-Content -LiteralPath $oldEmptyWindowSession -Value 'empty'
        Set-Content -LiteralPath $settingsBackup -Value 'backup'
        [System.IO.File]::WriteAllBytes($oversizedChatSession, (New-Object byte[] (2MB)))
        [System.IO.File]::WriteAllBytes($oversizedWorkspaceIndex, (New-Object byte[] (3MB)))

        $expiredDate = (Get-Date).AddDays(-40)
        foreach ($path in @($staleWorkspaceRoot, $staleWorkspaceFile, $oldChatSession, $oldEditingSession, $oldTranscript, $oldHistoryFile, $oldEmptyWindowSession, $settingsBackup)) {
            if (Test-Path -LiteralPath $path) {
                (Get-Item -LiteralPath $path).LastWriteTime = $expiredDate
            }
        }
        foreach ($path in @($oversizedChatSession, $oversizedWorkspaceIndex)) {
            if (Test-Path -LiteralPath $path) {
                (Get-Item -LiteralPath $path).LastWriteTime = (Get-Date).AddHours(-30)
            }
        }

        & $scriptPath -GlobalVscodeUserPath $globalUserPath -WorkspaceStorageRetentionDays 30 -ChatSessionRetentionDays 14 -ChatEditingSessionRetentionDays 7 -TranscriptRetentionDays 14 -HistoryRetentionDays 30 -SettingsBackupRetentionDays 30 -MaxChatSessionFileSizeMB 1 -MaxCopilotWorkspaceIndexSizeMB 1 -OversizedFileGraceHours 1 -RecentRunWindowHours 0 -Apply | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'clean-vscode-user-runtime smoke test failed.'
        Assert-True (-not (Test-Path -LiteralPath $staleWorkspaceRoot)) 'clean-vscode-user-runtime did not remove stale workspaceStorage directory.'
        Assert-True (-not (Test-Path -LiteralPath $oldChatSession)) 'clean-vscode-user-runtime did not remove expired chat session.'
        Assert-True (-not (Test-Path -LiteralPath $oldEditingSession)) 'clean-vscode-user-runtime did not remove expired chat editing session.'
        Assert-True (-not (Test-Path -LiteralPath $oldTranscript)) 'clean-vscode-user-runtime did not remove expired transcript.'
        Assert-True (-not (Test-Path -LiteralPath $oldHistoryFile)) 'clean-vscode-user-runtime did not remove expired History file.'
        Assert-True (-not (Test-Path -LiteralPath $oldEmptyWindowSession)) 'clean-vscode-user-runtime did not remove expired empty-window session.'
        Assert-True (-not (Test-Path -LiteralPath $settingsBackup)) 'clean-vscode-user-runtime did not remove expired settings backup.'
        Assert-True (-not (Test-Path -LiteralPath $oversizedChatSession)) 'clean-vscode-user-runtime did not remove oversized chat session.'
        Assert-True (-not (Test-Path -LiteralPath $oversizedWorkspaceIndex)) 'clean-vscode-user-runtime did not remove oversized workspace index.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $targetGithub = Join-Path $tempRoot '.github'
    $targetCodex = Join-Path $tempRoot '.codex'
    $targetAgentsSkills = Join-Path $tempRoot '.agents\skills'
    $targetCopilotSkills = Join-Path $tempRoot '.copilot\skills'
    $scriptPath = Join-Path $runtimeScriptRoot 'bootstrap.ps1'
    try {
        & $scriptPath -RepoRoot $resolvedRepoRoot -TargetGithubPath $targetGithub -TargetCodexPath $targetCodex -TargetAgentsSkillsPath $targetAgentsSkills -TargetCopilotSkillsPath $targetCopilotSkills -RuntimeProfile codex | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'bootstrap codex-profile smoke test failed.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetAgentsSkills 'super-agent\SKILL.md') -PathType Leaf) 'bootstrap codex profile must project picker-visible skills.'
        Assert-True (Test-Path -LiteralPath (Join-Path $targetCodex 'shared-scripts\maintenance\trim-trailing-blank-lines.ps1') -PathType Leaf) 'bootstrap codex profile must project Codex shared scripts.'
        Assert-True (-not (Test-Path -LiteralPath $targetGithub)) 'bootstrap codex profile must not project the GitHub runtime root.'
        Assert-True (-not (Test-Path -LiteralPath $targetCopilotSkills)) 'bootstrap codex profile must not project native Copilot skills.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $codexHome = Join-Path $tempRoot '.codex'
    $tmpDir = Join-Path $codexHome 'tmp'
    $logDir = Join-Path $codexHome 'log'
    $sessionsDir = Join-Path $codexHome 'sessions'
    $oldLog = Join-Path $logDir 'old.log'
    $oldSession = Join-Path $sessionsDir 'old-session.json'
    $tempFile = Join-Path $tmpDir 'temp.txt'
    $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'
    try {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
        Set-Content -LiteralPath $tempFile -Value 'temp'
        Set-Content -LiteralPath $oldLog -Value 'log'
        Set-Content -LiteralPath $oldSession -Value 'session'
        $expiredDate = (Get-Date).AddDays(-10)
        (Get-Item -LiteralPath $oldLog).LastWriteTime = $expiredDate
        (Get-Item -LiteralPath $oldSession).LastWriteTime = $expiredDate
        & $scriptPath -CodexHome $codexHome -IncludeSessions -SessionRetentionDays 1 -LogRetentionDays 1 -Apply | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'clean-codex-runtime smoke test failed.'
        Assert-True (-not (Test-Path -LiteralPath $tempFile)) 'clean-codex-runtime did not remove tmp file.'
        Assert-True (-not (Test-Path -LiteralPath $oldLog)) 'clean-codex-runtime did not remove old log.'
        Assert-True (-not (Test-Path -LiteralPath $oldSession)) 'clean-codex-runtime did not remove old session.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $codexHome = Join-Path $tempRoot '.codex'
    $tmpDir = Join-Path $codexHome 'tmp'
    $logDir = Join-Path $codexHome 'log'
    $sessionsDir = Join-Path $codexHome 'sessions'
    $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'
    try {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
        & $scriptPath -CodexHome $codexHome -IncludeSessions -SessionRetentionDays 1 -LogRetentionDays 1 -Apply | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'clean-codex-runtime must tolerate empty log/session collections.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $codexHome = Join-Path $tempRoot '.codex'
    $sessionsDir = Join-Path $codexHome 'sessions\2026\03\17'
    $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'
    try {
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
        $oversizedSession = Join-Path $sessionsDir 'oversized.jsonl'
        $budgetSession = Join-Path $sessionsDir 'budget.jsonl'
        [System.IO.File]::WriteAllBytes($oversizedSession, (New-Object byte[] (2MB)))
        [System.IO.File]::WriteAllBytes($budgetSession, (New-Object byte[] (3MB)))
        $expiredDate = (Get-Date).AddDays(-3)
        (Get-Item -LiteralPath $oversizedSession).LastWriteTime = $expiredDate
        (Get-Item -LiteralPath $budgetSession).LastWriteTime = $expiredDate

        & $scriptPath -CodexHome $codexHome -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 14 -MaxSessionFileSizeMB 1 -OversizedSessionGraceHours 1 -MaxSessionStorageGB 1 -SessionStorageGraceHours 1 -Apply | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'clean-codex-runtime oversized/budget smoke test failed.'
        Assert-True (-not (Test-Path -LiteralPath $budgetSession)) 'clean-codex-runtime did not remove oversized or budget-pruned session file.'
        Assert-True (-not (Test-Path -LiteralPath $oversizedSession)) 'clean-codex-runtime did not remove the oversized session file.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $codexHome = Join-Path $tempRoot '.codex'
    $sessionsDir = Join-Path $codexHome 'sessions\2026\03\17'
    $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'
    try {
        New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null
        $recentLargeSession = Join-Path $sessionsDir 'recent-large.jsonl'
        [System.IO.File]::WriteAllBytes($recentLargeSession, (New-Object byte[] (3MB)))
        (Get-Item -LiteralPath $recentLargeSession).LastWriteTime = (Get-Date).AddDays(-3)

        & $scriptPath -CodexHome $codexHome -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 14 -Apply | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'clean-codex-runtime default retention smoke test failed.'
        Assert-True (Test-Path -LiteralPath $recentLargeSession) 'clean-codex-runtime should preserve recent active sessions when oversized/budget cleanup is not explicitly enabled.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $configPath = Join-Path $tempRoot 'config.toml'
    $scriptPath = Join-Path $runtimeScriptRoot 'set-codex-runtime-preferences.ps1'
    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        Set-Content -LiteralPath $configPath -Value @(
            'model = "gpt-5.4"',
            'model_reasoning_effort = "xhigh"',
            '',
            '[features]',
            'multi_agent = false'
        )

        & $scriptPath -RepoRoot $resolvedRepoRoot -TargetConfigPath $configPath -ReasoningEffort high | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'set-codex-runtime-preferences smoke test failed.'
        $content = Get-Content -LiteralPath $configPath -Raw
        Assert-True ($content -match 'model_reasoning_effort = "high"') 'set-codex-runtime-preferences did not update model_reasoning_effort.'
        Assert-True ($content -match 'multi_agent = true') 'set-codex-runtime-preferences did not restore the catalog default multi_agent mode.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host '[OK] runtime script tests passed.'
    exit 0
}
catch {
    $message = $_.Exception.Message
    $trace = $_.ScriptStackTrace
    if ([string]::IsNullOrWhiteSpace($trace)) {
        Write-Host ("[FAIL] runtime script tests failed: {0}" -f $message)
    }
    else {
        Write-Host ("[FAIL] runtime script tests failed: {0}`n{1}" -f $message, $trace)
    }
    exit 1
}