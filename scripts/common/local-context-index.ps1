<#
.SYNOPSIS
    Shared helpers for the repository-owned local RAG/CAG context index.

.DESCRIPTION
    Provides deterministic, local-first indexing helpers for planning,
    instructions, scripts, and other repository text surfaces. The index is
    designed for safe continuity and retrieval without shrinking required
    working context.

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Returns one direct property value or a fallback default.
function Get-LocalContextIndexOptionalValue {
    param(
        [object] $Object,
        [string] $PropertyName,
        [object] $DefaultValue = $null
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($PropertyName)) {
        return $DefaultValue
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($PropertyName)) {
            return $Object[$PropertyName]
        }

        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

# Resolves the canonical local context index catalog path.
function Resolve-LocalContextIndexCatalogPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [string] $CatalogPath
    )

    if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
        return Join-Path $RepoRoot '.github\governance\local-context-index.catalog.json'
    }

    if ([System.IO.Path]::IsPathRooted($CatalogPath)) {
        return [System.IO.Path]::GetFullPath($CatalogPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $CatalogPath))
}

# Reads the canonical local context index catalog.
function Read-LocalContextIndexCatalog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [string] $CatalogPath
    )

    $resolvedCatalogPath = Resolve-LocalContextIndexCatalogPath -RepoRoot $RepoRoot -CatalogPath $CatalogPath
    if (-not (Test-Path -LiteralPath $resolvedCatalogPath -PathType Leaf)) {
        throw "Local context index catalog not found: $resolvedCatalogPath"
    }

    try {
        $catalog = Get-Content -Raw -LiteralPath $resolvedCatalogPath | ConvertFrom-Json -Depth 100
    }
    catch {
        throw ("Invalid local context index catalog '{0}': {1}" -f $resolvedCatalogPath, $_.Exception.Message)
    }

    return [pscustomobject]@{
        Path = $resolvedCatalogPath
        Catalog = $catalog
    }
}

# Resolves the output root used to persist the local context index.
function Resolve-LocalContextIndexRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [object] $Catalog,
        [string] $OutputRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
        if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
            return [System.IO.Path]::GetFullPath($OutputRoot)
        }

        return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $OutputRoot))
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot ([string] $Catalog.indexRoot)))
}

# Converts one repository glob into a regex that matches forward-slash relative paths.
function Convert-LocalContextGlobToRegex {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Pattern
    )

    $normalized = ($Pattern -replace '\\', '/')
    $escaped = [regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    $escaped = $escaped.Replace('\?', '.')
    return ('^{0}$' -f $escaped)
}

# Returns true when one relative repository path should be indexed.
function Test-LocalContextIndexPathIncluded {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,
        [Parameter(Mandatory = $true)]
        [object] $Catalog
    )

    $normalizedRelativePath = ($RelativePath -replace '\\', '/').TrimStart('./')
    $includeGlobs = @($Catalog.includeGlobs | ForEach-Object { [string] $_ })
    $excludeGlobs = @($Catalog.excludeGlobs | ForEach-Object { [string] $_ })

    $included = $false
    foreach ($includeGlob in $includeGlobs) {
        if ($normalizedRelativePath -match (Convert-LocalContextGlobToRegex -Pattern $includeGlob)) {
            $included = $true
            break
        }
    }

    if (-not $included) {
        return $false
    }

    foreach ($excludeGlob in $excludeGlobs) {
        if ($normalizedRelativePath -match (Convert-LocalContextGlobToRegex -Pattern $excludeGlob)) {
            return $false
        }
    }

    return $true
}

# Returns candidate repository files for indexing.
function Get-LocalContextIndexFileCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [object] $Catalog
    )

    $maxFileSizeBytes = [long] (Get-LocalContextIndexOptionalValue -Object $Catalog -PropertyName 'maxFileSizeKb' -DefaultValue 256) * 1KB
    $candidates = New-Object System.Collections.Generic.List[System.IO.FileInfo]

    foreach ($file in @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
        if (-not (Test-LocalContextIndexPathIncluded -RelativePath $relativePath -Catalog $Catalog)) {
            continue
        }

        if ([long] $file.Length -gt $maxFileSizeBytes) {
            continue
        }

        $candidates.Add($file) | Out-Null
    }

    return @($candidates | Sort-Object FullName)
}

