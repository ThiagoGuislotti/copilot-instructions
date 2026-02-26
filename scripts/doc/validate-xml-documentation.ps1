<#
.SYNOPSIS
    Audits C# projects to detect types missing XML <summary> documentation.

.DESCRIPTION
    Recursively scans C# project files and inspects classes, interfaces, enums, records and structs
    to verify whether they contain XML documentation comments. The script prints a summary per project,
    highlights missing entries, and can export findings to JSON for further processing (e.g., via AI tooling).

.PARAMETER ProjectPath
    Optional. Path to a single project or folder containing one project to validate.

.PARAMETER Projects
    Optional. Array of project paths to validate explicitly.

.PARAMETER SourceFolder
    Optional. Root folder (default: src) used for automatic discovery when neither ProjectPath nor Projects is supplied.

.PARAMETER IncludeTests
    Includes test projects during automatic discovery. Tests are ignored by default.

.PARAMETER ExportMissing
    Exports the list of missing documentation entries to a JSON file.

.PARAMETER OutputPath
    Path to the JSON file generated when -ExportMissing is provided. Default: docs\missing-documentation.json.

.PARAMETER GroupByProject
    Groups the console report by project instead of showing a flat list.

.EXAMPLE
    Validates every project found under the default "src" folder.
    pwsh -File scripts/doc/validate-xml-documentation.ps1

.EXAMPLE
    Validates only the specified project and groups missing entries by project.
    pwsh -File scripts/doc/validate-xml-documentation.ps1 -ProjectPath "src/Api/Api.csproj" -GroupByProject

.EXAMPLE
    Validates an explicit list of projects and exports missing items to a custom JSON file.
    pwsh -File scripts/doc/validate-xml-documentation.ps1 -Projects @('src/Domain/Domain.csproj','src/Application/Application.csproj') -ExportMissing -OutputPath 'docs/domain-missing.json'

.EXAMPLE
    Validates all discovered projects and exports the missing documentation list.
    pwsh -File scripts/doc/validate-xml-documentation.ps1 -ExportMissing -OutputPath "docs/missing.json"

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, read access to target projects.
#>

param(
    [Parameter(Position = 0)]
    [string]$ProjectPath = "",

    [Parameter()]
    [string[]]$Projects = @(),

    [Parameter()]
    [string]$SourceFolder = "src",

    [switch]$IncludeTests = $false,
    [switch]$ExportMissing = $false,
    [switch]$GroupByProject = $false,

    [Parameter()]
    [string]$OutputPath = "docs\missing-documentation.json"
)

$ErrorActionPreference = "Stop"

# Helper: discover projects automatically
# Enumerates project files under a folder while honoring exclusion rules.
function Get-ProjectsFromFolder {
    param([string]$Folder)

    if (-not (Test-Path $Folder)) {
        Write-Host "⚠ Folder not found: $Folder" -ForegroundColor Yellow
        return @()
    }

    $foundProjects = @{}
    $csprojFiles = Get-ChildItem -Path $Folder -Filter "*.csproj" -Recurse -File |
                   Where-Object {
                       $_.FullName -notmatch '\\obj\\' -and
                       $_.FullName -notmatch '\\bin\\' -and
                       ($IncludeTests -or $_.Name -notmatch 'Test')
                   }

    foreach ($csproj in $csprojFiles) {
        $projectDir = Split-Path -Parent $csproj.FullName
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)
        $foundProjects[$projectName] = $projectDir
    }

    return $foundProjects
}

# Determine which projects to process
$projectPaths = @{}

