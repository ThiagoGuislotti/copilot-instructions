[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $failures.Add($Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Add-Warning {
    param([Parameter(Mandatory = $true)][string]$Message)
    $warnings.Add($Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Resolve-FromRepo {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Should-ValidateLinkTarget {
    param([Parameter(Mandatory = $true)][string]$Target)

    $value = $Target.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    if ($value.StartsWith("#")) { return $false }
    if ($value -match "^(https?|mailto|ftp):") { return $false }
    if ($value -match "^\[[A-Z0-9_\- ]+\]$") { return $false } # placeholders like [PARAM]
    if ($value -match "\$\{.+\}") { return $false } # snippets/placeholders

    # Practical heuristic: only validate targets that look like file paths.
    if ($value.StartsWith("./") -or $value.StartsWith("../") -or $value.StartsWith("/")) { return $true }
    if ($value -match "[/\\]") { return $true }
    if ($value -match "\.[A-Za-z0-9]{1,10}([#?].*)?$") { return $true }
    if ($value -match "^(\.github|\.codex|prompts|chatmodes|schemas|scripts|src|templates)/") { return $true }

    return $false
}

function Resolve-MarkdownTarget {
    param(
        [Parameter(Mandatory = $true)][string]$SourceFilePath,
        [Parameter(Mandatory = $true)][string]$Target
    )

    $pathPart = $Target.Split("#")[0].Split("?")[0].Trim()
    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return $null
    }

    if ($pathPart.StartsWith("/")) {
        $relative = $pathPart.TrimStart("/", "\")
        return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $relative))
    }

    if ([System.IO.Path]::IsPathRooted($pathPart)) {
        return [System.IO.Path]::GetFullPath($pathPart)
    }

    $sourceDir = Split-Path -Parent $SourceFilePath
    return [System.IO.Path]::GetFullPath((Join-Path $sourceDir $pathPart))
}

function Get-MarkdownTargets {
    param([Parameter(Mandatory = $true)][string]$Path)

    $content = Get-Content -Raw -Path $Path
    $matches = [regex]::Matches($content, "\[[^\]]+\]\(([^)]+)\)")
    $targets = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        $raw = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }

        if ($raw.StartsWith("<") -and $raw.EndsWith(">")) {
            $raw = $raw.TrimStart("<").TrimEnd(">")
        }

        # Remove optional markdown title: path "title"
        if ($raw -match '^(?<path>\S+)\s+(?:"[^"]*"|''[^'']*'')$') {
            $raw = $Matches["path"]
        }

        $targets.Add($raw)
    }

    return $targets
}

function Test-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $absolute = Resolve-FromRepo -Path $Path
    if (!(Test-Path $absolute)) {
        Add-Failure "Missing JSON file: $Path"
        return $null
    }

    try {
        $obj = Get-Content -Raw -Path $absolute | ConvertFrom-Json -Depth 100
        Write-Host "[OK] JSON parse: $Path" -ForegroundColor Green
        return $obj
    } catch {
        Add-Failure "Invalid JSON in $Path :: $($_.Exception.Message)"
        return $null
    }
}

if (!(Test-Path $RepoRoot)) {
    throw "Repo root not found: $RepoRoot"
}

$requiredFiles = @(
    ".github/AGENTS.md",
    ".github/copilot-instructions.md",
    "instruction-routing.catalog.yml",
    "prompts/route-instructions.prompt.md",
    "schemas/instruction-routing.catalog.schema.json"
)

foreach ($required in $requiredFiles) {
    $absolute = Resolve-FromRepo -Path $required
    if (!(Test-Path $absolute)) {
        Add-Failure "Required file not found: $required"
    } else {
        Write-Host "[OK] Required file: $required" -ForegroundColor Green
    }
}