# Returns true when the file extension should be treated as markdown-style content.
function Test-MarkdownLikeContextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    return @('.md', '.markdown') -contains ([System.IO.Path]::GetExtension($Path).ToLowerInvariant())
}

# Compresses repeated whitespace into one search-friendly text block.
function Convert-ToNormalizedContextText {
    param(
        [AllowNull()]
        [string] $Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return (($Text -replace '\s+', ' ').Trim())
}

# Builds heading-aware chunks for one markdown file.
function New-MarkdownContextChunks {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Lines,
        [Parameter(Mandatory = $true)]
        [int] $MaxChars,
        [Parameter(Mandatory = $true)]
        [int] $MaxLines
    )

    $chunks = New-Object System.Collections.Generic.List[object]
    $currentHeading = [string]::Empty
    $currentLines = New-Object System.Collections.Generic.List[string]
    $chunkIndex = 0

    function Flush-MarkdownChunk {
        param(
            [string] $Heading,
            [System.Collections.Generic.List[string]] $Buffer,
            [int] $Index
        )

        if ($Buffer.Count -eq 0) {
            return $null
        }

        $text = Convert-ToNormalizedContextText -Text (($Buffer.ToArray()) -join [Environment]::NewLine)
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }

        return [ordered]@{
            id = ('{0}::{1}' -f $RelativePath, $Index)
            path = $RelativePath
            kind = 'markdown'
            heading = $Heading
            text = $text
            searchText = Convert-ToNormalizedContextText -Text (($Heading + ' ' + $text).ToLowerInvariant())
        }
    }

    foreach ($line in @($Lines)) {
        $trimmed = [string] $line
        if ($trimmed -match '^#{1,6}\s+(.+?)\s*$') {
            $flushed = Flush-MarkdownChunk -Heading $currentHeading -Buffer $currentLines -Index $chunkIndex
            if ($null -ne $flushed) {
                $chunks.Add($flushed) | Out-Null
                $chunkIndex++
            }

            $currentLines = New-Object System.Collections.Generic.List[string]
            $currentHeading = [string] $Matches[1]
            continue
        }

        $currentLines.Add($trimmed) | Out-Null
        $currentText = Convert-ToNormalizedContextText -Text (($currentLines.ToArray()) -join [Environment]::NewLine)
        if (($currentLines.Count -ge $MaxLines) -or ($currentText.Length -ge $MaxChars)) {
            $flushed = Flush-MarkdownChunk -Heading $currentHeading -Buffer $currentLines -Index $chunkIndex
            if ($null -ne $flushed) {
                $chunks.Add($flushed) | Out-Null
                $chunkIndex++
            }

            $currentLines = New-Object System.Collections.Generic.List[string]
        }
    }

    $finalChunk = Flush-MarkdownChunk -Heading $currentHeading -Buffer $currentLines -Index $chunkIndex
    if ($null -ne $finalChunk) {
        $chunks.Add($finalChunk) | Out-Null
    }

    return @($chunks)
}

# Builds bounded line-window chunks for non-markdown text files.
function New-TextContextChunks {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Lines,
        [Parameter(Mandatory = $true)]
        [int] $MaxChars,
        [Parameter(Mandatory = $true)]
        [int] $MaxLines
    )

    $chunks = New-Object System.Collections.Generic.List[object]
    $buffer = New-Object System.Collections.Generic.List[string]
    $chunkIndex = 0

    function Flush-TextChunk {
        param(
            [System.Collections.Generic.List[string]] $Buffer,
            [int] $Index
        )

        if ($Buffer.Count -eq 0) {
            return $null
        }

        $text = Convert-ToNormalizedContextText -Text (($Buffer.ToArray()) -join [Environment]::NewLine)
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }

        return [ordered]@{
            id = ('{0}::{1}' -f $RelativePath, $Index)
            path = $RelativePath
            kind = 'text'
            heading = $null
            text = $text
            searchText = Convert-ToNormalizedContextText -Text (($RelativePath + ' ' + $text).ToLowerInvariant())
        }
    }

    foreach ($line in @($Lines)) {
        $buffer.Add([string] $line) | Out-Null
        $currentText = Convert-ToNormalizedContextText -Text (($buffer.ToArray()) -join [Environment]::NewLine)
        if (($buffer.Count -ge $MaxLines) -or ($currentText.Length -ge $MaxChars)) {
            $flushed = Flush-TextChunk -Buffer $buffer -Index $chunkIndex
            if ($null -ne $flushed) {
                $chunks.Add($flushed) | Out-Null
                $chunkIndex++
            }

            $buffer = New-Object System.Collections.Generic.List[string]
        }
    }

    $finalChunk = Flush-TextChunk -Buffer $buffer -Index $chunkIndex
    if ($null -ne $finalChunk) {
        $chunks.Add($finalChunk) | Out-Null
    }

    return @($chunks)
}

