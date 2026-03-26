<#
.SYNOPSIS
    Renders repository-owned Claude runtime surfaces from the authoritative definitions tree.

.DESCRIPTION
    Mirrors authored Claude runtime assets from `definitions/providers/claude/runtime/`
    into the tracked `.claude/` surface.

    This phase currently manages the repository-owned `settings.json` contract.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected when omitted.

.PARAMETER SourceRoot
    Optional override path to the authoritative Claude runtime source tree.
    Defaults to `<RepoRoot>/definitions/providers/claude/runtime`.

.PARAMETER OutputRoot
    Optional override path for the rendered `.claude/` surface.
    Defaults to `<RepoRoot>/.claude`.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/render-claude-runtime-surfaces.ps1 -RepoRoot .

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

# Resolves either an explicit override path or the default Claude runtime authored tree.
function Resolve-ClaudeRuntimeSurfacePath {
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

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$resolvedSourceRoot = Resolve-ClaudeRuntimeSurfacePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $SourceRoot -DefaultRelativePath 'definitions/providers/claude/runtime'
$resolvedOutputRoot = Resolve-ClaudeRuntimeSurfacePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $OutputRoot -DefaultRelativePath '.claude'
$managedRootFiles = @('settings.json')

Start-ExecutionSession `
    -Name 'render-claude-runtime-surfaces' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Source root' = $resolvedSourceRoot
            'Output root' = $resolvedOutputRoot
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

foreach ($fileName in $managedRootFiles) {
    $sourceFilePath = Join-Path $resolvedSourceRoot $fileName
    if (-not (Test-Path -LiteralPath $sourceFilePath -PathType Leaf)) {
        throw "Missing Claude runtime source file: $sourceFilePath"
    }

    Copy-Item -LiteralPath $sourceFilePath -Destination (Join-Path $resolvedOutputRoot $fileName) -Force
}

Write-VerboseColor ("Rendered Claude runtime surface: {0} -> {1}" -f $resolvedSourceRoot, $resolvedOutputRoot) 'Gray'
Write-StyledOutput ''
Write-StyledOutput 'Claude runtime render summary'
Write-StyledOutput ("  Source: {0}" -f $resolvedSourceRoot)
Write-StyledOutput ("  Destination: {0}" -f $resolvedOutputRoot)
Write-StyledOutput ("  Managed root files: {0}" -f $managedRootFiles.Count)

Complete-ExecutionSession -Name 'render-claude-runtime-surfaces' -Status 'passed' -Summary ([ordered]@{
        'Managed root files' = $managedRootFiles.Count
    }) | Out-Null

exit 0