if ($Projects.Count -gt 0) {
    Write-Host "📋 Mode: explicit project list ($($Projects.Count) item(s))" -ForegroundColor Cyan
    foreach ($proj in $Projects) {
        if (Test-Path $proj) {
            $projectName = Split-Path -Leaf $proj
            $projectPaths[$projectName] = $proj
        } else {
            Write-Host "⚠ Project not found: $proj" -ForegroundColor Yellow
        }
    }
}
elseif ($ProjectPath -ne "") {
    if (Test-Path $ProjectPath) {
        if (Test-Path "$ProjectPath\*.csproj") {
            Write-Host "📁 Mode: single project" -ForegroundColor Cyan
            $projectName = Split-Path -Leaf $ProjectPath
            $projectPaths[$projectName] = $ProjectPath
        }
        elseif ((Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0) {
            Write-Host "📂 Mode: project folder" -ForegroundColor Cyan
            $projectPaths = Get-ProjectsFromFolder -Folder $ProjectPath
        }
        else {
            Write-Host "⚠ No project found at: $ProjectPath" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "⚠ Path not found: $ProjectPath" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "🔍 Mode: automatic discovery under '$SourceFolder'" -ForegroundColor Cyan
    $projectPaths = Get-ProjectsFromFolder -Folder $SourceFolder

    if ($projectPaths.Count -eq 0) {
        Write-Host "⚠ Nenhum projeto encontrado na pasta '$SourceFolder'" -ForegroundColor Yellow
        Write-Host "💡 Dica: Use -ProjectPath para especificar um caminho ou -Projects para uma lista" -ForegroundColor Gray
        exit 1
    }
}

# Statistics tracker
$stats = @{
    TotalFiles = 0
    Documented = 0
    Missing = 0
    Skipped = 0
}

$missingFiles = @()

# Validates XML documentation coverage and quality for a source file.
function Test-FileDocumentation {
    param([string]$FilePath, [string]$ProjectName)

    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $fileName = Split-Path -Leaf $FilePath
        $relativePath = $FilePath -replace [regex]::Escape((Get-Location).Path + '\'), ''

        # Extract type declaration (class/interface/enum/record/struct)
        $classMatch = $content -match '(?:public|internal|private|protected)\s+(?:sealed\s+)?(?:static\s+)?(?:abstract\s+)?(class|interface|enum|record|struct)\s+([A-Za-z0-9_<>,\s]+?)(?:\s*:\s*|\s*where\s*|\s*\{|\s*\()'

        if (-not $classMatch) {
            $stats.Skipped++
            return $null
        }

        $typeKind = $matches[1]
        $typeName = $matches[2].Trim() -replace '\s+', ' ' -replace '<.*', ''

        # Check for XML summary documentation
        $hasDocumentation = $content -match '///\s*<summary>'

        if ($hasDocumentation) {
            $stats.Documented++
            return $null
        } else {
            $stats.Missing++

            # Extract namespace when available
            $namespace = ""
            if ($content -match 'namespace\s+([^\r\n\{;]+)') {
                $namespace = $matches[1].Trim()
            }

            return @{
                Project = $ProjectName
                File = $fileName
                Path = $relativePath
                FullPath = $FilePath
                TypeKind = $typeKind
                TypeName = $typeName
                Namespace = $namespace
            }
        }

    } catch {
        Write-Host "  ✗ ERROR analyzing: $fileName - $($_.Exception.Message)" -ForegroundColor Red
        $stats.Skipped++
        return $null
    }
}

# Execution banner
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  XML Documentation Validation - C# Projects                ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

if ($projectPaths.Count -eq 0) {
    Write-Host "❌ No projects to validate.`n" -ForegroundColor Red
    Write-Host "💡 Usage examples:" -ForegroundColor Cyan
    Write-Host "   .\validate-xml-documentation.ps1                              # Validate everything under src\" -ForegroundColor Gray
    Write-Host "   .\validate-xml-documentation.ps1 -ExportMissing              # Export to JSON" -ForegroundColor Gray
    Write-Host "   .\validate-xml-documentation.ps1 -ProjectPath src\MyProject  # Single project" -ForegroundColor Gray
    exit 1
}

Write-Host "📦 Projects to validate: $($projectPaths.Count)" -ForegroundColor Cyan
foreach ($p in $projectPaths.GetEnumerator() | Sort-Object Key) {
    Write-Host "   • $($p.Key)" -ForegroundColor Gray
}
Write-Host ""

foreach ($project in $projectPaths.GetEnumerator() | Sort-Object Name) {
    $projectName = $project.Key
    $projectPath = $project.Value

    if (-not (Test-Path $projectPath)) {
        Write-Host "⚠ Project not found: $projectPath`n" -ForegroundColor Yellow
        continue
    }

    Write-Host "═══ $projectName ═══" -ForegroundColor Magenta

    $files = Get-ChildItem -Path $projectPath -Filter "*.cs" -Recurse -File |
             Where-Object {
                 $_.FullName -notmatch '\\obj\\' -and
                 $_.FullName -notmatch '\\bin\\' -and
                 $_.Name -ne 'GlobalSuppressions.cs' -and
                 $_.Name -ne 'AssemblyInfo.cs'
             } |
             Sort-Object FullName

    $projectTotal = $files.Count
    $stats.TotalFiles += $projectTotal

    Write-Host "Files processed: $projectTotal" -ForegroundColor Gray

    $projectMissing = 0
    foreach ($file in $files) {
        $result = Test-FileDocumentation -FilePath $file.FullName -ProjectName $projectName
        if ($null -ne $result) {
            $missingFiles += $result
            $projectMissing++
        }
    }

    if ($projectMissing -gt 0) {
        Write-Host "❌ Files missing documentation: $projectMissing" -ForegroundColor Red
    } else {
        Write-Host "✅ All files documented!" -ForegroundColor Green
    }

    Write-Host ""
}

# Final report
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  VALIDATION REPORT                                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Total files analyzed:        $($stats.TotalFiles)" -ForegroundColor White
Write-Host "✅ With documentation:        $($stats.Documented)" -ForegroundColor Green
Write-Host "❌ Missing documentation:     $($stats.Missing)" -ForegroundColor Red
Write-Host "⚠️  Skipped / no type found:  $($stats.Skipped)" -ForegroundColor Yellow

$coverage = if ($stats.TotalFiles -gt 0) {
    [math]::Round(($stats.Documented / ($stats.TotalFiles - $stats.Skipped)) * 100, 2)
} else { 0 }

Write-Host "`nDocumentation coverage: $coverage% ($($stats.Documented)/$($stats.TotalFiles - $stats.Skipped))" -ForegroundColor $(
    if ($coverage -eq 100) { "Green" }
    elseif ($coverage -ge 80) { "Cyan" }
    elseif ($coverage -ge 50) { "Yellow" }
    else { "Red" }
)

# List files missing documentation
if ($missingFiles.Count -gt 0) {
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  FILES MISSING DOCUMENTATION                                ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

    if ($GroupByProject) {
        $grouped = $missingFiles | Group-Object -Property Project | Sort-Object Name
        foreach ($group in $grouped) {
            Write-Host "📁 $($group.Name) ($($group.Count) file(s)):" -ForegroundColor Cyan
            foreach ($file in $group.Group | Sort-Object File) {
                Write-Host "   ❌ $($file.File) ($($file.TypeKind) $($file.TypeName))" -ForegroundColor Red
                Write-Host "      $($file.Path)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    } else {
        foreach ($file in $missingFiles | Sort-Object Project, File) {
            Write-Host "❌ [$($file.Project)] $($file.File)" -ForegroundColor Red
            Write-Host "   Type: $($file.TypeKind) | Name: $($file.TypeName)" -ForegroundColor Gray
            Write-Host "   Path: $($file.Path)" -ForegroundColor DarkGray
            if ($file.Namespace) {
                Write-Host "   Namespace: $($file.Namespace)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
}

# Export to JSON (optional)
if ($ExportMissing -and $missingFiles.Count -gt 0) {
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $exportData = @{
        GeneratedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Summary = @{
            TotalFiles = $stats.TotalFiles
            Documented = $stats.Documented
            Missing = $stats.Missing
            Skipped = $stats.Skipped
            Coverage = $coverage
        }
        MissingDocumentation = $missingFiles
    }

    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  EXPORT COMPLETE                                            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
    Write-Host "📄 Exported file: $OutputPath" -ForegroundColor Cyan
    Write-Host "📊 Items without documentation: $($missingFiles.Count)" -ForegroundColor Yellow
    Write-Host "`n💡 Use this file with AI-assisted tooling to generate summaries in context." -ForegroundColor Gray
}
elseif ($ExportMissing -and $missingFiles.Count -eq 0) {
    Write-Host "`n✅ Nothing to export – all files already contain documentation!" -ForegroundColor Green
}

# Exit status
if ($stats.Missing -gt 0) {
    Write-Host "`n⚠️  Validation found $($stats.Missing) file(s) without documentation." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n✅ Validation complete – all files contain documentation!" -ForegroundColor Green
    exit 0
}