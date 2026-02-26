<#
.SYNOPSIS
    Validates whether test method names follow the triple-underscore convention (e.g., Feature_Context_Result).

.DESCRIPTION
    Detects the solution root automatically (Set-CorrectWorkingDirectory) and inspects every test project found
    under the repository. You can optionally narrow the scan to specific projects via -Projects or change the
    starting directory through -Path. The script extracts methods decorated with common test attributes (xUnit,
    NUnit, MSTest) and verifies that their names contain at least the configured number of underscore separators.

    Workflow:
        • Locate test projects (*.Tests.csproj, *.UnitTests.csproj, *.IntegrationTests.csproj, etc.).
        • Parse C# files inside those projects, looking for methods with test attributes.
        • Count underscores in method names and compare against the required threshold (default: 3 underscores).
        • Report any violations and exit with code 1 so the script can be used in CI pipelines.

.PARAMETER Path
    Optional starting directory. If omitted, the script searches for the repository root automatically.

.PARAMETER Projects
    Optional list of project identifiers (folder, csproj name, or partial match). Only matching test projects are scanned.

.PARAMETER RequiredUnderscores
    Minimum number of underscores required in each test method name. Defaults to 3 (four segments).

.PARAMETER Verbose
    Emits color-coded diagnostics (projects scanned, files processed, method matches).

.EXAMPLE
    # Validate every test project in the repository root.
    pwsh -File scripts/tests/check-test-naming.ps1

.EXAMPLE
    # Preview validation with verbose logs to audit parsed methods.
    pwsh -File scripts/tests/check-test-naming.ps1 -Verbose

.EXAMPLE
    # Restrict validation to a subset of projects (partial names accepted).
    pwsh -File scripts/tests/check-test-naming.ps1 -Projects "OpenApi.Readers.UnitTests","Swagger.UnitTests"

.EXAMPLE
    # Adjust the convention to two underscores (three segments) if needed.
    pwsh -File scripts/tests/check-test-naming.ps1 -RequiredUnderscores 2

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Git CLI (optional for root detection).
    Exit codes: 0 when all tests comply, 1 when violations are detected, other codes for unexpected errors.
#>

param (
    [string] $Path,
    [string[]] $Projects,
    [int] $RequiredUnderscores = 3,
    [switch] $Verbose
)

if ($RequiredUnderscores -lt 1) {
    throw "RequiredUnderscores must be greater than or equal to 1."
}

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

$testAttributePattern = [regex]'(?i)\[(Fact|Theory|Test|TestMethod|DataTestMethod|TestCase|TestCaseSource|SkippableFact|SkippableTheory|Property|Combinatorial|Sequential)\b'
$methodPattern = '(?ms)((?:\s*\[[^\]]+\]\s*)+)\s*public\s+(?:async\s+)?(?:Task|ValueTask|void)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*\('

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param (
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE:{0}] {1}" -f $Color, $Message)
    }
}

