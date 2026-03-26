<#
.SYNOPSIS
    Renders tracked MCP runtime artifacts from the canonical catalog.

.DESCRIPTION
    Uses `.github/governance/mcp-runtime.catalog.json` as the single source of
    truth and regenerates the tracked runtime projections:
    - `.vscode/mcp.tamplate.jsonc`
    - `.codex/mcp/servers.manifest.json`

    This script is intended for repository maintenance and validation, not for
    writing user-global runtime state.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER CatalogPath
    Optional override path to the canonical MCP runtime catalog.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-mcp-runtime-artifacts.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $CatalogPath,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'mcp-runtime-catalog')

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$catalogInfo = Read-McpRuntimeCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath

$vscodeOutputPath = Join-Path $resolvedRepoRoot '.vscode\mcp.tamplate.jsonc'
$codexOutputPath = Join-Path $resolvedRepoRoot '.codex\mcp\servers.manifest.json'

$vscodeDocument = Convert-McpRuntimeCatalogToVscodeDocument -Catalog $catalogInfo.Catalog
$codexManifest = Convert-McpRuntimeCatalogToCodexManifest -Catalog $catalogInfo.Catalog

New-Item -ItemType Directory -Path (Split-Path -Path $vscodeOutputPath -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Path $codexOutputPath -Parent) -Force | Out-Null

Set-Content -LiteralPath $vscodeOutputPath -Value ($vscodeDocument | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
Set-Content -LiteralPath $codexOutputPath -Value ($codexManifest | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline

Write-StyledOutput ''
Write-StyledOutput 'MCP runtime render summary'
Write-StyledOutput ("  Catalog: {0}" -f $catalogInfo.Path)
Write-StyledOutput ("  VS Code template: {0}" -f $vscodeOutputPath)
Write-StyledOutput ("  Codex manifest: {0}" -f $codexOutputPath)
Write-StyledOutput ("  VS Code servers: {0}" -f @($vscodeDocument.servers.PSObject.Properties).Count)
Write-StyledOutput ("  Codex servers: {0}" -f @($codexManifest.servers).Count)

exit 0