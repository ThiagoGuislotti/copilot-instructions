<#
.SYNOPSIS
    Renders repository-owned Codex orchestration surfaces from the authoritative definitions tree.

.DESCRIPTION
    Mirrors authored Codex orchestration assets from `definitions/providers/codex/orchestration/`
    into the tracked `.codex/orchestration/` surface.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER SourceRoot
    Optional override path to the authoritative Codex orchestration source tree.
    Defaults to `<RepoRoot>/definitions/providers/codex/orchestration`.

.PARAMETER OutputRoot
    Optional override path for the rendered `.codex/orchestration/` surface.
    Defaults to `<RepoRoot>/.codex/orchestration`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-codex-orchestration-surfaces.ps1 -RepoRoot .

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $SourceRoot,
    [string] $OutputRoot,
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

# Resolves either an explicit override path or the default Codex orchestration authored tree.
function Resolve-CodexOrchestrationSurfacePath {
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

# Replaces the managed `.codex/orchestration/` tree with the authoritative source contents.
function Invoke-CodexOrchestrationSurfaceMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Missing Codex orchestration source: $SourcePath"
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
$resolvedSourceRoot = Resolve-CodexOrchestrationSurfacePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $SourceRoot -DefaultRelativePath 'definitions/providers/codex/orchestration'
$resolvedOutputRoot = Resolve-CodexOrchestrationSurfacePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $OutputRoot -DefaultRelativePath '.codex/orchestration'

Start-ExecutionSession `
    -Name 'render-codex-orchestration-surfaces' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Source root' = $resolvedSourceRoot
            'Output root' = $resolvedOutputRoot
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

Invoke-CodexOrchestrationSurfaceMirror -SourcePath $resolvedSourceRoot -DestinationPath $resolvedOutputRoot
$renderedFileCount = @(Get-ChildItem -LiteralPath $resolvedOutputRoot -Recurse -File -ErrorAction SilentlyContinue).Count
Write-VerboseColor ("Rendered Codex orchestration surface: {0} -> {1}" -f $resolvedSourceRoot, $resolvedOutputRoot) 'Gray'

Write-StyledOutput ''
Write-StyledOutput 'Codex orchestration render summary'
Write-StyledOutput ("  Source: {0}" -f $resolvedSourceRoot)
Write-StyledOutput ("  Destination: {0}" -f $resolvedOutputRoot)
Write-StyledOutput ("  Rendered files: {0}" -f $renderedFileCount)

Complete-ExecutionSession -Name 'render-codex-orchestration-surfaces' -Status 'passed' -Summary ([ordered]@{
        'Rendered files' = $renderedFileCount
    }) | Out-Null

exit 0