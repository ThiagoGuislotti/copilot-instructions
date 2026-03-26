<#
.SYNOPSIS
    Renders repository-owned VS Code profile surfaces from the authoritative definitions tree.

.DESCRIPTION
    Mirrors versioned VS Code profile assets from `definitions/providers/vscode/profiles/`
    into the tracked `.vscode/profiles/` surface.

    This keeps `definitions/` as the source of truth while `.vscode/profiles/`
    remains a projected surface consumed by repository operators and docs.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER SourceRoot
    Optional override path to the authoritative VS Code profile source tree.
    Defaults to `<RepoRoot>/definitions/providers/vscode/profiles`.

.PARAMETER OutputRoot
    Optional override path for the rendered `.vscode/profiles/` surface.
    Defaults to `<RepoRoot>/.vscode/profiles`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-vscode-profile-surfaces.ps1 -RepoRoot .

.EXAMPLE
    pwsh -File scripts/runtime/render-vscode-profile-surfaces.ps1 -RepoRoot . -SourceRoot definitions/providers/vscode/profiles

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

# Resolves the authoritative VS Code profile source root.
function Resolve-VscodeProfileSourceRoot {
    param(
        [string] $ResolvedRepoRoot,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot 'definitions\providers\vscode\profiles'
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Resolves the rendered VS Code profile output root.
function Resolve-VscodeProfileOutputRoot {
    param(
        [string] $ResolvedRepoRoot,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot '.vscode\profiles'
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Mirrors the authoritative profile tree into the rendered surface.
function Invoke-VscodeProfileSurfaceMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Missing VS Code profile source: $SourcePath"
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
$resolvedSourceRoot = Resolve-VscodeProfileSourceRoot -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $SourceRoot
$resolvedOutputRoot = Resolve-VscodeProfileOutputRoot -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $OutputRoot

Start-ExecutionSession `
    -Name 'render-vscode-profile-surfaces' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Source root' = $resolvedSourceRoot
            'Output root' = $resolvedOutputRoot
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

Invoke-VscodeProfileSurfaceMirror -SourcePath $resolvedSourceRoot -DestinationPath $resolvedOutputRoot

$fileCount = @(Get-ChildItem -LiteralPath $resolvedOutputRoot -Recurse -File -ErrorAction SilentlyContinue).Count
$directoryCount = @(Get-ChildItem -LiteralPath $resolvedOutputRoot -Directory -ErrorAction SilentlyContinue).Count
Write-VerboseColor ("Rendered VS Code profile surface: {0} -> {1}" -f $resolvedSourceRoot, $resolvedOutputRoot) 'Gray'

Write-StyledOutput ''
Write-StyledOutput 'VS Code profile render summary'
Write-StyledOutput ("  Source: {0}" -f $resolvedSourceRoot)
Write-StyledOutput ("  Destination: {0}" -f $resolvedOutputRoot)
Write-StyledOutput ("  Directories: {0}" -f $directoryCount)
Write-StyledOutput ("  Files: {0}" -f $fileCount)

Complete-ExecutionSession -Name 'render-vscode-profile-surfaces' -Status 'passed' -Summary ([ordered]@{
        'Directories rendered' = $directoryCount
        'Files rendered' = $fileCount
    }) | Out-Null

exit 0