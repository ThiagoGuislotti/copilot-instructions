<#
.SYNOPSIS
    Renders repository-owned Codex compatibility surfaces from the authoritative definitions tree.

.DESCRIPTION
    Projects the remaining authored Codex compatibility assets from
    `definitions/providers/codex/` into the tracked `.codex/` runtime surface:
    - `.codex/scripts/**`
    - selected authored files in `.codex/mcp/`

    The generated `.codex/mcp/servers.manifest.json` remains owned by
    `scripts/runtime/render-mcp-runtime-artifacts.ps1` and is intentionally left
    untouched by this renderer.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER SourceRoot
    Optional override path to the authoritative Codex provider source tree.
    Defaults to `<RepoRoot>/definitions/providers/codex`.

.PARAMETER ScriptsOutputRoot
    Optional override path for the rendered `.codex/scripts/` surface.
    Defaults to `<RepoRoot>/.codex/scripts`.

.PARAMETER McpOutputRoot
    Optional override path for the rendered `.codex/mcp/` support-file surface.
    Defaults to `<RepoRoot>/.codex/mcp`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-codex-compatibility-surfaces.ps1 -RepoRoot .

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $SourceRoot,
    [string] $ScriptsOutputRoot,
    [string] $McpOutputRoot,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../shared-scripts/common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:IsVerboseEnabled = [bool] $Verbose

# Resolves either an explicit override path or the default Codex compatibility surface path.
function Resolve-CodexCompatibilityPath {
    param(
        [string] $ResolvedRepoRoot,
        [string] $RequestedPath,
        [string] $DefaultRelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot $DefaultRelativePath
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Mirrors one authoritative Codex compatibility directory into its projected runtime surface.
function Invoke-CompatibilitySurfaceMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Missing Codex compatibility source: $SourcePath"
    }

    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    Get-ChildItem -LiteralPath $DestinationPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
    }

    Get-ChildItem -LiteralPath $SourcePath -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationPath -Recurse -Force
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$resolvedSourceRoot = Resolve-CodexCompatibilityPath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $SourceRoot -DefaultRelativePath 'definitions/providers/codex'
$resolvedScriptsOutputRoot = Resolve-CodexCompatibilityPath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $ScriptsOutputRoot -DefaultRelativePath '.codex/scripts'
$resolvedMcpOutputRoot = Resolve-CodexCompatibilityPath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $McpOutputRoot -DefaultRelativePath '.codex/mcp'
$managedMcpFiles = @('README.md', 'codex.config.template.toml', 'vscode.mcp.template.json')

Start-ExecutionSession `
    -Name 'render-codex-compatibility-surfaces' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Source root' = $resolvedSourceRoot
            'Scripts output root' = $resolvedScriptsOutputRoot
            'MCP output root' = $resolvedMcpOutputRoot
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

$scriptsSourceRoot = Join-Path $resolvedSourceRoot 'scripts'
$mcpSourceRoot = Join-Path $resolvedSourceRoot 'mcp'

Invoke-CompatibilitySurfaceMirror -SourcePath $scriptsSourceRoot -DestinationPath $resolvedScriptsOutputRoot
New-Item -ItemType Directory -Path $resolvedMcpOutputRoot -Force | Out-Null
foreach ($fileName in $managedMcpFiles) {
    $sourceFilePath = Join-Path $mcpSourceRoot $fileName
    if (-not (Test-Path -LiteralPath $sourceFilePath -PathType Leaf)) {
        throw "Missing Codex MCP support source file: $sourceFilePath"
    }

    Copy-Item -LiteralPath $sourceFilePath -Destination (Join-Path $resolvedMcpOutputRoot $fileName) -Force
}

$renderedScriptFileCount = @(Get-ChildItem -LiteralPath $resolvedScriptsOutputRoot -Recurse -File -ErrorAction SilentlyContinue).Count
Write-VerboseColor ("Rendered Codex compatibility scripts: {0} -> {1}" -f $scriptsSourceRoot, $resolvedScriptsOutputRoot) 'Gray'
Write-VerboseColor ("Rendered Codex MCP support files: {0} -> {1}" -f $mcpSourceRoot, $resolvedMcpOutputRoot) 'Gray'

Write-StyledOutput ''
Write-StyledOutput 'Codex compatibility render summary'
Write-StyledOutput ("  Source: {0}" -f $resolvedSourceRoot)
Write-StyledOutput ("  Scripts destination: {0}" -f $resolvedScriptsOutputRoot)
Write-StyledOutput ("  MCP destination: {0}" -f $resolvedMcpOutputRoot)
Write-StyledOutput ("  Script files rendered: {0}" -f $renderedScriptFileCount)
Write-StyledOutput ("  MCP support files rendered: {0}" -f $managedMcpFiles.Count)
Write-StyledOutput '  Generated MCP manifest preserved: .codex/mcp/servers.manifest.json'

Complete-ExecutionSession -Name 'render-codex-compatibility-surfaces' -Status 'passed' -Summary ([ordered]@{
        'Script files rendered' = $renderedScriptFileCount
        'MCP support files rendered' = $managedMcpFiles.Count
    }) | Out-Null

exit 0