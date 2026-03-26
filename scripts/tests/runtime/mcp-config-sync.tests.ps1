<#
.SYNOPSIS
    Runtime regression tests for mixed MCP manifest rendering and canonical
    catalog-driven Codex projections.

.DESCRIPTION
    Verifies that `scripts/runtime/sync-codex-mcp-config.ps1` can render a
    mixed manifest containing `stdio` and `http` servers without requiring
    every optional property to exist on every server entry.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/mcp-config-sync.tests.ps1

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

# Fails the current test when the text does not contain the expected fragment.
function Assert-ContainsText {
    param(
        [string] $Content,
        [string] $ExpectedText,
        [string] $Message
    )

    if (-not $Content.Contains($ExpectedText)) {
        throw $Message
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/sync-codex-mcp-config.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
$manifestPath = Join-Path $tempRoot 'servers.manifest.json'
$catalogPath = Join-Path $tempRoot 'mcp-runtime.catalog.json'
$configPath = Join-Path $tempRoot 'config.toml'

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    @'
{
  "version": 1,
  "servers": [
    {
      "name": "playwright",
      "type": "stdio",
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    },
    {
      "name": "microsoftdocs",
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    }
  ]
}
'@ | Set-Content -LiteralPath $manifestPath

    @'
model = "gpt-5"

[tools]
search = true
'@ | Set-Content -LiteralPath $configPath

    & $scriptPath -ManifestPath $manifestPath -TargetConfigPath $configPath -CreateBackup | Out-Null
    $lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue
    $exitCode = if ($null -eq $lastExitCodeVariable) { 0 } else { [int] $lastExitCodeVariable.Value }
    Assert-True -Condition ($exitCode -eq 0) -Message 'sync-codex-mcp-config should succeed for mixed stdio/http manifests.'

    $content = Get-Content -LiteralPath $configPath -Raw
    Assert-ContainsText -Content $content -ExpectedText '[mcp_servers.playwright]' -Message 'Rendered config must include the stdio MCP server block.'
    Assert-ContainsText -Content $content -ExpectedText 'command = "npx"' -Message 'Rendered config must include the stdio command.'
    Assert-ContainsText -Content $content -ExpectedText '[mcp_servers.microsoftdocs]' -Message 'Rendered config must include the http MCP server block.'
    Assert-ContainsText -Content $content -ExpectedText 'url = "https://learn.microsoft.com/api/mcp"' -Message 'Rendered config must include the http URL.'

    $backupFiles = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'config.toml.bak.*' -File)
    Assert-True -Condition ($backupFiles.Count -eq 1) -Message 'sync-codex-mcp-config should create one backup when -CreateBackup is specified.'

    @'
{
  "version": 1,
  "inputs": [],
  "servers": [
    {
      "id": "microsoftdocs/mcp",
      "codexName": "microsoftdocs",
      "targets": {
        "vscode": { "include": true, "enabledByDefault": true },
        "codex": { "include": true }
      },
      "definition": {
        "type": "http",
        "url": "https://learn.microsoft.com/api/mcp",
        "gallery": "https://example.invalid/gallery",
        "version": "1.0.0"
      }
    },
    {
      "id": "microsoft/playwright-mcp",
      "codexName": "playwright",
      "targets": {
        "codex": { "include": true }
      },
      "definition": {
        "type": "stdio",
        "command": "npx",
        "args": ["@playwright/mcp@latest"]
      }
    },
    {
      "id": "vscode-only/example",
      "targets": {
        "vscode": { "include": true, "enabledByDefault": false }
      },
      "definition": {
        "type": "http",
        "url": "https://example.invalid/vscode-only"
      }
    }
  ]
}
'@ | Set-Content -LiteralPath $catalogPath

    @'
model = "gpt-5"

[tools]
search = true
'@ | Set-Content -LiteralPath $configPath

    & $scriptPath -RepoRoot $resolvedRepoRoot -CatalogPath $catalogPath -TargetConfigPath $configPath | Out-Null
    $lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue
    $exitCode = if ($null -eq $lastExitCodeVariable) { 0 } else { [int] $lastExitCodeVariable.Value }
    Assert-True -Condition ($exitCode -eq 0) -Message 'sync-codex-mcp-config should succeed for canonical catalog input.'

    $content = Get-Content -LiteralPath $configPath -Raw
    Assert-ContainsText -Content $content -ExpectedText '[mcp_servers.microsoftdocs]' -Message 'Catalog-driven sync must include the codex-enabled http server block.'
    Assert-ContainsText -Content $content -ExpectedText '[mcp_servers.playwright]' -Message 'Catalog-driven sync must include the codex-enabled stdio server block.'
    Assert-True -Condition (-not $content.Contains('vscode-only')) -Message 'Catalog-driven sync must exclude VS Code-only servers from Codex config.'

    Write-Host '[OK] MCP config sync tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] MCP config sync tests failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}