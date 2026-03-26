<#
.SYNOPSIS
    Renders repository-owned projected provider surfaces from the canonical projection catalog.

.DESCRIPTION
    Uses `.github/governance/provider-surface-projection.catalog.json` as the
    authoritative map for projected provider surfaces and invokes the known
    renderer scripts in catalog order. This script does not replace the
    renderer-specific entrypoints; it orchestrates them.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER CatalogPath
    Optional override path to the provider-surface projection catalog.

.PARAMETER RendererId
    Optional one-or-more renderer ids to invoke directly.

.PARAMETER ConsumerName
    Optional catalog consumer name. Defaults to `direct`. Use `bootstrap` to
    run only renderers enabled for bootstrap ordering.

.PARAMETER EnableCodexRuntime
    When `ConsumerName bootstrap` is used, includes bootstrap renderers gated on
    the Codex runtime.

.PARAMETER EnableClaudeRuntime
    When `ConsumerName bootstrap` is used, includes bootstrap renderers gated on
    the Claude runtime.

.PARAMETER SummaryOnly
    Prints the selected renderers without invoking them.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-provider-surfaces.ps1 -RepoRoot .

.EXAMPLE
    pwsh -File scripts/runtime/render-provider-surfaces.ps1 -RepoRoot . -ConsumerName bootstrap -EnableCodexRuntime -EnableClaudeRuntime

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $CatalogPath,
    [string[]] $RendererId,
    [string] $ConsumerName = 'direct',
    [switch] $EnableCodexRuntime,
    [switch] $EnableClaudeRuntime,
    [switch] $SummaryOnly
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'provider-surface-catalog')

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$catalogInfo = Read-ProviderSurfaceProjectionCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath
$isVerboseEnabled = ($VerbosePreference -ne 'SilentlyContinue')
$selectedRenderers = Get-ProviderSurfaceProjectionRenderers `
    -Catalog $catalogInfo.Catalog `
    -RendererIds @($RendererId) `
    -ConsumerName $ConsumerName `
    -EnableCodexRuntime:$EnableCodexRuntime `
    -EnableClaudeRuntime:$EnableClaudeRuntime

Write-StyledOutput 'Provider surface render selection'
Write-StyledOutput ("  Catalog: {0}" -f $catalogInfo.Path)
Write-StyledOutput ("  Consumer: {0}" -f $ConsumerName)
Write-StyledOutput ("  Selected renderers: {0}" -f @($selectedRenderers).Count)
foreach ($renderer in @($selectedRenderers)) {
    Write-StyledOutput ("  - {0}" -f ([string] $renderer.id))
}

if ($SummaryOnly) {
    exit 0
}

$results = Invoke-ProviderSurfaceProjectionRenderers `
    -RepoRoot $resolvedRepoRoot `
    -Catalog $catalogInfo.Catalog `
    -RendererIds @($RendererId) `
    -ConsumerName $ConsumerName `
    -EnableCodexRuntime:$EnableCodexRuntime `
    -EnableClaudeRuntime:$EnableClaudeRuntime `
    -RenderVerbose:$isVerboseEnabled

Write-StyledOutput ''
Write-StyledOutput 'Provider surface render summary'
Write-StyledOutput ("  Catalog: {0}" -f $catalogInfo.Path)
Write-StyledOutput ("  Consumer: {0}" -f $ConsumerName)
Write-StyledOutput ("  Renderers invoked: {0}" -f @($results).Count)

exit 0