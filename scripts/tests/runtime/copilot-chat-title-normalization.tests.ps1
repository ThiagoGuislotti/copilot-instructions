<#
.SYNOPSIS
    Runtime tests for Copilot chat title normalization without external frameworks.

.DESCRIPTION
    Covers project prefix derivation, title creation for sessions without
    explicit custom titles, backup creation, and idempotent behavior for
    `scripts/runtime/update-copilot-chat-titles.ps1`.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/copilot-chat-title-normalization.tests.ps1

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

# Fails the current test when the value does not match the expected pattern.
function Assert-Match {
    param(
        [string] $Actual,
        [string] $Pattern,
        [string] $Message
    )

    if ($Actual -notmatch $Pattern) {
        throw ("{0} Pattern='{1}'" -f $Message, $Pattern)
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
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/update-copilot-chat-titles.ps1'

try {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    try {
        $workspaceStorageRoot = Join-Path $tempRoot 'workspaceStorage'
        $workspaceId = 'workspace-a'
        $workspaceRoot = Join-Path $workspaceStorageRoot $workspaceId
        $chatSessionsRoot = Join-Path $workspaceRoot 'chatSessions'
        $emptyWindowRoot = Join-Path $tempRoot 'emptyWindowChatSessions'

        New-Item -ItemType Directory -Path $chatSessionsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $emptyWindowRoot -Force | Out-Null

        Write-TextFile -Path (Join-Path $workspaceRoot 'workspace.json') -Content @'
{
  "workspace": "file:///c%3A/Repos/copilot-instructions.code-workspace"
}
'@

        Write-TextFile -Path (Join-Path $chatSessionsRoot 'session-existing.json') -Content @'
{
  "version": 3,
  "creationDate": 1770000000000,
  "lastMessageDate": 1770000000100,
  "customTitle": "Investigate chat history persistence",
  "requests": [
    {
      "message": {
        "text": "Investigate chat history persistence"
      }
    }
  ]
}
'@

        Write-TextFile -Path (Join-Path $chatSessionsRoot 'session-no-title.json') -Content @'
{
  "version": 3,
  "creationDate": 1770000000000,
  "lastMessageDate": 1770000000100,
  "requests": [
    {
      "message": {
        "text": "Normalize missing Copilot chat titles for the current workspace"
      }
    }
  ]
}
'@

        Write-TextFile -Path (Join-Path $chatSessionsRoot 'session-stream.jsonl') -Content @'
{"kind":0,"v":{"version":3,"creationDate":1770000000000,"sessionId":"abc","requests":[]}}
{"kind":2,"k":["requests"],"v":[{"message":{"text":"Prefix streamed Copilot session titles"}}]}
'@

        & $scriptPath `
            -RepoRoot $resolvedRepoRoot `
            -WorkspaceStorageRoot $workspaceStorageRoot `
            -EmptyWindowChatRoot $emptyWindowRoot `
            -Apply `
            -CreateBackup | Out-Null

        $existingJson = Get-Content -Raw -LiteralPath (Join-Path $chatSessionsRoot 'session-existing.json')
        $missingJson = Get-Content -Raw -LiteralPath (Join-Path $chatSessionsRoot 'session-no-title.json')
        $streamJsonl = Get-Content -Raw -LiteralPath (Join-Path $chatSessionsRoot 'session-stream.jsonl')

        Assert-Match -Actual $existingJson -Pattern '"customTitle": "copilot-instructions - Investigate chat history persistence"' -Message 'Existing JSON session titles must receive the project prefix.'
        Assert-Match -Actual $missingJson -Pattern '"customTitle": "copilot-instructions - Normalize missing Copilot chat titles for the current workspace"' -Message 'JSON sessions without customTitle must receive a prefixed title derived from the first request.'
        Assert-Match -Actual $streamJsonl -Pattern '"customTitle":"copilot-instructions - Prefix streamed Copilot session titles"' -Message 'JSONL sessions must receive a prefixed customTitle.'

        $backupFiles = @(Get-ChildItem -LiteralPath $chatSessionsRoot -Filter '*.bak' -File)
        Assert-Equal -Actual $backupFiles.Count -Expected 3 -Message 'A backup file must be created for each changed session file.'

        $contentBeforeSecondRun = Get-Content -Raw -LiteralPath (Join-Path $chatSessionsRoot 'session-existing.json')
        & $scriptPath `
            -RepoRoot $resolvedRepoRoot `
            -WorkspaceStorageRoot $workspaceStorageRoot `
            -EmptyWindowChatRoot $emptyWindowRoot `
            -Apply | Out-Null
        $contentAfterSecondRun = Get-Content -Raw -LiteralPath (Join-Path $chatSessionsRoot 'session-existing.json')

        Assert-Equal -Actual $contentAfterSecondRun -Expected $contentBeforeSecondRun -Message 'Title normalization must be idempotent and must not duplicate the prefix.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host '[OK] Copilot chat title normalization tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] Copilot chat title normalization tests failed: {0}" -f $_.Exception.Message)
    exit 1
}