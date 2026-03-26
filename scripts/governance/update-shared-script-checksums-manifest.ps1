<#
.SYNOPSIS
    Regenerates the shared script checksum manifest for external workflow consumption.

.DESCRIPTION
    Computes SHA256 checksums for repository-managed script roots and writes a
    deterministic manifest at `.github/governance/shared-script-checksums.manifest.json`.

    The manifest is intended for GitHub Actions workflows in external repositories
    that download scripts from this repository and verify integrity before execution.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER ManifestPath
    Manifest output path relative to repository root.

.PARAMETER IncludedRoots
    Script root folders (relative to repository root) included in checksum generation.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/governance/update-shared-script-checksums-manifest.ps1

.EXAMPLE
    pwsh -File scripts/governance/update-shared-script-checksums-manifest.ps1 `
      -IncludedRoots scripts/common,scripts/security

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ManifestPath = '.github/governance/shared-script-checksums.manifest.json',
    [string[]] $IncludedRoots = @('scripts/common', 'scripts/security'),
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

# Converts absolute path to normalized repository-relative path.
function Convert-ToManifestRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return Convert-ToRelativeRepoPath -Root $Root -Path $Path
}

# Collects script files from included roots.
function Get-IncludedScriptFileList {
    param(
        [string] $Root,
        [string[]] $RootFolders
    )

    $fileSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($rootFolder in $RootFolders) {
        $resolvedFolderPath = Resolve-RepoPath -Root $Root -Path $rootFolder
        if (-not (Test-Path -LiteralPath $resolvedFolderPath -PathType Container)) {
            throw ("Included root folder not found: {0}" -f $rootFolder)
        }

        Write-VerboseLog ("Scanning folder: {0}" -f $resolvedFolderPath)
        Get-ChildItem -LiteralPath $resolvedFolderPath -Recurse -File -Filter '*.ps1' | ForEach-Object {
            $fileSet.Add($_.FullName) | Out-Null
        }
    }

    return @($fileSet | Sort-Object)
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$normalizedRoots = @($IncludedRoots | ForEach-Object { ([string] $_).Replace('\', '/') } | Sort-Object -Unique)
if ($normalizedRoots.Count -eq 0) {
    throw 'At least one IncludedRoots entry is required.'
}

$scriptFiles = Get-IncludedScriptFileList -Root $resolvedRepoRoot -RootFolders $normalizedRoots
if ($scriptFiles.Count -eq 0) {
    throw 'No .ps1 files found in IncludedRoots.'
}

$entryList = New-Object System.Collections.Generic.List[object]
foreach ($scriptFile in $scriptFiles) {
    $relativePath = Convert-ToManifestRelativePath -Root $resolvedRepoRoot -Path $scriptFile
    $hash = (Get-FileHash -LiteralPath $scriptFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $entryList.Add([ordered]@{
            path = $relativePath
            sha256 = $hash
        }) | Out-Null
}

$manifestObject = [ordered]@{
    version = 1
    sourceRepository = 'https://github.com/ThiagoGuislotti/copilot-instructions'
    hashAlgorithm = 'SHA256'
    includedRoots = $normalizedRoots
    entries = @($entryList | Sort-Object path)
}

$resolvedManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ManifestPath
$manifestDirectory = Split-Path -Path $resolvedManifestPath -Parent
if (-not [string]::IsNullOrWhiteSpace($manifestDirectory)) {
    New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
}

$manifestJson = $manifestObject | ConvertTo-Json -Depth 20
Set-Content -LiteralPath $resolvedManifestPath -Value $manifestJson -Encoding UTF8

Write-StyledOutput 'Shared script checksum manifest updated.'
Write-StyledOutput ("  manifest: {0}" -f $resolvedManifestPath)
Write-StyledOutput ("  roots: {0}" -f ($normalizedRoots -join ', '))
Write-StyledOutput ("  entries: {0}" -f $entryList.Count)

exit 0