<#
.SYNOPSIS
    Runs deterministic golden tests for static routing selection.

.DESCRIPTION
    Validates that routing behavior defined in .github/instruction-routing.catalog.yml
    remains deterministic for representative requests in fixtures.

    The script emulates the selection rules from prompts/route-instructions.prompt.md:
    - Trigger scoring per route
    - Candidate threshold selection
    - Route sort order (score desc + yaml order)
    - Include expansion with when conditions and cap=5

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER FixturePath
    Fixture JSON path relative to repo root.

.PARAMETER Verbose
    Prints detailed route scoring diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/test-routing-selection.ps1

.EXAMPLE
    pwsh -File scripts/validation/test-routing-selection.ps1 -Verbose

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $FixturePath = 'scripts/validation/fixtures/routing-golden-tests.json',
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent

# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($Verbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Resolves and sets the working directory to the repository root.
function Set-CorrectWorkingDirectory {
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
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $i++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Set-Location -Path $current
                return $current
            }
            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Builds an absolute path from repository root and relative path input.
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

# Converts YAML scalar nodes into normalized PowerShell primitive values.
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

# Loads and validates the routing catalog YAML into a normalized model.
function Get-CatalogModel {
    param(
        [string] $CatalogPath
    )

    $lines = Get-Content -LiteralPath $CatalogPath
    $alwaysPaths = @()
    $routes = @()

    $inAlways = $false
    $inRouting = $false
    $currentRoute = $null
    $currentInclude = $null
    $mode = ''
    $order = 0

    foreach ($line in $lines) {
        if ($line -match '^\s*always:\s*$') {
            $inAlways = $true
            continue
        }

        if ($line -match '^\s*routing:\s*$') {
            $inAlways = $false
            $inRouting = $true
            continue
        }

        if ($inAlways) {
            $alwaysMatch = [regex]::Match($line, '^\s*-\s*path:\s*(?<value>.+?)\s*$')
            if ($alwaysMatch.Success) {
                $alwaysPaths += (Convert-YamlScalar -Value $alwaysMatch.Groups['value'].Value)
            }
            continue
        }

        if (-not $inRouting) {
            continue
        }

        if ($line -match '^\s*prompts:\s*$') {
            if ($null -ne $currentInclude -and $null -ne $currentRoute) {
                $currentRoute.Includes += , $currentInclude
                $currentInclude = $null
            }
            if ($null -ne $currentRoute) {
                $routes += , $currentRoute
                $currentRoute = $null
            }
            break
        }

        $routeMatch = [regex]::Match($line, '^\s{2}- id:\s*(?<id>.+?)\s*$')
        if ($routeMatch.Success) {
            if ($null -ne $currentInclude -and $null -ne $currentRoute) {
                $currentRoute.Includes += , $currentInclude
                $currentInclude = $null
            }
            if ($null -ne $currentRoute) {
                $routes += , $currentRoute
            }

            $order++
            $routeId = Convert-YamlScalar -Value $routeMatch.Groups['id'].Value
            $currentRoute = [pscustomobject]@{
                Id = $routeId
                Order = $order
                Triggers = @()
                Includes = @()
            }
            $mode = ''
            continue
        }

        if ($null -eq $currentRoute) {
            continue
        }

        if ($line -match '^\s{4}triggers:\s*$') {
            if ($null -ne $currentInclude -and $null -ne $currentRoute) {
                $currentRoute.Includes += , $currentInclude
                $currentInclude = $null
            }
            $mode = 'triggers'
            continue
        }

        if ($line -match '^\s{4}include:\s*$') {
            if ($null -ne $currentInclude -and $null -ne $currentRoute) {
                $currentRoute.Includes += , $currentInclude
                $currentInclude = $null
            }
            $mode = 'include'
            continue
        }

        if ($mode -eq 'triggers') {
            $triggerMatch = [regex]::Match($line, '^\s{6}-\s*(?<value>.+?)\s*$')
            if ($triggerMatch.Success) {
                $trigger = Convert-YamlScalar -Value $triggerMatch.Groups['value'].Value
                if (-not [string]::IsNullOrWhiteSpace($trigger)) {
                    $currentRoute.Triggers += $trigger
                }
            }
            continue
        }

        if ($mode -eq 'include') {
            $pathMatch = [regex]::Match($line, '^\s{6}- path:\s*(?<value>.+?)\s*$')
            if ($pathMatch.Success) {
                if ($null -ne $currentInclude -and $null -ne $currentRoute) {
                    $currentRoute.Includes += , $currentInclude
                }
                $currentInclude = [pscustomobject]@{
                    Path = Convert-YamlScalar -Value $pathMatch.Groups['value'].Value
                    When = ''
                    Reason = ''
                }
                continue
            }

            if ($null -ne $currentInclude) {
                $whenMatch = [regex]::Match($line, '^\s{8}when:\s*(?<value>.+?)\s*$')
                if ($whenMatch.Success) {
                    $currentInclude.When = Convert-YamlScalar -Value $whenMatch.Groups['value'].Value
                    continue
                }

                $reasonMatch = [regex]::Match($line, '^\s{8}reason:\s*(?<value>.+?)\s*$')
                if ($reasonMatch.Success) {
                    $currentInclude.Reason = Convert-YamlScalar -Value $reasonMatch.Groups['value'].Value
                    continue
                }
            }
        }
    }

    if ($null -ne $currentInclude -and $null -ne $currentRoute) {
        $currentRoute.Includes += , $currentInclude
        $currentInclude = $null
    }
    if ($null -ne $currentRoute) {
        $routes += , $currentRoute
    }

    return [pscustomobject]@{
        AlwaysPaths = $alwaysPaths
        Routes = $routes
    }
}

