<#
.SYNOPSIS
    Queries the repository-owned local context index.

.DESCRIPTION
    Executes deterministic lexical retrieval against the local context index
    built by `update-local-context-index.ps1`. This is the safe local RAG/CAG
    entrypoint for continuity and targeted reuse of repository context.

.PARAMETER RepoRoot
    Repository root used to resolve the catalog and index path.

.PARAMETER QueryText
    Search query to execute against the local context index.

.PARAMETER CatalogPath
    Optional override path to the local context index catalog.

.PARAMETER OutputRoot
    Optional override output directory for the generated index.

.PARAMETER Top
    Maximum number of hits to return. Defaults to the catalog query default.

.PARAMETER JsonOutput
    Emits raw JSON instead of the default human-readable summary.

.PARAMETER Verbose
    Shows verbose execution metadata.

.EXAMPLE
    pwsh -File scripts/runtime/query-local-context-index.ps1 -RepoRoot . -QueryText "context compaction continuity"

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $QueryText,
    [string] $CatalogPath,
    [string] $OutputRoot,
    [Nullable[int]] $Top,
    [switch] $JsonOutput
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'local-context-index')

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$catalogInfo = Read-LocalContextIndexCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath
$resolvedIndexRoot = Resolve-LocalContextIndexRoot -RepoRoot $resolvedRepoRoot -Catalog $catalogInfo.Catalog -OutputRoot $OutputRoot
$indexDocument = Read-LocalContextIndexDocument -IndexRoot $resolvedIndexRoot
if ($null -eq $indexDocument) {
    throw ("Local context index not found. Run update-local-context-index first: {0}" -f (Join-Path $resolvedIndexRoot 'index.json'))
}

$defaultTop = [int] (Get-LocalContextIndexOptionalValue -Object (Get-LocalContextIndexOptionalValue -Object $catalogInfo.Catalog -PropertyName 'queryDefaults') -PropertyName 'top' -DefaultValue 5)
$effectiveTop = if ($null -eq $Top) { $defaultTop } else { [Math]::Max(1, [int] $Top) }

$hits = New-Object System.Collections.Generic.List[object]
foreach ($chunk in @($indexDocument.chunks)) {
    $score = Get-LocalContextChunkScore -QueryText $QueryText -Chunk $chunk
    if ($score -le 0) {
        continue
    }

    $hits.Add([ordered]@{
            id = [string] $chunk.id
            path = [string] $chunk.path
            heading = [string] (Get-LocalContextIndexOptionalValue -Object $chunk -PropertyName 'heading' -DefaultValue '')
            score = $score
            excerpt = [string] $chunk.text
        }) | Out-Null
}

$orderedHits = @($hits | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'path'; Descending = $false } | Select-Object -First $effectiveTop)
$result = [ordered]@{
    query = $QueryText
    top = $effectiveTop
    indexPath = (Join-Path $resolvedIndexRoot 'index.json')
    resultCount = $orderedHits.Count
    hits = $orderedHits
}

if ($JsonOutput) {
    $result | ConvertTo-Json -Depth 100 | Write-Output
    exit 0
}

Write-Output ("Local context index query: {0}" -f $QueryText)
Write-Output ("Index: {0}" -f $result.indexPath)
Write-Output ("Hits: {0}" -f $result.resultCount)
foreach ($hit in $orderedHits) {
    Write-Output ''
    Write-Output ("- [{0}] {1}" -f $hit.score, $hit.path)
    if (-not [string]::IsNullOrWhiteSpace([string] $hit.heading)) {
        Write-Output ("  heading: {0}" -f $hit.heading)
    }
    Write-Output ("  excerpt: {0}" -f $hit.excerpt)
}

exit 0