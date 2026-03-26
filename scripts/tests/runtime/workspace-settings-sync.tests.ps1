<#
.SYNOPSIS
    Runtime tests for workspace settings synchronization without external frameworks.

.DESCRIPTION
    Covers creation and update flows for `sync-workspace-settings.ps1`.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/workspace-settings-sync.tests.ps1

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

# Fails the current test when the actual and expected values differ.
function Assert-Equal {
    param(
        [object] $Actual,
        [object] $Expected,
        [string] $Message
    )

    if ($Actual -ne $Expected) {
        throw ("{0} Expected='{1}' Actual='{2}'" -f $Message, $Expected, $Actual)
    }
}

# Writes deterministic UTF-8 test content to disk.
function Write-TextFile {
    param(
        [string] $Path,
        [string] $Content
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $Content
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/sync-workspace-settings.ps1'

try {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    try {
        $baseWorkspace = Join-Path $tempRoot 'base.code-workspace'
        Write-TextFile -Path $baseWorkspace -Content @'
{
  "folders": [],
  "extensions": {
    "recommendations": [
      "mhutchie.git-graph"
    ]
  },
  "launch": {
    "configurations": []
  }
}
'@

        $existingWorkspace = Join-Path $tempRoot 'existing.code-workspace'
        Write-TextFile -Path $existingWorkspace -Content @'
{
  "folders": [
    { "name": "Api", "path": "src/Api" },
    { "name": "Ui", "path": "src/Ui" }
  ],
  "extensions": {
    "recommendations": [
      "rust-lang.rust-analyzer"
    ]
  },
  "settings": {
    "git.autofetch": true,
    "editor.fontSize": 99
  }
}
'@

        & $scriptPath -RepoRoot $resolvedRepoRoot -WorkspacePath $existingWorkspace -BaseWorkspacePath $baseWorkspace | Out-Null
        $existingDocument = Get-Content -Raw -LiteralPath $existingWorkspace | ConvertFrom-Json -Depth 100

        Assert-Equal -Actual @($existingDocument.folders).Count -Expected 2 -Message 'Existing workspace must preserve folders.'
        Assert-Equal -Actual @($existingDocument.extensions.recommendations).Count -Expected 2 -Message 'Existing workspace must merge extension recommendations with base workspace.'
        Assert-True -Condition (@($existingDocument.extensions.recommendations) -contains 'mhutchie.git-graph') -Message 'Existing workspace must inherit base workspace recommendations.'
        Assert-True -Condition (@($existingDocument.extensions.recommendations) -contains 'rust-lang.rust-analyzer') -Message 'Existing workspace must preserve workspace-specific recommendations.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['git.autofetch']) -Message 'Workspace sync must inherit git.autofetch from the global template instead of duplicating it.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['git.openRepositoryInParentFolders']) -Message 'Workspace sync must inherit parent-folder discovery from the global template instead of duplicating it.'
        Assert-Equal -Actual $existingDocument.settings.'git.autorefresh' -Expected $false -Message 'Heavy workspace sync must set git.autorefresh to false.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['extensions.autoUpdate']) -Message 'Workspace sync must inherit extensions.autoUpdate from the global template instead of duplicating it.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['github.copilot.nextEditSuggestions.enabled']) -Message 'Workspace sync must inherit Copilot nextEditSuggestions from the global template instead of duplicating it.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['workbench.startupEditor']) -Message 'Workspace sync must inherit the standard welcome page startup value from the global template.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['chat.emptyState.history.enabled']) -Message 'Workspace sync must inherit empty-state chat history from the global template.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['scm.repositories.visible']) -Message 'Workspace sync must inherit visible repository limits from the global template.'
        Assert-Equal -Actual $existingDocument.settings.'chat.agent.maxRequests' -Expected 100 -Message 'Workspace sync must cap chat.agent.maxRequests.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['editor.fontSize']) -Message 'Workspace sync must not keep unrelated workspace-local settings.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['files.watcherExclude']) -Message 'Workspace sync must inherit watcher excludes from the global template instead of duplicating them.'
        Assert-True -Condition ($null -eq $existingDocument.settings.PSObject.Properties['search.exclude']) -Message 'Workspace sync must inherit search excludes from the global template instead of duplicating them.'
        Assert-True -Condition ($null -ne $existingDocument.launch) -Message 'Workspace sync must inherit missing top-level defaults from the base workspace.'

        $newWorkspace = Join-Path $tempRoot 'new.code-workspace'
        & $scriptPath -RepoRoot $resolvedRepoRoot -WorkspacePath $newWorkspace -FolderPath 'src/Api', 'src/Ui' -BaseWorkspacePath $baseWorkspace | Out-Null
        $newDocument = Get-Content -Raw -LiteralPath $newWorkspace | ConvertFrom-Json -Depth 100

        Assert-Equal -Actual @($newDocument.folders).Count -Expected 2 -Message 'Workspace creation must create supplied folders.'
        Assert-Equal -Actual $newDocument.folders[0].path -Expected 'src/Api' -Message 'Workspace creation must preserve provided folder path.'
        Assert-Equal -Actual $newDocument.settings.'git.autorefresh' -Expected $false -Message 'Workspace creation must disable autorefresh for heavy multi-folder workspaces.'
        Assert-Equal -Actual $newDocument.settings.'chat.agent.maxRequests' -Expected 100 -Message 'Workspace creation must keep the workspace-local chat.agent.maxRequests cap.'
        Assert-True -Condition ($null -eq $newDocument.settings.PSObject.Properties['git.openRepositoryInParentFolders']) -Message 'Workspace creation must inherit parent-folder discovery from the global template.'
        Assert-True -Condition ($null -eq $newDocument.settings.PSObject.Properties['workbench.startupEditor']) -Message 'Workspace creation must inherit startup editor from the global template.'
        Assert-True -Condition ($null -eq $newDocument.settings.PSObject.Properties['chat.emptyState.history.enabled']) -Message 'Workspace creation must inherit empty-state chat history from the global template.'
        Assert-True -Condition ($null -eq $newDocument.settings.PSObject.Properties['search.exclude']) -Message 'Workspace creation must inherit search excludes from the global template.'
        Assert-Equal -Actual @($newDocument.extensions.recommendations).Count -Expected 1 -Message 'Workspace creation must inherit extension recommendations from the base workspace.'
        Assert-True -Condition ($null -ne $newDocument.launch) -Message 'Workspace creation must carry top-level defaults from the base workspace.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host '[OK] workspace settings sync tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] workspace settings sync tests failed: {0}" -f $_.Exception.Message)
    exit 1
}