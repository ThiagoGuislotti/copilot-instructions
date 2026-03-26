<#
.SYNOPSIS
    Renders the tracked VS Code MCP template from the canonical MCP runtime catalog.

.DESCRIPTION
    Uses `.github/governance/mcp-runtime.catalog.json` as the single source of
    truth for runtime MCP definitions, then renders the full-fidelity VS Code
    template consumed by workspace and global VS Code sync flows.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER CatalogPath
    Optional override path to the canonical MCP runtime catalog.

.PARAMETER OutputPath
    Optional output path for the rendered VS Code MCP template. Defaults to
    `<RepoRoot>/.vscode/mcp.tamplate.jsonc`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1

.EXAMPLE
    pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 -OutputPath .\.temp\vscode.mcp.generated.json

.NOTES
    Version: 2.0
    Requirements: PowerShell 7+.
#>

[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $CatalogPath,
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\scripts\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths', 'mcp-runtime-catalog')

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$catalogInfo = Read-McpRuntimeCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath
$resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Join-Path $resolvedRepoRoot '.vscode\mcp.tamplate.jsonc'
}
elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $resolvedRepoRoot $OutputPath))
}

$renderedDocument = Convert-McpRuntimeCatalogToVscodeDocument -Catalog $catalogInfo.Catalog
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

Set-Content -LiteralPath $resolvedOutputPath -Value ($renderedDocument | ConvertTo-Json -Depth 100) -Encoding UTF8 -NoNewline
Write-Host "Generated: $resolvedOutputPath"
Write-Host "Catalog: $($catalogInfo.Path)"
Write-Host "Servers rendered: $(@($renderedDocument.servers.PSObject.Properties).Count)"