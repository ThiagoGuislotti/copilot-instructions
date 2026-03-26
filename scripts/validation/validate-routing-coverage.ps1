<#
.SYNOPSIS
    Validates routing catalog coverage against golden fixture cases.

.DESCRIPTION
    Enforces deterministic routing governance by checking:
    - every route id in `.github/instruction-routing.catalog.yml` is covered by at least one fixture case
    - every expected route id in fixture cases exists in the catalog
    - every expected selected path in fixture cases exists in the route include union
    - every include path declared by routes exists on disk

    Exit code:
    - 0 when all coverage checks pass
    - 1 when any required check fails

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER CatalogPath
    Routing catalog path relative to repository root.

.PARAMETER FixturePath
    Routing golden fixture path relative to repository root.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-routing-coverage.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-routing-coverage.ps1 -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $CatalogPath = '.github/instruction-routing.catalog.yml',
    [string] $FixturePath = 'scripts/validation/fixtures/routing-golden-tests.json',
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Resolves a path from repo root.
function Resolve-RepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

# Resolves repository root from input and fallback candidates.
function Resolve-RepositoryRoot {
    param(
        [string] $RequestedRoot
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $RequestedRoot).Path
        }
        catch {
            throw "Invalid RepoRoot path: $RequestedRoot"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ScriptRoot)) {
        $candidates += (Resolve-Path -LiteralPath (Join-Path $script:ScriptRoot '..\..')).Path
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Converts null/scalar/arrays to string arrays.
function Convert-ToStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return ,@()
    }

    if ($Value -is [string]) {
        return ,@([string] $Value)
    }

    return ,@($Value | ForEach-Object { [string] $_ })
}

# Converts YAML scalar values to plain text.
function Convert-YamlScalar {
    param(
        [string] $Value
    )

    $cleaned = $Value.Trim()
    if (($cleaned.StartsWith('"') -and $cleaned.EndsWith('"')) -or ($cleaned.StartsWith("'") -and $cleaned.EndsWith("'"))) {
        $cleaned = $cleaned.Substring(1, $cleaned.Length - 2)
    }

    return $cleaned
}

# Loads routing catalog route ids and include path lists.
function Get-CatalogRouteMap {
    param(
        [string] $CatalogFilePath
    )

    $routeMap = @{}
    $lines = Get-Content -LiteralPath $CatalogFilePath
    $inRouting = $false
    $currentRouteId = $null
    $currentMode = ''

    foreach ($line in $lines) {
        if ($line -match '^\s*routing:\s*$') {
            $inRouting = $true
            continue
        }

        if (-not $inRouting) {
            continue
        }

        if ($line -match '^\s*prompts:\s*$') {
            break
        }

        $routeMatch = [regex]::Match($line, '^\s{2}- id:\s*(?<id>.+?)\s*$')
        if ($routeMatch.Success) {
            $currentRouteId = Convert-YamlScalar -Value $routeMatch.Groups['id'].Value
            if ([string]::IsNullOrWhiteSpace($currentRouteId)) {
                continue
            }

            if ($routeMap.ContainsKey($currentRouteId)) {
                Add-ValidationFailure ("Duplicate route id in catalog: {0}" -f $currentRouteId)
                continue
            }

            $routeMap[$currentRouteId] = New-Object System.Collections.Generic.List[string]
            $currentMode = ''
            continue
        }

        if ([string]::IsNullOrWhiteSpace($currentRouteId)) {
            continue
        }

        if ($line -match '^\s{4}include:\s*$') {
            $currentMode = 'include'
            continue
        }

        if ($line -match '^\s{4}[a-zA-Z0-9_-]+:\s*$' -and $currentMode -eq 'include') {
            $currentMode = ''
            continue
        }

        if ($currentMode -ne 'include') {
            continue
        }

        $pathMatch = [regex]::Match($line, '^\s{6}- path:\s*(?<path>.+?)\s*$')
        if ($pathMatch.Success) {
            $includePath = Convert-YamlScalar -Value $pathMatch.Groups['path'].Value
            if (-not [string]::IsNullOrWhiteSpace($includePath)) {
                $routeMap[$currentRouteId].Add($includePath) | Out-Null
            }
        }
    }

    return $routeMap
}

# Loads fixture JSON document and returns cases.
function Get-FixtureCaseList {
    param(
        [string] $FixtureFilePath
    )

    $fixtureObject = $null
    try {
        $fixtureObject = Get-Content -Raw -LiteralPath $FixtureFilePath | ConvertFrom-Json -Depth 100
    }
    catch {
        Add-ValidationFailure ("Invalid fixture JSON: {0}" -f $_.Exception.Message)
        return @()
    }

    $cases = @($fixtureObject.cases)
    if ($cases.Count -eq 0) {
        Add-ValidationFailure ("Fixture has no cases: {0}" -f $FixtureFilePath)
        return @()
    }

    return ,$cases
}

