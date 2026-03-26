<#
.SYNOPSIS
    Renders repository-owned VS Code workspace surfaces from the authoritative definitions tree.

.DESCRIPTION
    Mirrors authored VS Code workspace assets from `definitions/providers/vscode/workspace/`
    into the tracked `.vscode/` surface without touching runtime-local helper files such as
    `mcp-vscode-global.json` or other non-managed folders.

    Managed assets:
    - `README.md`
    - `base.code-workspace`
    - `settings.tamplate.jsonc`
    - `snippets/`

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER SourceRoot
    Optional override path to the authoritative VS Code workspace source tree.
    Defaults to `<RepoRoot>/definitions/providers/vscode/workspace`.

.PARAMETER OutputRoot
    Optional override path for the rendered `.vscode/` surface.
    Defaults to `<RepoRoot>/.vscode`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-vscode-workspace-surfaces.ps1 -RepoRoot .

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

# Resolves either an explicit override path or the default VS Code workspace authored tree.
function Resolve-VscodeWorkspaceSurfacePath {
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

# Replaces the managed destination directory with the authoritative source contents.
function Invoke-VscodeWorkspaceDirectoryMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourcePath,
        [Parameter(Mandatory = $true)]
        [string] $DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Missing VS Code workspace source directory: $SourcePath"
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
$resolvedSourceRoot = Resolve-VscodeWorkspaceSurfacePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $SourceRoot -DefaultRelativePath 'definitions/providers/vscode/workspace'
$resolvedOutputRoot = Resolve-VscodeWorkspaceSurfacePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $OutputRoot -DefaultRelativePath '.vscode'
$managedRootFiles = @(
    'README.md',
    'base.code-workspace',
    'settings.tamplate.jsonc'
)

Start-ExecutionSession `
    -Name 'render-vscode-workspace-surfaces' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Source root' = $resolvedSourceRoot
            'Output root' = $resolvedOutputRoot
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

foreach ($fileName in $managedRootFiles) {
    $sourceFilePath = Join-Path $resolvedSourceRoot $fileName
    if (-not (Test-Path -LiteralPath $sourceFilePath -PathType Leaf)) {
        throw "Missing managed VS Code workspace file: $sourceFilePath"
    }

    Copy-Item -LiteralPath $sourceFilePath -Destination (Join-Path $resolvedOutputRoot $fileName) -Force
}

Invoke-VscodeWorkspaceDirectoryMirror -SourcePath (Join-Path $resolvedSourceRoot 'snippets') -DestinationPath (Join-Path $resolvedOutputRoot 'snippets')
Write-VerboseColor ("Rendered VS Code workspace surface: {0} -> {1}" -f $resolvedSourceRoot, $resolvedOutputRoot) 'Gray'

$renderedFileCount = @(Get-ChildItem -LiteralPath (Join-Path $resolvedOutputRoot 'snippets') -Recurse -File -ErrorAction SilentlyContinue).Count + $managedRootFiles.Count
Write-StyledOutput ''
Write-StyledOutput 'VS Code workspace render summary'
Write-StyledOutput ("  Source: {0}" -f $resolvedSourceRoot)
Write-StyledOutput ("  Destination: {0}" -f $resolvedOutputRoot)
Write-StyledOutput ("  Managed root files: {0}" -f $managedRootFiles.Count)
Write-StyledOutput ("  Rendered files: {0}" -f $renderedFileCount)

Complete-ExecutionSession -Name 'render-vscode-workspace-surfaces' -Status 'passed' -Summary ([ordered]@{
        'Managed root files' = $managedRootFiles.Count
        'Rendered files' = $renderedFileCount
    }) | Out-Null

exit 0