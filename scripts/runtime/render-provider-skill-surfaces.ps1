<#
.SYNOPSIS
    Renders repository-owned provider skill surfaces from the authoritative source tree.

.DESCRIPTION
    Mirrors skill assets from `definitions/providers/<provider>/skills/` into the
    tracked provider runtime surfaces:
    - `.codex/skills`
    - `.claude/skills`

    This keeps `definitions/` as the source of truth while `.codex/` and `.claude/`
    remain projected runtime surfaces that can be mirrored to machine-local
    runtimes by bootstrap/install.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER SourceRoot
    Optional override path to the provider source tree. Defaults to
    `<RepoRoot>/definitions/providers`.

.PARAMETER Provider
    One or more providers to render. Supported values are `codex` and `claude`.
    Defaults to both providers.

.PARAMETER CodexOutputRoot
    Optional override path for the rendered Codex skill surface.

.PARAMETER ClaudeOutputRoot
    Optional override path for the rendered Claude skill surface.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-provider-skill-surfaces.ps1 -RepoRoot .

.EXAMPLE
    pwsh -File scripts/runtime/render-provider-skill-surfaces.ps1 -RepoRoot . -Provider codex

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $SourceRoot,
    [string[]] $Provider = @('codex', 'claude'),
    [string] $CodexOutputRoot,
    [string] $ClaudeOutputRoot,
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

# Resolves the provider source root.
function Resolve-ProviderSourceRoot {
    param(
        [string] $ResolvedRepoRoot,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot 'definitions\providers'
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Resolves one rendered provider output root.
function Resolve-ProviderOutputRoot {
    param(
        [string] $ResolvedRepoRoot,
        [string] $ProviderName,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot ('.{0}\skills' -f $ProviderName)
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Mirrors one source directory into a rendered provider surface.
function Invoke-ProviderSurfaceMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Missing provider skill source: $SourcePath"
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
$resolvedSourceRoot = Resolve-ProviderSourceRoot -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $SourceRoot
$requestedProviders = foreach ($item in @($Provider)) {
    foreach ($providerName in @(([string] $item) -split ',')) {
        $trimmedProviderName = $providerName.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmedProviderName)) {
            $trimmedProviderName
        }
    }
}
$requestedProviders = @($requestedProviders | Sort-Object -Unique)

$providerMap = [ordered]@{
    codex = [ordered]@{
        Source = Join-Path $resolvedSourceRoot 'codex\skills'
        Destination = Resolve-ProviderOutputRoot -ResolvedRepoRoot $resolvedRepoRoot -ProviderName 'codex' -RequestedPath $CodexOutputRoot
    }
    claude = [ordered]@{
        Source = Join-Path $resolvedSourceRoot 'claude\skills'
        Destination = Resolve-ProviderOutputRoot -ResolvedRepoRoot $resolvedRepoRoot -ProviderName 'claude' -RequestedPath $ClaudeOutputRoot
    }
}

foreach ($providerName in $requestedProviders) {
    if (-not $providerMap.Contains($providerName)) {
        throw ("Unsupported provider '{0}'. Supported values: codex, claude." -f $providerName)
    }
}

Start-ExecutionSession `
    -Name 'render-provider-skill-surfaces' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Source root' = $resolvedSourceRoot
            'Providers' = ($requestedProviders -join ', ')
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

$renderedProviders = New-Object System.Collections.Generic.List[object]
foreach ($providerName in $requestedProviders) {
    $providerInfo = $providerMap[$providerName]
    Invoke-ProviderSurfaceMirror -SourcePath $providerInfo.Source -DestinationPath $providerInfo.Destination
    $fileCount = @(Get-ChildItem -LiteralPath $providerInfo.Destination -Recurse -File -ErrorAction SilentlyContinue).Count
    $directoryCount = @(Get-ChildItem -LiteralPath $providerInfo.Destination -Directory -ErrorAction SilentlyContinue).Count
    Write-VerboseColor ("Rendered provider skill surface: {0} -> {1}" -f $providerInfo.Source, $providerInfo.Destination) 'Gray'
    $renderedProviders.Add([pscustomobject]@{
            Name = $providerName
            Source = $providerInfo.Source
            Destination = $providerInfo.Destination
            FileCount = $fileCount
            DirectoryCount = $directoryCount
        }) | Out-Null
}

Write-StyledOutput ''
Write-StyledOutput 'Provider skill render summary'
foreach ($providerResult in @($renderedProviders.ToArray())) {
    Write-StyledOutput ("  Provider: {0}" -f $providerResult.Name)
    Write-StyledOutput ("    Source: {0}" -f $providerResult.Source)
    Write-StyledOutput ("    Destination: {0}" -f $providerResult.Destination)
    Write-StyledOutput ("    Directories: {0}" -f $providerResult.DirectoryCount)
    Write-StyledOutput ("    Files: {0}" -f $providerResult.FileCount)
}

Complete-ExecutionSession -Name 'render-provider-skill-surfaces' -Status 'passed' -Summary ([ordered]@{
        'Providers rendered' = $renderedProviders.Count
        'Files rendered' = (@($renderedProviders.ToArray() | Measure-Object -Property FileCount -Sum).Sum)
    }) | Out-Null

exit 0