# Validates that route include paths resolve to existing files.
function Test-CatalogIncludePath {
    param(
        [string] $CatalogDirectoryPath,
        [string] $RouteId,
        [string] $IncludePath
    )

    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $CatalogDirectoryPath $IncludePath))
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        Add-ValidationFailure ("Catalog route '{0}' references missing include path: {1}" -f $RouteId, $IncludePath)
    }
}

# Validates fixture case route/path expectations against catalog declarations.
function Test-FixtureCaseCoverage {
    param(
        [object] $CaseItem,
        [hashtable] $RouteMap,
        [hashtable] $RouteCoverageMap,
        [string] $CatalogDirectoryPath
    )

    $caseId = [string] $CaseItem.id
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        $caseId = '<unnamed-case>'
    }

    $expectedRouteIdList = Convert-ToStringArray -Value $CaseItem.expected_route_ids
    $expectedPathList = Convert-ToStringArray -Value $CaseItem.expected_selected_paths

    $includeUnion = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($routeId in $expectedRouteIdList) {
        if (-not $RouteMap.ContainsKey($routeId)) {
            Add-ValidationFailure ("Fixture case '{0}' references unknown route id: {1}" -f $caseId, $routeId)
            continue
        }

        $RouteCoverageMap[$routeId] = [int] $RouteCoverageMap[$routeId] + 1
        foreach ($includePath in $RouteMap[$routeId]) {
            $includeUnion.Add($includePath) | Out-Null
        }
    }

    if ($expectedRouteIdList.Count -eq 0 -and $expectedPathList.Count -gt 0) {
        Add-ValidationFailure ("Fixture case '{0}' has expected_selected_paths but no expected_route_ids." -f $caseId)
    }

    foreach ($expectedPath in $expectedPathList) {
        if (-not $includeUnion.Contains($expectedPath)) {
            Add-ValidationFailure ("Fixture case '{0}' expected path '{1}' is not in include union of expected routes." -f $caseId, $expectedPath)
        }

        $resolvedExpectedPath = [System.IO.Path]::GetFullPath((Join-Path $CatalogDirectoryPath $expectedPath))
        if (-not (Test-Path -LiteralPath $resolvedExpectedPath -PathType Leaf)) {
            Add-ValidationFailure ("Fixture case '{0}' expected path not found on disk: {1}" -f $caseId, $expectedPath)
        }
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedCatalogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $CatalogPath
$resolvedFixturePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $FixturePath
$catalogDirectoryPath = Split-Path -Path $resolvedCatalogPath -Parent

if (-not (Test-Path -LiteralPath $resolvedCatalogPath -PathType Leaf)) {
    Add-ValidationFailure ("Catalog file not found: {0}" -f $CatalogPath)
}

if (-not (Test-Path -LiteralPath $resolvedFixturePath -PathType Leaf)) {
    Add-ValidationFailure ("Fixture file not found: {0}" -f $FixturePath)
}

if ($script:Failures.Count -gt 0) {
    Write-StyledOutput ''
    Write-StyledOutput 'Routing coverage validation summary'
    Write-StyledOutput '  Routes checked: 0'
    Write-StyledOutput '  Cases checked: 0'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)
    exit 1
}

$routeMap = Get-CatalogRouteMap -CatalogFilePath $resolvedCatalogPath
if ($routeMap.Count -eq 0) {
    Add-ValidationFailure 'No routes parsed from routing catalog.'
}

$fixtureCases = Get-FixtureCaseList -FixtureFilePath $resolvedFixturePath
$routeCoverageMap = @{}
foreach ($routeId in $routeMap.Keys) {
    $routeCoverageMap[$routeId] = 0
}

foreach ($routeId in $routeMap.Keys) {
    foreach ($includePath in $routeMap[$routeId]) {
        Test-CatalogIncludePath -CatalogDirectoryPath $catalogDirectoryPath -RouteId $routeId -IncludePath $includePath
    }
}

foreach ($caseItem in $fixtureCases) {
    Test-FixtureCaseCoverage -CaseItem $caseItem -RouteMap $routeMap -RouteCoverageMap $routeCoverageMap -CatalogDirectoryPath $catalogDirectoryPath
}

foreach ($routeId in ($routeMap.Keys | Sort-Object)) {
    if ([int] $routeCoverageMap[$routeId] -lt 1) {
        Add-ValidationFailure ("Catalog route without fixture coverage: {0}" -f $routeId)
    }
    else {
        Write-VerboseLog ("Route coverage {0}: {1}" -f $routeId, $routeCoverageMap[$routeId])
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Routing coverage validation summary'
Write-StyledOutput ("  Routes checked: {0}" -f $routeMap.Count)
Write-StyledOutput ("  Cases checked: {0}" -f $fixtureCases.Count)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'Routing coverage validation passed.'
exit 0