# Resolves the repository root using explicit and fallback location candidates.
function Resolve-SolutionRoot {
    param (
        [string] $StartPath
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($StartPath)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $StartPath).Path
        }
        catch {
            Write-Warning ("Unable to resolve path '{0}': {1}" -f $StartPath, $_.Exception.Message)
        }
    }

    if ($script:ScriptRoot) {
        $candidates += $script:ScriptRoot
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($i = 0; $i -lt 5 -and $current; $i++) {
            $hasSln = Test-Path (Join-Path -Path $current -ChildPath 'NetToolsKit.sln')
            $hasLayout = (Test-Path (Join-Path -Path $current -ChildPath 'src')) -and (Test-Path (Join-Path -Path $current -ChildPath '.github'))

            if ($hasSln -or $hasLayout) {
                Write-StyledOutput ("Solution root found: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw "Could not find solution root."
}

# Resolves target test project files from explicit inputs or defaults.
function Resolve-TestProject {
    param (
        [string] $Root,
        [string[]] $RequestedProjects
    )

    $allProjects = Get-ChildItem -Path $Root -Recurse -Filter '*.csproj' |
        Where-Object { $_.Name -match 'Tests\.csproj$' } |
        ForEach-Object {
            [pscustomobject]@{
                Name      = $_.BaseName
                Path      = $_.FullName
                Directory = $_.Directory.FullName
            }
        }

    if (-not $allProjects) {
        Write-Warning "No test projects (*.Tests.csproj) were found."
        return @()
    }

    if (-not $RequestedProjects -or $RequestedProjects.Count -eq 0) {
        return $allProjects
    }

    $normalized = $RequestedProjects |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() }

    $selected = $allProjects | Where-Object {
        $proj = $_
        $normalized | Where-Object {
            $needle = $_
            ($proj.Name -like "*$needle*") -or ($proj.Path -like "*$needle*")
        }
    }

    $missing = $normalized | Where-Object {
        $needle = $_
        -not ($selected | Where-Object { $_.Name -like "*$needle*" -or $_.Path -like "*$needle*" })
    }

    foreach ($item in $missing) {
        Write-Warning ("Requested project '{0}' was not found among discovered test projects." -f $item)
    }

    return $selected
}

# Collects test source files from resolved test project directories.
function Get-TestFile {
    param (
        [string] $ProjectDirectory
    )

    Get-ChildItem -Path $ProjectDirectory -Recurse -File -Filter '*.cs' |
        Where-Object {
            $full = $_.FullName
            ($full -notmatch '\\(bin|obj|artifacts)\\') -and
            ($full -match 'Tests\\' -or $_.Name -like '*Tests.cs')
        }
}

# Extracts test method names from a source file for naming validation.
function Get-TestMethodsFromFile {
    param (
        [string] $FilePath
    )

    $content = Get-Content -LiteralPath $FilePath -Raw
    $methodMatches = [regex]::Matches($content, $methodPattern)
    $methods = New-Object System.Collections.Generic.List[string]

    foreach ($match in $methodMatches) {
        $attributesBlock = $match.Groups[1].Value

        if (-not $testAttributePattern.IsMatch($attributesBlock)) {
            continue
        }

        $methods.Add($match.Groups['name'].Value) | Out-Null
    }

    return $methods
}

# -------------------------------
# Discovery Phase
# -------------------------------
$repoRoot = Resolve-SolutionRoot -StartPath $Path
Set-Location -Path $repoRoot

$projects = Resolve-TestProject -Root $repoRoot -RequestedProjects $Projects

if (-not $projects -or $projects.Count -eq 0) {
    Write-StyledOutput "No test projects selected for validation."
    exit 0
}

Write-StyledOutput ("Projects selected: {0}" -f ($projects.Name -join ', '))

# -------------------------------
# Validation Phase
# -------------------------------
$violations = New-Object System.Collections.Generic.List[pscustomobject]

foreach ($project in $projects) {
    Write-VerboseColor ("Scanning project: {0}" -f $project.Name) 'Cyan'

    $files = Get-TestFile -ProjectDirectory $project.Directory
    Write-VerboseColor ("  Files found: {0}" -f $files.Count) 'Cyan'

    foreach ($file in $files) {
        $methods = Get-TestMethodsFromFile -FilePath $file.FullName

        if ($methods.Count -eq 0) {
            Write-VerboseColor ("    No test methods in {0}" -f ([IO.Path]::GetRelativePath($repoRoot, $file.FullName))) 'DarkGray'
            continue
        }

        foreach ($method in $methods) {
            $underscoreCount = ([regex]::Matches($method, '_')).Count

            Write-VerboseColor ("    Method {0} has {1} underscore(s)" -f $method, $underscoreCount) 'Gray'

            if ($underscoreCount -lt $RequiredUnderscores) {
                $violations.Add([pscustomobject]@{
                    Project    = $project.Name
                    File       = [IO.Path]::GetRelativePath($repoRoot, $file.FullName)
                    Method     = $method
                    Underscores = $underscoreCount
                }) | Out-Null
            }
        }
    }
}

# -------------------------------
# Reporting
# -------------------------------
if ($violations.Count -gt 0) {
    Write-StyledOutput ("Found {0} test method(s) violating the underscore convention (required: {1})." -f $violations.Count, $RequiredUnderscores)

    $violations |
        Sort-Object Project, File, Method |
        ForEach-Object {
            Write-StyledOutput ("- {0} :: {1} :: {2} (underscores: {3})" -f $_.Project, $_.File, $_.Method, $_.Underscores)
        }

    exit 1
}

Write-StyledOutput ("All test method names satisfy the underscore convention (>= {0})." -f $RequiredUnderscores)
exit 0