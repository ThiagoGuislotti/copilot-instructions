<#
.SYNOPSIS
    Executes .NET test projects with code coverage collection and merges HTML/Cobertura reports.
.DESCRIPTION
    Runs .NET test projects with code coverage collection, merges coverage reports,
    and generates HTML coverage reports using ReportGenerator.

    This script uses VSTest collector (XPlat Code Coverage) which is the recommended
    approach for .NET test coverage collection. It automatically handles TRX generation,
    coverage collection, and report merging.

    Projects are resolved in this order: direct path → tests/<Name>/<Name>.csproj → search under tests/
    SolutionDir property is automatically set to repository root for proper MSBuild evaluation
    Coverage files are collected from TRX attachment folders and merged using ReportGenerator
    TRX attachment folders are cleaned by default to save disk space (use -NoClean to preserve)
    Coverage history is maintained for trend analysis in ReportGenerator reports
.PARAMETER Project
    Single test project (name, .csproj path, or folder). Projects are resolved by name under tests/,
    direct file path, or directory containing a .csproj file.
.PARAMETER Projects
    Array of test projects (names, paths, or folders). Each entry follows the same resolution
    logic as the Project parameter.
.PARAMETER ProjectsDir
    Directory to scan recursively for .csproj files. Can be relative to repository root
    or an absolute path.
.PARAMETER Framework
    Target framework (e.g., net8.0, net9.0). Default: net9.0
.PARAMETER OutputRoot
    Root output directory for all artifacts. Default: .deployment/tests
.PARAMETER NoClean
    If present, keeps TRX attachment folders after processing. By default, these are cleaned
    to save disk space after coverage files are merged.
.PARAMETER Verbose
    If present, shows detailed logging and command execution including underlying dotnet commands.
.EXAMPLE
    .\scripts\tests\run-coverage.ps1 -Project NetToolsKit.Core.UnitTests

    Runs coverage for a single project by name, using convention-based discovery.
.EXAMPLE
    .\scripts\tests\run-coverage.ps1 -Project "tests\NetToolsKit.Json.UnitTests\NetToolsKit.Json.UnitTests.csproj"

    Runs coverage for a single project using a direct .csproj path.
.EXAMPLE
    .\scripts\tests\run-coverage.ps1 -Projects NetToolsKit.Core.UnitTests,NetToolsKit.Json.UnitTests

    Runs coverage for multiple projects specified as an array.
.EXAMPLE
    .\scripts\tests\run-coverage.ps1 -ProjectsDir tests

    Runs coverage for all test projects found under the tests directory.
.EXAMPLE
    .\scripts\tests\run-coverage.ps1 -ProjectsDir tests -Framework net8.0 -OutputRoot ".coverage" -Verbose

    Runs all tests with a custom framework, output folder and verbose logging.
.EXAMPLE
    .\scripts\tests\run-coverage.ps1 -Project NetToolsKit.Core.UnitTests -NoClean

    Runs coverage and keeps TRX attachment folders for debugging purposes.
.EXAMPLE
    Executes every test project, preserves attachments and prints detailed dotnet commands.
    .\scripts\tests\run-coverage.ps1 -ProjectsDir tests -NoClean -Verbose
#>