# Evaluates route when-conditions against provided request context values.
function Test-WhenCondition {
    param(
        [string] $When,
        [string] $Request
    )

    if ([string]::IsNullOrWhiteSpace($When)) {
        return $true
    }

    $requestLower = $Request.ToLowerInvariant()
    $whenLower = $When.ToLowerInvariant()

    if ($requestLower.Contains($whenLower)) {
        return $true
    }

    if ($whenLower.Contains('editing')) {
        foreach ($keyword in @('edit', 'editing', 'modify', 'update', 'change')) {
            if ($requestLower.Contains($keyword)) {
                return $true
            }
        }
    }

    return $false
}

# Selects matching routes based on include and exclude condition checks.
function Get-RouteSelection {
    param(
        [object[]] $Routes,
        [string] $Request
    )

    $requestLower = $Request.ToLowerInvariant()
    $scores = New-Object System.Collections.Generic.List[object]

    foreach ($route in $Routes) {
        $hits = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($trigger in $route.Triggers) {
            if ([string]::IsNullOrWhiteSpace($trigger)) {
                continue
            }

            $triggerLower = $trigger.ToLowerInvariant()
            if ($requestLower.Contains($triggerLower)) {
                $hits.Add($trigger) | Out-Null
            }
        }

        $scores.Add([pscustomobject]@{
            Route = $route
            Score = $hits.Count
        }) | Out-Null
    }

    $matchedAtLeastTwo = @($scores | Where-Object { $_.Score -ge 2 })
    $matchedAtLeastOne = @($scores | Where-Object { $_.Score -ge 1 })

    $candidates = @()
    if ($matchedAtLeastTwo.Count -gt 0) {
        $candidates = $matchedAtLeastTwo
    }
    elseif ($matchedAtLeastOne.Count -gt 0) {
        $candidates = $matchedAtLeastOne
    }

    $sortedCandidates = @($candidates | Sort-Object -Property @{ Expression = { $_.Score }; Descending = $true }, @{ Expression = { $_.Route.Order }; Descending = $false })
    $selectedRouteIds = @($sortedCandidates | ForEach-Object { $_.Route.Id })

    $selectedPaths = New-Object System.Collections.Generic.List[string]
    $selectedSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($candidate in $sortedCandidates) {
        foreach ($include in $candidate.Route.Includes) {
            if (-not (Test-WhenCondition -When $include.When -Request $Request)) {
                continue
            }

            if ($selectedSet.Contains($include.Path)) {
                continue
            }

            $selectedSet.Add($include.Path) | Out-Null
            $selectedPaths.Add($include.Path) | Out-Null

            if ($selectedPaths.Count -ge 5) {
                break
            }
        }

        if ($selectedPaths.Count -ge 5) {
            break
        }
    }

    return [pscustomobject]@{
        RouteIds = $selectedRouteIds
        Paths = @($selectedPaths)
    }
}