# Builds index chunks for one repository file.
function New-LocalContextChunksForFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $File,
        [Parameter(Mandatory = $true)]
        [object] $Catalog
    )

    $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $File.FullName) -replace '\\', '/'
    $lines = @(Get-Content -LiteralPath $File.FullName -ErrorAction SilentlyContinue)
    $chunking = Get-LocalContextIndexOptionalValue -Object $Catalog -PropertyName 'chunking'
    $maxChars = [int] (Get-LocalContextIndexOptionalValue -Object $chunking -PropertyName 'maxChars' -DefaultValue 1600)
    $maxLines = [int] (Get-LocalContextIndexOptionalValue -Object $chunking -PropertyName 'maxLines' -DefaultValue 40)

    if (Test-MarkdownLikeContextFile -Path $relativePath) {
        return @(New-MarkdownContextChunks -RelativePath $relativePath -Lines $lines -MaxChars $maxChars -MaxLines $maxLines)
    }

    return @(New-TextContextChunks -RelativePath $relativePath -Lines $lines -MaxChars $maxChars -MaxLines $maxLines)
}

# Reads the persisted local context index document when present.
function Read-LocalContextIndexDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string] $IndexRoot
    )

    $indexPath = Join-Path $IndexRoot 'index.json'
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        return $null
    }

    try {
        return (Get-Content -Raw -LiteralPath $indexPath | ConvertFrom-Json -Depth 200)
    }
    catch {
        return $null
    }
}

# Writes the persisted local context index document.
function Write-LocalContextIndexDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string] $IndexRoot,
        [Parameter(Mandatory = $true)]
        [object] $Document
    )

    New-Item -ItemType Directory -Path $IndexRoot -Force | Out-Null
    $indexPath = Join-Path $IndexRoot 'index.json'
    Set-Content -LiteralPath $indexPath -Value ($Document | ConvertTo-Json -Depth 200) -Encoding UTF8 -NoNewline
    return $indexPath
}

# Tokenizes a search query or chunk text into lowercase search terms.
function Get-LocalContextSearchTerms {
    param(
        [AllowNull()]
        [string] $Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @(
        [regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9][a-z0-9._/-]{1,63}') |
            ForEach-Object { $_.Value } |
            Where-Object { $_.Length -ge 2 } |
            Select-Object -Unique
    )
}

# Scores one chunk against a query using deterministic lexical weighting.
function Get-LocalContextChunkScore {
    param(
        [Parameter(Mandatory = $true)]
        [string] $QueryText,
        [Parameter(Mandatory = $true)]
        [object] $Chunk
    )

    $score = 0
    $queryLower = $QueryText.ToLowerInvariant()
    $pathLower = ([string] $Chunk.path).ToLowerInvariant()
    $headingLower = ([string] (Get-LocalContextIndexOptionalValue -Object $Chunk -PropertyName 'heading' -DefaultValue '')).ToLowerInvariant()
    $searchText = ([string] (Get-LocalContextIndexOptionalValue -Object $Chunk -PropertyName 'searchText' -DefaultValue '')).ToLowerInvariant()

    if ($pathLower.Contains($queryLower)) {
        $score += 24
    }

    if (-not [string]::IsNullOrWhiteSpace($headingLower) -and $headingLower.Contains($queryLower)) {
        $score += 18
    }

    foreach ($term in (Get-LocalContextSearchTerms -Text $QueryText)) {
        if ($pathLower.Contains($term)) {
            $score += 10
        }

        if (-not [string]::IsNullOrWhiteSpace($headingLower) -and $headingLower.Contains($term)) {
            $score += 8
        }

        $matchCount = ([regex]::Matches($searchText, [regex]::Escape($term))).Count
        if ($matchCount -gt 0) {
            $score += [Math]::Min(12, $matchCount * 2)
        }
    }

    return $score
}