param(
    [string]$Project = "",
    [string[]]$Projects = @(),
    [string]$ProjectsDir = "",
    [string]$Framework = "net9.0",
    [string]$OutputRoot = ".deployment/tests",
    [switch]$NoClean,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Logging functions
# Writes informational messages to the console.
function Write-Info($msg) {
    Write-Host "INFO: $msg" -ForegroundColor Green
}

# Writes verbose messages only when verbose mode is enabled.
function Write-Verbose2($msg) {
    if ($Verbose) {
        Write-Host "VERBOSE: $msg" -ForegroundColor Gray
    }
}

# Writes warning messages to the console.
function Write-Warning2($msg) {
    Write-Host "WARN: $msg" -ForegroundColor Yellow
}

# Writes minimal required progress output for non-verbose runs.
function Write-Minimal($msg) {
    # Always show minimal essential information
    Write-Host $msg -ForegroundColor Cyan
}

# Resolve repo root (two levels up from this script)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Split-Path -Parent (Split-Path -Parent $ScriptDir))

# Validate repo root
if (-not (Test-Path (Join-Path $RepoRoot ".git")) -and -not (Test-Path (Join-Path $RepoRoot "*.sln"))) {
    Write-Warning2 "Repository root detection may be incorrect: $RepoRoot"
}

# Setup artifact directories
$CoverageDir = Join-Path $RepoRoot (Join-Path $OutputRoot 'coverage')
$HistoryDir  = Join-Path $RepoRoot (Join-Path $OutputRoot 'coverage-history')
$TrxDir      = Join-Path $RepoRoot (Join-Path $OutputRoot 'trx')

Write-Verbose2 "Creating output directories..."
New-Item -ItemType Directory -Force -Path $CoverageDir, $HistoryDir, $TrxDir | Out-Null

# Ensure reportgenerator tool is available
# Ensures the ReportGenerator global tool is installed and available.
function Ensure-ReportGenerator {
    Write-Verbose2 "Checking for ReportGenerator tool..."
    $rg = Get-Command reportgenerator -ErrorAction SilentlyContinue
    if (-not $rg) {
        if ($Verbose) { Write-Info "ReportGenerator not found, attempting to install/update..." }
        $tools = Join-Path $env:USERPROFILE '.dotnet\tools'
        if (Test-Path $tools) {
            $env:PATH = "$tools;$env:PATH"
            Write-Verbose2 "Added .NET tools to PATH: $tools"
        }
        try {
            Write-Verbose2 "Updating dotnet-reportgenerator-globaltool..."
            dotnet tool update -g dotnet-reportgenerator-globaltool *> $null
        } catch {
            Write-Verbose2 "Installing dotnet-reportgenerator-globaltool..."
            dotnet tool install -g dotnet-reportgenerator-globaltool *> $null
        }
    }
    if (-not (Get-Command reportgenerator -ErrorAction SilentlyContinue)) {
        throw 'ReportGenerator not found. Please install dotnet-reportgenerator-globaltool manually: dotnet tool install -g dotnet-reportgenerator-globaltool'
    }
    Write-Verbose2 "ReportGenerator tool is available"
}

# Display configuration (only in verbose mode)
if ($Verbose) {
    Write-Info "=== Test Coverage Configuration ==="
    Write-Info "Repository root: $RepoRoot"
    Write-Info "Output root: $OutputRoot"
    Write-Info "  - Coverage: $CoverageDir"
    Write-Info "  - History:  $HistoryDir"
    Write-Info "  - TRX:      $TrxDir"
    Write-Info "Target framework: $Framework"
    Write-Info "Single project: $(if ($Project) { $Project } else { '<none>' })"
    Write-Info "Multiple projects: $(if ($Projects.Count -gt 0) { $Projects -join ', ' } else { '<none>' })"
    Write-Info "Projects directory: $(if ($ProjectsDir) { $ProjectsDir } else { '<none>' })"
    Write-Info "Clean TRX attachments: $(-not $NoClean)"
    Write-Info "========================================"
} else {
    Write-Minimal "Running test coverage collection..."
}

# Resolve SolutionDir and pass it explicitly (required for MSBuild property evaluation)
$SolutionDir = ($RepoRoot.TrimEnd('\','/')) + '\'  # trailing backslash required by MSBuild

# Project resolution function with improved error handling
# Resolves a project name or path into a concrete .csproj file path.
function Resolve-ProjectPath([string]$nameOrPath) {
    if ([string]::IsNullOrWhiteSpace($nameOrPath)) { return $null }

    Write-Verbose2 "Resolving project: $nameOrPath"

    # Direct path resolution
    if (Test-Path $nameOrPath) {
        $item = Get-Item $nameOrPath
        if ($item.PSIsContainer) {
            # Directory - look for .csproj inside
            $csproj = Get-ChildItem -Path $nameOrPath -Filter *.csproj -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($csproj) {
                Write-Verbose2 "  → Found .csproj in directory: $($csproj.FullName)"
                return $csproj.FullName
            }
        } else {
            # File - assume it's a .csproj
            Write-Verbose2 "  → Direct file path: $($item.FullName)"
            return $item.FullName
        }
    }

    # Convention-based search: tests/<Name>/<Name>.csproj
    $conventionPath = Join-Path $RepoRoot (Join-Path 'tests' ("$nameOrPath/$nameOrPath.csproj"))
    if (Test-Path $conventionPath) {
        Write-Verbose2 "  → Found via convention: $conventionPath"
        return $conventionPath
    }

    # Recursive search under tests/
    $testsDir = Join-Path $RepoRoot 'tests'
    if (Test-Path $testsDir) {
        $found = Get-ChildItem -Path $testsDir -Recurse -Filter "$nameOrPath.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            Write-Verbose2 "  → Found via recursive search: $($found.FullName)"
            return $found.FullName
        }
    }

    Write-Verbose2 "  → Not found"
    return $null
}

# Build list of projects to test
$projList = New-Object System.Collections.Generic.List[string]

# Add single project
if (-not [string]::IsNullOrWhiteSpace($Project)) {
    $projList.Add($Project) | Out-Null
    Write-Verbose2 "Added single project: $Project"
}

# Add multiple projects
if ($Projects -and $Projects.Count -gt 0) {
    $Projects | ForEach-Object {
        $projList.Add($_) | Out-Null
        Write-Verbose2 "Added project from array: $_"
    }
}

# Add projects from directory scan
if (-not [string]::IsNullOrWhiteSpace($ProjectsDir)) {
    $scanDir = if (Test-Path $ProjectsDir) { $ProjectsDir } else { Join-Path $RepoRoot $ProjectsDir }
    Write-Verbose2 "Scanning directory for projects: $scanDir"

    if (-not (Test-Path $scanDir)) {
        throw "Projects directory not found: $scanDir"
    }

    $foundProjects = Get-ChildItem -Path $scanDir -Recurse -Filter *.csproj -ErrorAction SilentlyContinue
    $foundProjects | ForEach-Object {
        $projList.Add($_.FullName) | Out-Null
        Write-Verbose2 "Added project from directory scan: $($_.FullName)"
    }
    if ($Verbose) {
        Write-Info "Found $($foundProjects.Count) projects in directory"
    } else {
        Write-Minimal "Found $($foundProjects.Count) test projects"
    }
}

# Validate we have projects to test
if ($projList.Count -eq 0) {
    throw 'No projects specified. Provide -Project <Name|Path>, -Projects <array>, or -ProjectsDir <directory>'
}

if ($Verbose) {
    Write-Info "Total projects to test: $($projList.Count)"
} else {
    Write-Minimal "Testing $($projList.Count) projects..."
}

# Execute tests with coverage collection
$successCount = 0
$failCount = 0

foreach ($p in $projList | Select-Object -Unique) {
    $projPath = Resolve-ProjectPath $p
    if (-not $projPath) {
        Write-Warning2 "Project not found, skipping: $p"
        $failCount++
        continue
    }

    if ($Verbose) {
        Write-Info "Testing project: $projPath"
    } else {
        $projectName = [IO.Path]::GetFileNameWithoutExtension($projPath)
        Write-Host "  • $projectName" -ForegroundColor Gray
    }

    # Generate unique log name based on project
    $logName = [IO.Path]::GetFileNameWithoutExtension($projPath)

    # Build dotnet test arguments
    $args = @(
        'test', $projPath,
        '-c', 'Release',
        '-f', $Framework,
        "-property:SolutionDir=$SolutionDir",
        '--logger', "trx;LogFileName=$logName.trx",
        '--results-directory', $TrxDir,
        '--collect', 'XPlat Code Coverage;Format=cobertura',
        '--nologo'
    )

    if ($Verbose) {
        $args += '--verbosity', 'normal'
    } else {
        $args += '--verbosity', 'quiet'
    }

    Write-Verbose2 "Command: dotnet $($args -join ' ')"

    try {
        & dotnet @args
        if ($Verbose) {
            Write-Info "✓ Test completed successfully: $logName"
        }
        $successCount++
    } catch {
        Write-Warning2 "✗ Test failed: $logName - $($_.Exception.Message)"
        $failCount++
    }
}

if ($Verbose) {
    Write-Info "Test execution summary: $successCount succeeded, $failCount failed"
} else {
    if ($failCount -gt 0) {
        Write-Host "Test summary: $successCount passed, $failCount failed" -ForegroundColor Yellow
    } else {
        Write-Host "Test summary: $successCount passed" -ForegroundColor Green
    }
}

# Merge coverage reports and generate HTML
if ($Verbose) {
    Write-Info "Processing coverage reports..."
} else {
    Write-Minimal "Generating coverage report..."
}
Ensure-ReportGenerator

$coveragePattern = Join-Path $TrxDir '**\coverage.cobertura.xml'
Write-Verbose2 "Searching for coverage files with pattern: $coveragePattern"

# Verify we have coverage files to process
$coverageFiles = Get-ChildItem -Path $TrxDir -Recurse -Filter "coverage.cobertura.xml" -ErrorAction SilentlyContinue
if ($coverageFiles.Count -eq 0) {
    Write-Warning2 "No coverage files found. Tests may have failed or coverage collection was disabled."
} else {
    Write-Verbose2 "Found $($coverageFiles.Count) coverage files to merge"

    # Generate merged coverage report
    Write-Verbose2 "Generating merged coverage report..."
    $rgArgs = @(
        "-reports:$coveragePattern",
        "-targetdir:$CoverageDir",
        "-historydir:$HistoryDir",
        "-reporttypes:Cobertura;Html;HtmlSummary"
    )

    Write-Verbose2 "ReportGenerator args: $($rgArgs -join ' ')"
    & reportgenerator @rgArgs | Out-Null

    # Display results
    $indexPath = Join-Path $CoverageDir 'index.html'
    $coberturaPath = Join-Path $CoverageDir 'Cobertura.xml'

    if (Test-Path $indexPath) {
        if ($Verbose) {
            Write-Info "✓ HTML coverage report generated: $indexPath"
        } else {
            Write-Host "Coverage report: $indexPath" -ForegroundColor Green
        }
        try {
            Start-Process $indexPath | Out-Null
            if ($Verbose) {
                Write-Info "Coverage report opened in browser"
            } else {
                Write-Host "Report opened in browser" -ForegroundColor Green
            }
        } catch {
            Write-Verbose2 "Could not open browser automatically: $($_.Exception.Message)"
        }
    }

    if (Test-Path $coberturaPath) {
        Write-Verbose2 "✓ Cobertura XML report: $coberturaPath"
    }
}

# Optional cleanup of TRX attachment folders
if (-not $NoClean) {
    Write-Verbose2 "Cleaning up TRX attachment folders..."
    try {
        $attachDirs = Get-ChildItem -Path $TrxDir -Directory -ErrorAction SilentlyContinue
        $cleanedCount = 0

        foreach ($dir in $attachDirs) {
            $hasCoverage = Get-ChildItem -Path $dir.FullName -Recurse -Filter "coverage.cobertura.xml" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hasCoverage) {
                Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                $cleanedCount++
                Write-Verbose2 "Cleaned attachment directory: $($dir.Name)"
            }
        }

        if ($cleanedCount -gt 0 -and $Verbose) {
            Write-Info "Cleaned $cleanedCount TRX attachment directories"
        }
    } catch {
        Write-Verbose2 "Cleanup warning: $($_.Exception.Message)"
    }
} else {
    Write-Verbose2 "Skipping TRX cleanup (NoClean specified)"
}

if ($Verbose) {
    Write-Info "=== Coverage Collection Complete ==="
    Write-Info "Results available in: $OutputRoot"
    Write-Info "========================================"
} else {
    Write-Minimal "Coverage collection complete!"
}