# Compares two arrays for length and element-wise equality.
function Test-ArrayEquals {
    param(
        [string[]] $Expected,
        [string[]] $Actual
    )

    if ($Expected.Count -ne $Actual.Count) {
        return $false
    }

    for ($i = 0; $i -lt $Expected.Count; $i++) {
        if ($Expected[$i] -ne $Actual[$i]) {
            return $false
        }
    }

    return $true
}

$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot
$catalogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/instruction-routing.catalog.yml'
$fixtureAbsolutePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $FixturePath

if (-not (Test-Path -LiteralPath $catalogPath)) {
    throw "Catalog file not found: $catalogPath"
}

if (-not (Test-Path -LiteralPath $fixtureAbsolutePath)) {
    throw "Fixture file not found: $fixtureAbsolutePath"
}

$fixture = Get-Content -Raw -LiteralPath $fixtureAbsolutePath | ConvertFrom-Json -Depth 100
if ($null -eq $fixture.cases -or @($fixture.cases).Count -eq 0) {
    throw "Fixture has no test cases: $fixtureAbsolutePath"
}

$catalog = Get-CatalogModel -CatalogPath $catalogPath
if (@($catalog.Routes).Count -eq 0) {
    throw 'No routes parsed from instruction-routing.catalog.yml'
}

$failures = New-Object System.Collections.Generic.List[string]
$total = @($fixture.cases).Count
$passed = 0

foreach ($case in $fixture.cases) {
    $expectedRouteIds = @($case.expected_route_ids)
    $expectedSelectedPaths = @($case.expected_selected_paths)
    $result = Get-RouteSelection -Routes $catalog.Routes -Request $case.request

    Write-VerboseColor ("Case '{0}' -> routes=[{1}] paths=[{2}]" -f $case.id, ($result.RouteIds -join ', '), ($result.Paths -join ', ')) 'Gray'

    $routeMatch = Test-ArrayEquals -Expected $expectedRouteIds -Actual @($result.RouteIds)
    $pathMatch = Test-ArrayEquals -Expected $expectedSelectedPaths -Actual @($result.Paths)

    if ($routeMatch -and $pathMatch) {
        $passed++
        continue
    }

    $failures.Add(
        ("Case '{0}' failed. Expected routes=[{1}] actual=[{2}] | Expected paths=[{3}] actual=[{4}]" -f
            $case.id,
            ($expectedRouteIds -join ', '),
            (@($result.RouteIds) -join ', '),
            ($expectedSelectedPaths -join ', '),
            (@($result.Paths) -join ', '))
    ) | Out-Null
}

Write-Host 'Routing golden test summary' -ForegroundColor Cyan
Write-Host ("  Cases: {0}" -f $total)
Write-Host ("  Passed: {0}" -f $passed)
Write-Host ("  Failed: {0}" -f $failures.Count)

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host ("[FAIL] {0}" -f $failure) -ForegroundColor Red
    }
    exit 1
}

Write-Host 'All routing golden tests passed.' -ForegroundColor Green
exit 0