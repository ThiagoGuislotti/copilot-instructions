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

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:IncludeTestProjects = [bool] $IncludeTests

# Helper: discover projects automatically
# Enumerates project files under a folder while honoring exclusion rules.
function Get-ProjectsFromFolder {
    param([string]$Folder)

    if (-not (Test-Path $Folder)) {
        Write-StyledOutput "⚠ Folder not found: $Folder"
        return @()
    }

    $foundProjects = @{}
    $csprojFiles = Get-ChildItem -Path $Folder -Filter "*.csproj" -Recurse -File |
                   Where-Object {
                       $_.FullName -notmatch '\\obj\\' -and
                       $_.FullName -notmatch '\\bin\\' -and
                       ($script:IncludeTestProjects -or $_.Name -notmatch 'Test')
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
    Write-StyledOutput "📋 Mode: explicit project list ($($Projects.Count) item(s))"
    foreach ($proj in $Projects) {
        if (Test-Path $proj) {
            $projectName = Split-Path -Leaf $proj
            $projectPaths[$projectName] = $proj
        } else {
            Write-StyledOutput "⚠ Project not found: $proj"
        }
    }
}
elseif ($ProjectPath -ne "") {
    if (Test-Path $ProjectPath) {
        if (Test-Path "$ProjectPath\*.csproj") {
            Write-StyledOutput "📁 Mode: single project"
            $projectName = Split-Path -Leaf $ProjectPath
            $projectPaths[$projectName] = $ProjectPath
        }
        elseif ((Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0) {
            Write-StyledOutput "📂 Mode: project folder"
            $projectPaths = Get-ProjectsFromFolder -Folder $ProjectPath
        }
        else {
            Write-StyledOutput "⚠ No project found at: $ProjectPath"
            exit 1
        }
    } else {
        Write-StyledOutput "⚠ Path not found: $ProjectPath"
        exit 1
    }
}
else {
    Write-StyledOutput "🔍 Mode: automatic discovery under '$SourceFolder'"
    $projectPaths = Get-ProjectsFromFolder -Folder $SourceFolder

    if ($projectPaths.Count -eq 0) {
        Write-StyledOutput "⚠ Nenhum projeto encontrado na pasta '$SourceFolder'"
        Write-StyledOutput "💡 Dica: Use -ProjectPath para especificar um caminho ou -Projects para uma lista"
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
        Write-StyledOutput "  ✗ ERROR analyzing: $fileName - $($_.Exception.Message)"
        $stats.Skipped++
        return $null
    }
}

# Execution banner
Write-StyledOutput "`n╔════════════════════════════════════════════════════════════╗"
Write-StyledOutput "║  XML Documentation Validation - C# Projects                ║"
Write-StyledOutput "╚════════════════════════════════════════════════════════════╝`n"

if ($projectPaths.Count -eq 0) {
    Write-StyledOutput "❌ No projects to validate.`n"
    Write-StyledOutput "💡 Usage examples:"
    Write-StyledOutput "   .\validate-xml-documentation.ps1                              # Validate everything under src\"
    Write-StyledOutput "   .\validate-xml-documentation.ps1 -ExportMissing              # Export to JSON"
    Write-StyledOutput "   .\validate-xml-documentation.ps1 -ProjectPath src\MyProject  # Single project"
    exit 1
}

Write-StyledOutput "📦 Projects to validate: $($projectPaths.Count)"
foreach ($p in $projectPaths.GetEnumerator() | Sort-Object Key) {
    Write-StyledOutput "   • $($p.Key)"
}
Write-StyledOutput ""

foreach ($project in $projectPaths.GetEnumerator() | Sort-Object Name) {
    $projectName = $project.Key
    $projectPath = $project.Value

    if (-not (Test-Path $projectPath)) {
        Write-StyledOutput "⚠ Project not found: $projectPath`n"
        continue
    }

    Write-StyledOutput "═══ $projectName ═══"

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

    Write-StyledOutput "Files processed: $projectTotal"

    $projectMissing = 0
    foreach ($file in $files) {
        $result = Test-FileDocumentation -FilePath $file.FullName -ProjectName $projectName
        if ($null -ne $result) {
            $missingFiles += $result
            $projectMissing++
        }
    }

    if ($projectMissing -gt 0) {
        Write-StyledOutput "❌ Files missing documentation: $projectMissing"
    } else {
        Write-StyledOutput "✅ All files documented!"
    }

    Write-StyledOutput ""
}

# Final report
Write-StyledOutput "`n╔════════════════════════════════════════════════════════════╗"
Write-StyledOutput "║  VALIDATION REPORT                                          ║"
Write-StyledOutput "╚════════════════════════════════════════════════════════════╝`n"

Write-StyledOutput "Total files analyzed:        $($stats.TotalFiles)"
Write-StyledOutput "✅ With documentation:        $($stats.Documented)"
Write-StyledOutput "❌ Missing documentation:     $($stats.Missing)"
Write-StyledOutput "⚠️  Skipped / no type found:  $($stats.Skipped)"

$coverage = if ($stats.TotalFiles -gt 0) {
    [math]::Round(($stats.Documented / ($stats.TotalFiles - $stats.Skipped)) * 100, 2)
} else { 0 }

Write-StyledOutput "`nDocumentation coverage: $coverage% ($($stats.Documented)/$($stats.TotalFiles - $stats.Skipped))"
    if ($coverage -eq 100) { "Green" }
    elseif ($coverage -ge 80) { "Cyan" }
    elseif ($coverage -ge 50) { "Yellow" }
    else { "Red" }
)

# List files missing documentation
if ($missingFiles.Count -gt 0) {
    Write-StyledOutput "`n╔════════════════════════════════════════════════════════════╗"
    Write-StyledOutput "║  FILES MISSING DOCUMENTATION                                ║"
    Write-StyledOutput "╚════════════════════════════════════════════════════════════╝`n"

    if ($GroupByProject) {
        $grouped = $missingFiles | Group-Object -Property Project | Sort-Object Name
        foreach ($group in $grouped) {
            Write-StyledOutput "📁 $($group.Name) ($($group.Count) file(s)):"
            foreach ($file in $group.Group | Sort-Object File) {
                Write-StyledOutput "   ❌ $($file.File) ($($file.TypeKind) $($file.TypeName))"
                Write-StyledOutput "      $($file.Path)"
            }
            Write-StyledOutput ""
        }
    } else {
        foreach ($file in $missingFiles | Sort-Object Project, File) {
            Write-StyledOutput "❌ [$($file.Project)] $($file.File)"
            Write-StyledOutput "   Type: $($file.TypeKind) | Name: $($file.TypeName)"
            Write-StyledOutput "   Path: $($file.Path)"
            if ($file.Namespace) {
                Write-StyledOutput "   Namespace: $($file.Namespace)"
            }
            Write-StyledOutput ""
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

    Write-StyledOutput "╔════════════════════════════════════════════════════════════╗"
    Write-StyledOutput "║  EXPORT COMPLETE                                            ║"
    Write-StyledOutput "╚════════════════════════════════════════════════════════════╝`n"
    Write-StyledOutput "📄 Exported file: $OutputPath"
    Write-StyledOutput "📊 Items without documentation: $($missingFiles.Count)"
    Write-StyledOutput "`n💡 Use this file with AI-assisted tooling to generate summaries in context."
}
elseif ($ExportMissing -and $missingFiles.Count -eq 0) {
    Write-StyledOutput "`n✅ Nothing to export – all files already contain documentation!"
}

# Exit status
if ($stats.Missing -gt 0) {
    Write-StyledOutput "`n⚠️  Validation found $($stats.Missing) file(s) without documentation."
    exit 1
} else {
    Write-StyledOutput "`n✅ Validation complete – all files contain documentation!"
    exit 0
}