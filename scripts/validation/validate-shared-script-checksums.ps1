<#
.SYNOPSIS
    Validates the shared script checksum manifest against repository script files.

.DESCRIPTION
    Reads `.github/governance/shared-script-checksums.manifest.json` and verifies:
    - required manifest fields
    - included root folders exist
    - every discovered script is present in manifest entries
    - every manifest entry exists in source
    - SHA256 checksums match current file contents

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when warning-only is disabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER ManifestPath
    Manifest path relative to repository root.

.PARAMETER WarningOnly
    When true (default), findings are emitted as warnings and do not fail execution.

.PARAMETER DetailedOutput
    Prints file-level mismatch diagnostics.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-shared-script-checksums.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-shared-script-checksums.ps1 -WarningOnly:$false -DetailedOutput

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $ManifestPath = '.github/governance/shared-script-checksums.manifest.json',
    [bool] $WarningOnly = $true,
    [switch] $DetailedOutput,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $script:IsVerboseEnabled
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput

# Resolves a repository-relative path into an absolute path.

# Converts absolute path to normalized repository-relative path.
function Convert-ToRelativePath {
    param(
        [string] $Root,
        [string] $Path
    )

    return [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
}

# Converts manifest path values to repository-relative slash format.
function Convert-ToManifestPathValue {
    param(
        [string] $PathValue
    )

    $text = [string] $PathValue
    $text = $text.Replace('\', '/')
    $text = $text.Trim()
    if ($text.StartsWith('./')) {
        $text = $text.Substring(2)
    }

    return $text
}

# Builds expected hash map from manifest entries.
function Get-ManifestEntryMap {
    param(
        [object[]] $ManifestEntries
    )

    $map = @{}
    foreach ($entry in $ManifestEntries) {
        if ($null -eq $entry) {
            continue
        }

        $entryPath = Convert-ToManifestPathValue -PathValue ([string] $entry.path)
        $entryHash = ([string] $entry.sha256).ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($entryPath) -or [string]::IsNullOrWhiteSpace($entryHash)) {
            continue
        }

        $map[$entryPath] = $entryHash
    }

    return $map
}

# Builds current hash map from repository script roots.
function Get-CurrentEntryMap {
    param(
        [string] $Root,
        [string[]] $IncludedRoots
    )

    $map = @{}
    foreach ($rootFolder in $IncludedRoots) {
        $resolvedRootFolder = Resolve-RepoPath -Root $Root -Path $rootFolder
        if (-not (Test-Path -LiteralPath $resolvedRootFolder -PathType Container)) {
            Add-ValidationFailure ("Included root folder not found: {0}" -f $rootFolder)
            continue
        }

        Write-VerboseLog ("Scanning folder: {0}" -f $resolvedRootFolder)
        Get-ChildItem -LiteralPath $resolvedRootFolder -Recurse -File -Filter '*.ps1' | ForEach-Object {
            $relativePath = Convert-ToRelativePath -Root $Root -Path $_.FullName
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $map[$relativePath] = $hash
        }
    }

    return $map
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedManifestPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $ManifestPath
if (-not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)) {
    Add-ValidationFailure ("Manifest not found: {0}" -f $ManifestPath)
    Write-StyledOutput ''
    Write-StyledOutput 'Shared script checksum validation summary'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) { exit 1 }
    exit 0
}

$manifestObject = $null
try {
    $manifestObject = Get-Content -Raw -LiteralPath $resolvedManifestPath | ConvertFrom-Json -Depth 200
}
catch {
    Add-ValidationFailure ("Invalid manifest JSON: {0}" -f $_.Exception.Message)
}

if ($null -eq $manifestObject) {
    Write-StyledOutput ''
    Write-StyledOutput 'Shared script checksum validation summary'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) { exit 1 }
    exit 0
}

if ([int] $manifestObject.version -lt 1) {
    Add-ValidationFailure 'Manifest version must be >= 1.'
}

if ([string] $manifestObject.hashAlgorithm -ne 'SHA256') {
    Add-ValidationFailure ("Manifest hashAlgorithm must be 'SHA256', found '{0}'." -f [string] $manifestObject.hashAlgorithm)
}

$includedRoots = @($manifestObject.includedRoots | ForEach-Object { Convert-ToManifestPathValue -PathValue ([string] $_) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($includedRoots.Count -eq 0) {
    Add-ValidationFailure 'Manifest includedRoots must contain at least one folder.'
}

$manifestEntries = @($manifestObject.entries)
if ($manifestEntries.Count -eq 0) {
    Add-ValidationFailure 'Manifest entries must contain at least one item.'
}

$expectedMap = Get-ManifestEntryMap -ManifestEntries $manifestEntries
$currentMap = Get-CurrentEntryMap -Root $resolvedRepoRoot -IncludedRoots $includedRoots

$expectedKeys = @($expectedMap.Keys | Sort-Object)
$currentKeys = @($currentMap.Keys | Sort-Object)

$missingInManifest = New-Object System.Collections.Generic.List[string]
$missingInSource = New-Object System.Collections.Generic.List[string]
$hashMismatches = New-Object System.Collections.Generic.List[string]

foreach ($key in $currentKeys) {
    if (-not $expectedMap.ContainsKey($key)) {
        $missingInManifest.Add($key) | Out-Null
    }
}

foreach ($key in $expectedKeys) {
    if (-not $currentMap.ContainsKey($key)) {
        $missingInSource.Add($key) | Out-Null
        continue
    }

    if ($expectedMap[$key] -ne $currentMap[$key]) {
        $hashMismatches.Add($key) | Out-Null
    }
}

foreach ($path in $missingInManifest) {
    Add-ValidationFailure ("File exists but is missing in manifest: {0}" -f $path)
}

foreach ($path in $missingInSource) {
    Add-ValidationFailure ("Manifest references missing file: {0}" -f $path)
}

foreach ($path in $hashMismatches) {
    Add-ValidationFailure ("Checksum mismatch: {0}" -f $path)
}

if ($script:IsDetailedOutputEnabled) {
    foreach ($path in $hashMismatches) {
        Write-StyledOutput ("[DETAIL] expected={0} actual={1} path={2}" -f $expectedMap[$path], $currentMap[$path], $path)
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Shared script checksum validation summary'
Write-StyledOutput ("  Manifest: {0}" -f $resolvedManifestPath)
Write-StyledOutput ("  Included roots: {0}" -f ($includedRoots -join ', '))
Write-StyledOutput ("  Manifest entries: {0}" -f $expectedMap.Count)
Write-StyledOutput ("  Current entries: {0}" -f $currentMap.Count)
Write-StyledOutput ("  Missing in manifest: {0}" -f $missingInManifest.Count)
Write-StyledOutput ("  Missing in source: {0}" -f $missingInSource.Count)
Write-StyledOutput ("  Hash mismatches: {0}" -f $hashMismatches.Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

if ($script:Warnings.Count -gt 0 -or $script:Failures.Count -gt 0) {
    Write-StyledOutput 'Shared script checksum validation completed with warnings.'
}
else {
    Write-StyledOutput 'Shared script checksum validation passed.'
}

exit 0