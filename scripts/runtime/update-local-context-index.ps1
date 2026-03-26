<#
.SYNOPSIS
    Builds or refreshes the repository-owned local context index.

.DESCRIPTION
    Creates a deterministic local-first index under `.temp/context-index` from
    the canonical catalog. The index is safe to refresh repeatedly and exists
    to support local RAG/CAG continuity without replaying large chat history.

.PARAMETER RepoRoot
    Repository root used to resolve the catalog and indexable files.

.PARAMETER CatalogPath
    Optional override path to the local context index catalog.

.PARAMETER OutputRoot
    Optional override output directory for the generated index.

.PARAMETER ForceFullRebuild
    Rebuilds every indexed file even when a prior index exists.

.PARAMETER DetailedOutput
    Prints additional diagnostics.

.PARAMETER Verbose
    Shows verbose execution metadata.

.EXAMPLE
    pwsh -File scripts/runtime/update-local-context-index.ps1 -RepoRoot .

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $CatalogPath,
    [string] $OutputRoot,
    [switch] $ForceFullRebuild,
    [switch] $DetailedOutput,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'local-context-index')
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput

# Writes detailed diagnostics only when the caller opted in.
function Write-DetailedLog {
    param([string] $Message)

    if ($script:IsDetailedOutputEnabled) {
        Write-StyledOutput ("[DETAIL] {0}" -f $Message)
    }
}

$resolvedRepoRoot = Resolve-LocalContextIndexWorkspaceRoot -RequestedRoot $RepoRoot -FallbackPath (Get-Location).Path
$catalogInfo = Read-LocalContextIndexCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath
$resolvedIndexRoot = Resolve-LocalContextIndexRoot -RepoRoot $resolvedRepoRoot -Catalog $catalogInfo.Catalog -OutputRoot $OutputRoot
$existingIndex = if ($ForceFullRebuild) { $null } else { Read-LocalContextIndexDocument -IndexRoot $resolvedIndexRoot }

Start-ExecutionSession `
    -Name 'update-local-context-index' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Catalog path' = $catalogInfo.Path
            'Index root' = $resolvedIndexRoot
            'Force full rebuild' = [bool] $ForceFullRebuild
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

$existingFileMap = @{}
$existingChunkMap = @{}
if ($null -ne $existingIndex) {
    foreach ($fileEntry in @($existingIndex.files)) {
        $existingFileMap[[string] $fileEntry.path] = $fileEntry
    }
    foreach ($chunkEntry in @($existingIndex.chunks)) {
        $existingChunkMap[[string] $chunkEntry.id] = $chunkEntry
    }
}

$fileEntries = New-Object System.Collections.Generic.List[object]
$chunkEntries = New-Object System.Collections.Generic.List[object]
$reusedFileCount = 0
$rebuiltFileCount = 0

foreach ($file in @(Get-LocalContextIndexFileCandidates -RepoRoot $resolvedRepoRoot -Catalog $catalogInfo.Catalog)) {
    $relativePath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $file.FullName) -replace '\\', '/'
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $existingFileEntry = $existingFileMap[$relativePath]
    $canReuse = ($null -ne $existingFileEntry) -and ([string] $existingFileEntry.hash -eq ("sha256:{0}" -f $hash))

    if ($canReuse) {
        $reusedFileCount++
        $fileEntries.Add($existingFileEntry) | Out-Null
        foreach ($chunkId in @($existingFileEntry.chunkIds)) {
            $chunkKey = [string] $chunkId
            if ($existingChunkMap.ContainsKey($chunkKey)) {
                $chunkEntries.Add($existingChunkMap[$chunkKey]) | Out-Null
            }
        }
        continue
    }

    $rebuiltFileCount++
    $chunks = @(New-LocalContextChunksForFile -RepoRoot $resolvedRepoRoot -File $file -Catalog $catalogInfo.Catalog)
    $chunkIds = @($chunks | ForEach-Object { [string] $_.id })
    foreach ($chunk in $chunks) {
        $chunkEntries.Add($chunk) | Out-Null
    }

    $title = if (Test-MarkdownLikeContextFile -Path $relativePath) {
        $firstHeading = @((Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue) | Where-Object { $_ -match '^#\s+(.+?)\s*$' } | Select-Object -First 1)
        if ($firstHeading.Count -gt 0) {
            ([string] $firstHeading[0] -replace '^#\s+', '').Trim()
        }
        else {
            [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        }
    }
    else {
        [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    }

    $fileEntries.Add([ordered]@{
            path = $relativePath
            hash = ("sha256:{0}" -f $hash)
            lastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('o')
            sizeBytes = [long] $file.Length
            title = $title
            chunkIds = $chunkIds
        }) | Out-Null
}

$document = [ordered]@{
    version = [int] $catalogInfo.Catalog.version
    generatedAt = (Get-Date).ToString('o')
    repoRoot = $resolvedRepoRoot
    catalogPath = [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $catalogInfo.Path) -replace '\\', '/'
    chunkCount = $chunkEntries.Count
    files = @($fileEntries | Sort-Object path)
    chunks = @($chunkEntries | Sort-Object path, id)
}

$indexPath = Write-LocalContextIndexDocument -IndexRoot $resolvedIndexRoot -Document $document
Write-DetailedLog ("Index written to {0}" -f $indexPath)

Complete-ExecutionSession -Name 'update-local-context-index' -Status 'passed' -Summary ([ordered]@{
        'Files indexed' = $fileEntries.Count
        'Files rebuilt' = $rebuiltFileCount
        'Files reused' = $reusedFileCount
        'Chunks total' = $chunkEntries.Count
    }) | Out-Null

exit 0