<#
.SYNOPSIS
    Runtime tests for repository-owned VS Code agent hook scripts.

.DESCRIPTION
    Validates the simplified SessionStart, PreToolUse, and SubagentStart hook
    payload contracts used to bootstrap Copilot and Codex sessions inside
    VS Code.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing
    .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1

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

# Creates and returns a disposable temporary workspace path.
function New-TemporaryWorkspacePath {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('super-agent-workspace-' + [guid]::NewGuid().ToString('N'))
    [void] (New-Item -ItemType Directory -Path $path -Force)
    return $path
}

# Invokes a hook script with a compact JSON payload and returns the parsed result.
function Invoke-HookScript {
    param(
        [string] $ScriptPath,
        [hashtable] $Payload
    )

    $output = ($Payload | ConvertTo-Json -Depth 20 -Compress | & pwsh -NoLogo -NoProfile -File $ScriptPath)
    return ($output | ConvertFrom-Json -Depth 50)
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$sessionStartScript = Join-Path $resolvedRepoRoot '.github/hooks/scripts/session-start.ps1'
$preToolUseScript = Join-Path $resolvedRepoRoot '.github/hooks/scripts/pre-tool-use.ps1'
$subagentStartScript = Join-Path $resolvedRepoRoot '.github/hooks/scripts/subagent-start.ps1'

$workspacePath = New-TemporaryWorkspacePath
$globalWorkspacePath = New-TemporaryWorkspacePath
$housekeepingStatePath = Join-Path $workspacePath '.temp\housekeeping-state.json'
$housekeepingRecordPath = Join-Path $workspacePath '.temp\housekeeping-record.json'

try {
    New-Item -ItemType Directory -Path (Join-Path $workspacePath '.github\prompts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspacePath 'planning\active') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspacePath 'planning\specs\active') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $workspacePath '.github\AGENTS.md') -Value '# Workspace agents'
    Set-Content -LiteralPath (Join-Path $workspacePath '.github\copilot-instructions.md') -Value '# Workspace instructions'
    Set-Content -LiteralPath (Join-Path $workspacePath '.github\instruction-routing.catalog.yml') -Value 'routes: []'
    Set-Content -LiteralPath (Join-Path $workspacePath '.github\prompts\route-instructions.prompt.md') -Value '# Route prompt'
    Set-Content -LiteralPath (Join-Path $workspacePath 'planning\README.md') -Value '# Planning root'
    Set-Content -LiteralPath (Join-Path $workspacePath 'planning\specs\README.md') -Value '# Planning specs root'
    Set-Content -LiteralPath (Join-Path $workspacePath 'planning\active\plan-safe-housekeeping.md') -Value @(
        '# Safe Housekeeping Plan',
        '',
        '- State: in_progress',
        '- Current urgent slice in progress: export planning handoff before cleanup and throttle repeated housekeeping safely.',
        '',
        '## Objective',
        '',
        'Ensure continuity summaries survive context compaction without replaying giant chat histories.'
    )
    Set-Content -LiteralPath (Join-Path $workspacePath 'planning\specs\active\spec-safe-housekeeping.md') -Value @(
        '# Safe Housekeeping Spec',
        '',
        '## Objective',
        '',
        'Keep context recovery anchored in planning artifacts and clean only persisted runtime state.'
    )
    Set-Content -LiteralPath (Join-Path $workspacePath '.editorconfig') -Value @(
        'root = true',
        '',
        '[*]',
        'insert_final_newline = false'
    )
    Set-Content -LiteralPath (Join-Path $workspacePath 'README.md') -Value '# temp workspace' -NoNewline

    [void] (New-Item -ItemType Directory -Path (Join-Path $globalWorkspacePath '.build\super-agent\planning\active') -Force)
    [void] (New-Item -ItemType Directory -Path (Join-Path $globalWorkspacePath '.build\super-agent\specs\active') -Force)
    Set-Content -LiteralPath (Join-Path $globalWorkspacePath '.build\super-agent\planning\active\plan-global-housekeeping.md') -Value @(
        '# Global Runtime Housekeeping Plan',
        '',
        '- State: in_progress',
        '- Current urgent slice in progress: rebuild continuity from .build planning artifacts after compaction.',
        '',
        '## Objective',
        '',
        'Use global-runtime planning artifacts when the workspace has no local planning surface.'
    )
    Set-Content -LiteralPath (Join-Path $globalWorkspacePath '.build\super-agent\specs\active\spec-global-housekeeping.md') -Value @(
        '# Global Runtime Housekeeping Spec',
        '',
        '## Objective',
        '',
        'Preserve continuity in global-runtime mode without local workspace adapters.'
    )
    Set-Content -LiteralPath (Join-Path $globalWorkspacePath 'README.md') -Value '# temp workspace' -NoNewline

    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_FOREGROUND', '1', 'Process')
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_STATE_PATH', $housekeepingStatePath, 'Process')
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_RECORD_ONLY_PATH', $housekeepingRecordPath, 'Process')
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_INTERVAL_HOURS', '2', 'Process')

    $sessionPayload = [ordered]@{
        cwd = $workspacePath
        source = 'new'
        sessionId = 'session-123'
        hookEventName = 'SessionStart'
    }

    $subagentPayload = [ordered]@{
        cwd = $workspacePath
        sessionId = 'session-123'
        hookEventName = 'SubagentStart'
        agent_id = 'subagent-123'
        agent_type = 'reviewer'
    }

    $preToolReplacePayload = [ordered]@{
        cwd = $workspacePath
        sessionId = 'session-123'
        hookEventName = 'PreToolUse'
        tool_name = 'replaceString'
        tool_use_id = 'tool-123'
        tool_input = [ordered]@{
            filePath = (Join-Path $workspacePath 'README.md')
            oldString = 'before'
            newString = "after`r`n"
        }
    }

    $preToolCreatePayload = [ordered]@{
        cwd = $workspacePath
        sessionId = 'session-123'
        hookEventName = 'PreToolUse'
        tool_name = 'createFile'
        tool_use_id = 'tool-456'
        tool_input = [ordered]@{
            filePath = (Join-Path $workspacePath '.temp/hook-test.txt')
            content = "line one`nline two`n"
        }
    }

    $sessionResult = Invoke-HookScript -ScriptPath $sessionStartScript -Payload $sessionPayload
    $preToolReplaceResult = Invoke-HookScript -ScriptPath $preToolUseScript -Payload $preToolReplacePayload
    $preToolCreateResult = Invoke-HookScript -ScriptPath $preToolUseScript -Payload $preToolCreatePayload
    $subagentResult = Invoke-HookScript -ScriptPath $subagentStartScript -Payload $subagentPayload

    Assert-True ($sessionResult.hookSpecificOutput.hookEventName -eq 'SessionStart') 'SessionStart hook should return SessionStart payload.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'Selected startup controller: Super Agent \(\$super-agent\) via default') 'SessionStart hook should advertise the default startup controller.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match '\[Super Agent: ACTIVE \| controller=Super Agent \| skill=super-agent \| mode=workspace-adapter') 'SessionStart hook should expose a visible activation banner in workspace-adapter mode.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'first substantive assistant reply') 'SessionStart hook should require the one-time visibility confirmation in the first substantive reply.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'Super Agent lifecycle is mandatory') 'SessionStart hook should inject Super Agent lifecycle guidance.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'Planning root: planning/active -> planning/completed') 'SessionStart hook should use workspace planning roots in workspace-adapter mode.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'Spec root: planning/specs/active -> planning/specs/completed') 'SessionStart hook should use workspace spec roots in workspace-adapter mode.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'Continuity summary:') 'SessionStart hook should inject a continuity summary.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'plan-safe-housekeeping\.md') 'SessionStart hook should reference the active plan artifact in the continuity summary.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'spec-safe-housekeeping\.md') 'SessionStart hook should reference the active spec artifact in the continuity summary.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'resume from these artifacts first') 'SessionStart hook should tell the agent to resume from plan/spec after compaction.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'insert_final_newline = false') 'SessionStart hook should mention the repository EOF policy.'
    Assert-True ([string] $sessionResult.hookSpecificOutput.additionalContext -match 'Keep non-versioned build outputs under \.build/ and deployment/runtime publish outputs under \.deployment/') 'SessionStart hook should mention the shared artifact layout policy.'
    Assert-True (Test-Path -LiteralPath $housekeepingRecordPath -PathType Leaf) 'SessionStart hook should dispatch housekeeping when the throttle window has expired.'
    Assert-True (Test-Path -LiteralPath $housekeepingStatePath -PathType Leaf) 'SessionStart hook should persist housekeeping state.'

    Assert-True ($preToolReplaceResult.hookSpecificOutput.hookEventName -eq 'PreToolUse') 'PreToolUse hook should return PreToolUse payload.'
    Assert-True ([string] $preToolReplaceResult.hookSpecificOutput.additionalContext -match 'do not append a terminal newline') 'PreToolUse hook should remind the model about the EOF policy.'
    Assert-True ([string] $preToolReplaceResult.hookSpecificOutput.updatedInput.newString -eq 'after') 'PreToolUse hook should strip a terminal newline from replaceString.newString.'
    Assert-True ([string] $preToolCreateResult.hookSpecificOutput.updatedInput.content -eq "line one`nline two") 'PreToolUse hook should strip a terminal newline from createFile.content.'

    $firstRecord = Get-Content -Raw -LiteralPath $housekeepingRecordPath | ConvertFrom-Json -Depth 20
    Assert-True ([string] $firstRecord.workspacePath -eq $workspacePath) 'Housekeeping record should target the active workspace.'

    Remove-Item -LiteralPath $housekeepingRecordPath -Force
    $subagentResult = Invoke-HookScript -ScriptPath $subagentStartScript -Payload $subagentPayload

    Assert-True ($subagentResult.hookSpecificOutput.hookEventName -eq 'SubagentStart') 'SubagentStart hook should return SubagentStart payload.'
    Assert-True ([string] $subagentResult.hookSpecificOutput.additionalContext -match 'reviewer') 'SubagentStart hook should mention the spawned worker type.'
    Assert-True ([string] $subagentResult.hookSpecificOutput.additionalContext -match '\[Super Agent: ACTIVE \| controller=Super Agent \| skill=super-agent \| mode=workspace-adapter') 'SubagentStart hook should propagate the visibility banner in workspace-adapter mode.'
    Assert-True ([string] $subagentResult.hookSpecificOutput.additionalContext -match 'Planning root: planning/active') 'SubagentStart hook should preserve workspace planning roots.'
    Assert-True ([string] $subagentResult.hookSpecificOutput.additionalContext -match 'Continuity summary:') 'SubagentStart hook should propagate the continuity summary.'
    Assert-True ([string] $subagentResult.hookSpecificOutput.additionalContext -match 'insert_final_newline = false') 'SubagentStart hook should preserve workspace EOF guidance.'
    Assert-True (-not (Test-Path -LiteralPath $housekeepingRecordPath -PathType Leaf)) 'SubagentStart hook should not re-dispatch housekeeping inside the throttle window.'

    $stateFile = Get-Content -Raw -LiteralPath $housekeepingStatePath | ConvertFrom-Json -Depth 20
    $stateFile.lastAttemptAt = (Get-Date).AddHours(-3).ToString('o')
    $stateFile.lastRunAt = (Get-Date).AddHours(-3).ToString('o')
    ($stateFile | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $housekeepingStatePath

    $globalSessionPayload = [ordered]@{
        cwd = $globalWorkspacePath
        source = 'new'
        sessionId = 'session-global'
        hookEventName = 'SessionStart'
    }

    $globalSubagentPayload = [ordered]@{
        cwd = $globalWorkspacePath
        sessionId = 'session-global'
        hookEventName = 'SubagentStart'
        agent_id = 'subagent-global'
        agent_type = 'implementer'
    }

    $globalSessionResult = Invoke-HookScript -ScriptPath $sessionStartScript -Payload $globalSessionPayload
    $globalSubagentResult = Invoke-HookScript -ScriptPath $subagentStartScript -Payload $globalSubagentPayload

    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match 'Workspace mode: global-runtime') 'SessionStart hook should advertise global-runtime mode when no local adapter exists.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match '\[Super Agent: ACTIVE \| controller=Super Agent \| skill=super-agent \| mode=global-runtime') 'SessionStart hook should expose a visible activation banner in global-runtime mode.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match 'load runtime AGENTS\.md and copilot-instructions\.md from ~/.github first') 'SessionStart hook should fall back to runtime instructions in global-runtime mode.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match '\.build/super-agent/planning/active -> \.build/super-agent/planning/completed') 'SessionStart hook should use .build planning roots in global-runtime mode.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match '\.build/super-agent/specs/active -> \.build/super-agent/specs/completed') 'SessionStart hook should use .build spec roots in global-runtime mode.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match 'Do not assume the runtime repository routing catalog') 'SessionStart hook should block runtime repo routing assumptions in global-runtime mode.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match 'plan-global-housekeeping\.md') 'SessionStart hook should use .build continuity artifacts in global-runtime mode when they exist.'
    Assert-True ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match 'spec-global-housekeeping\.md') 'SessionStart hook should use .build spec continuity artifacts in global-runtime mode when they exist.'
    Assert-True (-not ([string] $globalSessionResult.hookSpecificOutput.additionalContext -match 'insert_final_newline = false')) 'SessionStart hook should not claim insert_final_newline = false when the workspace has no matching .editorconfig rule.'
    Assert-True (Test-Path -LiteralPath $housekeepingRecordPath -PathType Leaf) 'Global-runtime SessionStart should dispatch housekeeping again after the throttle expires.'

    Assert-True ([string] $globalSubagentResult.hookSpecificOutput.additionalContext -match 'Workspace mode: global-runtime') 'SubagentStart hook should propagate global-runtime mode.'
    Assert-True ([string] $globalSubagentResult.hookSpecificOutput.additionalContext -match 'implementer') 'SubagentStart hook should mention the worker type in global-runtime mode.'
    Assert-True ([string] $globalSubagentResult.hookSpecificOutput.additionalContext -match '\.build/super-agent/planning/active') 'SubagentStart hook should preserve .build planning roots in global-runtime mode.'
    Assert-True ([string] $globalSubagentResult.hookSpecificOutput.additionalContext -match '\[Super Agent: ACTIVE \| controller=Super Agent \| skill=super-agent \| mode=global-runtime') 'SubagentStart hook should propagate the visibility banner in global-runtime mode.'
    Assert-True ([string] $globalSubagentResult.hookSpecificOutput.additionalContext -match 'plan-global-housekeeping\.md') 'SubagentStart hook should explain the .build continuity source in global-runtime mode.'
}
finally {
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_FOREGROUND', $null, 'Process')
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_STATE_PATH', $null, 'Process')
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_RECORD_ONLY_PATH', $null, 'Process')
    [Environment]::SetEnvironmentVariable('SUPER_AGENT_HOUSEKEEPING_INTERVAL_HOURS', $null, 'Process')

    foreach ($temporaryPath in @($workspacePath, $globalWorkspacePath)) {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force
        }
    }
}

try {
    [Environment]::SetEnvironmentVariable('COPILOT_SUPER_AGENT_SKILL', 'super-agent', 'Process')
    [Environment]::SetEnvironmentVariable('COPILOT_SUPER_AGENT_NAME', 'Custom Super Agent', 'Process')

    $overrideResult = Invoke-HookScript -ScriptPath $sessionStartScript -Payload $sessionPayload
    Assert-True ([string] $overrideResult.hookSpecificOutput.additionalContext -match 'Selected startup controller: Custom Super Agent \(\$super-agent\) via environment-override') 'SessionStart hook should honor environment overrides for the startup controller.'
}
finally {
    [Environment]::SetEnvironmentVariable('COPILOT_SUPER_AGENT_SKILL', $null, 'Process')
    [Environment]::SetEnvironmentVariable('COPILOT_SUPER_AGENT_NAME', $null, 'Process')
}

Write-Host 'VS Code agent hook runtime tests passed.'