$catalogPath = Resolve-FromRepo -Path "instruction-routing.catalog.yml"
if (Test-Path $catalogPath) {
    $catalogLines = Get-Content -Path $catalogPath
    $catalogPaths = New-Object System.Collections.Generic.List[string]
    foreach ($line in $catalogLines) {
        if ($line -match "^\s*-\s*path:\s*(?<value>.+?)\s*$" -or $line -match "^\s*path:\s*(?<value>.+?)\s*$") {
            $pathValue = $Matches["value"].Trim().Trim("'").Trim('"')
            if (![string]::IsNullOrWhiteSpace($pathValue)) {
                $catalogPaths.Add($pathValue)
            }
        }
    }

    if ($catalogPaths.Count -eq 0) {
        Add-Failure "No path entries found in instruction-routing.catalog.yml"
    } else {
        foreach ($entry in ($catalogPaths | Select-Object -Unique)) {
            $absolute = Resolve-FromRepo -Path $entry
            if (!(Test-Path $absolute)) {
                Add-Failure "Catalog path not found: $entry"
            }
        }
        Write-Host "[OK] Catalog paths checked: $($catalogPaths.Count)" -ForegroundColor Green
    }
}

$schema = Test-JsonFile -Path "schemas/instruction-routing.catalog.schema.json"
if ($null -ne $schema) {
    foreach ($prop in @("`$schema", "title", "type", "properties")) {
        if ($null -eq $schema.$prop) {
            Add-Failure "Schema missing expected property: $prop"
        }
    }
}

$manifest = Test-JsonFile -Path ".codex/mcp/servers.manifest.json"
if ($null -ne $manifest) {
    if ($null -eq $manifest.servers -or @($manifest.servers).Count -eq 0) {
        Add-Failure "MCP manifest must contain at least one server."
    }
}

[void](Test-JsonFile -Path ".vscode/snippets/codex-cli.code-snippets")
[void](Test-JsonFile -Path ".vscode/snippets/copilot.code-snippets")

$markdownFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

$explicitMarkdown = @(
    "README.md",
    "scripts/README.md",
    ".github/AGENTS.md",
    ".github/copilot-instructions.md",
    ".codex/README.md",
    ".codex/mcp/README.md",
    ".codex/scripts/README.md",
    ".codex/skills/README.md"
)

foreach ($relative in $explicitMarkdown) {
    $absolute = Resolve-FromRepo -Path $relative
    if (Test-Path $absolute) {
        [void]$markdownFiles.Add($absolute)
    } else {
        Add-Warning "Skipping missing markdown file in set: $relative"
    }
}

$markdownFolders = @(
    ".github/instructions",
    "chatmodes",
    "prompts",
    ".codex/skills"
)

foreach ($folder in $markdownFolders) {
    $absoluteFolder = Resolve-FromRepo -Path $folder
    if (!(Test-Path $absoluteFolder)) {
        Add-Warning "Skipping missing markdown folder: $folder"
        continue
    }

    Get-ChildItem -Path $absoluteFolder -Recurse -File -Filter "*.md" | ForEach-Object {
        [void]$markdownFiles.Add($_.FullName)
    }
}

$checkedLinks = 0
foreach ($file in ($markdownFiles | Sort-Object)) {
    foreach ($target in (Get-MarkdownTargets -Path $file)) {
        if (!(Should-ValidateLinkTarget -Target $target)) {
            continue
        }

        $checkedLinks++
        $resolved = Resolve-MarkdownTarget -SourceFilePath $file -Target $target
        if ($null -eq $resolved -or !(Test-Path $resolved)) {
            $relativeFile = [System.IO.Path]::GetRelativePath($RepoRoot, $file)
            Add-Failure "Broken markdown link in $relativeFile -> $target"
        }
    }
}

Write-Host ""
Write-Host "Validation summary" -ForegroundColor Cyan
Write-Host "  Markdown files checked: $($markdownFiles.Count)"
Write-Host "  Markdown links checked: $checkedLinks"
Write-Host "  Warnings: $($warnings.Count)"
Write-Host "  Failures: $($failures.Count)"

if ($failures.Count -gt 0) {
    exit 1
}

Write-Host "All instruction validations passed." -ForegroundColor Green
exit 0
