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
    Assert-Contains -Collection $keys -Value 'ProfilePath' -Message 'sync-vscode-global-mcp missing ProfilePath parameter.'
    Assert-Contains -Collection $keys -Value 'SyncWorkspaceHelper' -Message 'sync-vscode-global-mcp missing SyncWorkspaceHelper parameter.'
    Assert-Contains -Collection $keys -Value 'CreateBackup' -Message 'sync-vscode-global-mcp missing CreateBackup parameter.'

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
    $workspaceVscode = Join-Path $tempRoot '.vscode'
    $globalUserPath = Join-Path $tempRoot 'Code\User'
    $globalMcpPath = Join-Path $globalUserPath 'mcp.json'
    $workspaceHelperPath = Join-Path $workspaceVscode 'mcp-vscode-global.json'
    $profilePath = Join-Path $workspaceVscode 'profiles\profile-frontend.json'
    $scriptPath = Join-Path $runtimeScriptRoot 'sync-vscode-global-mcp.ps1'
    try {
        New-Item -ItemType Directory -Path $workspaceVscode -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path -Path $profilePath -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path $globalUserPath -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $workspaceVscode 'mcp.tamplate.jsonc') -Value @(
            '{',
            '  "inputs": [',
            '    {',
            '      "id": "Authorization",',
            '      "type": "promptString",',
            '      "description": "Token",',
            '      "password": true',
            '    }',
            '  ],',
            '  "servers": {',
            '    "example/server": {',
            '      "type": "stdio",',
            '      "command": "pwsh",',
            '      "args": [',
            '        "%USERPROFILE%/tools/run.ps1"',
            '      ]',
            '    },',
            '    "disabled/by-default": {',
            '      "disabled": true,',
            '      "type": "http",',
            '      "url": "https://example.invalid/mcp"',
            '    },',
            '    "enabled/by-default": {',
            '      "type": "http",',
            '      "url": "https://example.invalid/enabled"',
            '    }',
            '  }',
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

        & $scriptPath -RepoRoot $resolvedRepoRoot -WorkspaceVscodePath $workspaceVscode -GlobalVscodeUserPath $globalUserPath -WorkspaceHelperPath $workspaceHelperPath -ProfilePath $profilePath -CreateBackup | Out-Null
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
    try {
        New-Item -ItemType Directory -Path (Join-Path $tempRoot '.github') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'planning\active') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tempRoot 'planning\specs\active') -Force | Out-Null
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

        $summary = & $scriptPath -RepoRoot $tempRoot -PrintOnly
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-True ($exitCode -eq 0) 'export-planning-summary smoke test failed.'
        Assert-True ($summary -match 'Example Plan') 'export-planning-summary did not include the active plan title.'
        Assert-True ($summary -match 'finish cleanup regression safely') 'export-planning-summary did not include the concise current focus.'
        Assert-True ($summary -match 'Example Spec') 'export-planning-summary did not include the active spec title.'
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