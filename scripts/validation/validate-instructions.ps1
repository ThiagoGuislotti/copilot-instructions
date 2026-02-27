<#
.SYNOPSIS
    Validates routing and documentation assets used by shared Copilot/Codex instructions.

.DESCRIPTION
    Performs static validation for repository instruction assets:
    - Required files existence
    - instruction-routing.catalog.yml path entries
    - JSON parsing for schema/manifest/snippets
    - Markdown link integrity for core docs and instruction folders
    - Skill contract lint for .codex/skills/*

    Returns exit code 1 when failures are found, otherwise 0.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script auto-detects a root containing .github and .codex.

.PARAMETER Verbose
    Prints detailed diagnostics during validation.

.EXAMPLE
    pwsh -File scripts/validation/validate-instructions.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-instructions.ps1 -Verbose

.NOTES
    Version: 1.4
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
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

# -------------------------------
# Helpers
# -------------------------------
# Writes verbose diagnostics with a logical color label.
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE:{0}] {1}" -f $Color, $Message)
    }
}

# Resolves repository root from input and fallback location candidates.
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
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $i++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Registers a validation failure and prints a standardized failure message.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning and prints a standardized warning message.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
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

# Determines whether a markdown link target should be validated.
function Test-IsLinkTargetValidatable {
    param(
        [string] $Target
    )

    $value = $Target.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    if ($value.StartsWith('#')) { return $false }
    if ($value -match '^(https?|mailto|ftp):') { return $false }
    if ($value -match '^\[[A-Z0-9_\- ]+\]$') { return $false }
    if ($value -match '\$\{.+\}') { return $false }

    if ($value.StartsWith('./') -or $value.StartsWith('../') -or $value.StartsWith('/')) { return $true }
    if ($value -match '[/\\]') { return $true }
    if ($value -match '\.[A-Za-z0-9]{1,10}([#?].*)?$') { return $true }
    if ($value -match '^(\.github|\.codex|prompts|chatmodes|schemas|scripts|src|templates)/') { return $true }

    return $false
}

# Resolves markdown link targets to repository or absolute filesystem paths.
function Resolve-MarkdownTarget {
    param(
        [string] $SourceFilePath,
        [string] $Target,
        [string] $Root
    )

    $pathPart = $Target.Split('#')[0].Split('?')[0].Trim()
    if ([string]::IsNullOrWhiteSpace($pathPart)) {
        return $null
    }

    if ($pathPart.StartsWith('/')) {
        $relative = $pathPart.TrimStart('/', '\')
        return [System.IO.Path]::GetFullPath((Join-Path $Root $relative))
    }

    if ([System.IO.Path]::IsPathRooted($pathPart)) {
        return [System.IO.Path]::GetFullPath($pathPart)
    }

    $sourceDir = Split-Path -Parent $SourceFilePath
    return [System.IO.Path]::GetFullPath((Join-Path $sourceDir $pathPart))
}

# Extracts markdown link targets from document content.
function Get-MarkdownLinkTarget {
    param(
        [string] $Path
    )

    $content = Get-Content -Raw -LiteralPath $Path
    $regexMatches = [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')
    $targets = New-Object System.Collections.Generic.List[string]

    foreach ($match in $regexMatches) {
        $raw = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }

        if ($raw.StartsWith('<') -and $raw.EndsWith('>')) {
            $raw = $raw.TrimStart('<').TrimEnd('>')
        }

        $titleMatch = [regex]::Match($raw, '^(?<path>\S+)\s+(?:"[^"]*"|''[^'']*'')$')
        if ($titleMatch.Success) {
            $raw = $titleMatch.Groups['path'].Value
        }

        $targets.Add($raw) | Out-Null
    }

    return $targets
}

# Validates that a JSON file exists and can be parsed successfully.
function Test-JsonFile {
    param(
        [string] $Root,
        [string] $Path
    )

    $absolute = Resolve-RepoPath -Root $Root -Path $Path
    if (-not (Test-Path -LiteralPath $absolute)) {
        Add-ValidationFailure "Missing JSON file: $Path"
        return $null
    }

    try {
        $json = Get-Content -Raw -LiteralPath $absolute | ConvertFrom-Json -Depth 100
        Write-StyledOutput ("[OK] JSON parse: {0}" -f $Path)
        return $json
    }
    catch {
        Add-ValidationFailure ("Invalid JSON in {0} :: {1}" -f $Path, $_.Exception.Message)
        return $null
    }
}

# Recursively extracts string values from nested objects and arrays.
function Get-StringValuesFromObject {
    param(
        [object] $InputObject,
        [System.Collections.Generic.List[string]] $Collector
    )

    if ($null -eq $InputObject) {
        return
    }

    if ($InputObject -is [string]) {
        $Collector.Add($InputObject) | Out-Null
        return
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            Get-StringValuesFromObject -InputObject $InputObject[$key] -Collector $Collector
        }
        return
    }

    if (($InputObject -is [System.Collections.IEnumerable]) -and (-not ($InputObject -is [string]))) {
        foreach ($item in $InputObject) {
            Get-StringValuesFromObject -InputObject $item -Collector $Collector
        }
        return
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        Get-StringValuesFromObject -InputObject $property.Value -Collector $Collector
    }
}

# Builds candidate snippet file paths from configuration references.
function Get-SnippetPathCandidate {
    param(
        [string] $Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $pathMatches = [regex]::Matches($Text, '(?<path>\.(?:github|codex|vscode)/[A-Za-z0-9._\-/]+)')
    $paths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($match in $pathMatches) {
        $path = $match.Groups['path'].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $paths.Add($path) | Out-Null
        }
    }

    return @($paths)
}

# Validates snippet file references used by editor configuration files.
function Test-SnippetReference {
    param(
        [string] $Root,
        [hashtable] $SnippetFiles
    )

    foreach ($relativePath in ($SnippetFiles.Keys | Sort-Object)) {
        $snippetObject = $SnippetFiles[$relativePath]
        if ($null -eq $snippetObject) {
            continue
        }

        $stringValues = New-Object System.Collections.Generic.List[string]
        Get-StringValuesFromObject -InputObject $snippetObject -Collector $stringValues

        $pathsInFile = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($value in $stringValues) {
            foreach ($candidate in (Get-SnippetPathCandidate -Text $value)) {
                $pathsInFile.Add($candidate) | Out-Null
            }
        }

        foreach ($candidatePath in ($pathsInFile | Sort-Object)) {
            $resolved = Resolve-RepoPath -Root $Root -Path $candidatePath
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-ValidationFailure ("Broken snippet path in {0} -> {1}" -f $relativePath, $candidatePath)
            }
        }
    }
}

# Converts user-profile absolute paths into repository-relative paths when possible.
function Convert-UserProfileReferenceToRepoPath {
    param(
        [string] $Root,
        [string] $Reference
    )

    if ([string]::IsNullOrWhiteSpace($Reference)) {
        return $null
    }

    $normalized = $Reference.Replace('/', '\')
    $githubPrefix = '%USERPROFILE%\.github\'
    $codexPrefix = '%USERPROFILE%\.codex\'

    if ($normalized.StartsWith($githubPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rest = $normalized.Substring($githubPrefix.Length)
        $relative = if ([string]::IsNullOrWhiteSpace($rest)) { '.github' } else { ".github\$rest" }
        return Resolve-RepoPath -Root $Root -Path $relative
    }

    if ($normalized.StartsWith($codexPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rest = $normalized.Substring($codexPrefix.Length)
        $relative = if ([string]::IsNullOrWhiteSpace($rest)) { '.codex' } else { ".codex\$rest" }
        return Resolve-RepoPath -Root $Root -Path $relative
    }

    return $null
}

# Validates file references declared in VS Code settings content.
function Test-VscodeSettingsReference {
    param(
        [string] $Root,
        [object] $Settings
    )

    if ($null -eq $Settings) {
        return
    }

    $locationsProperty = $Settings.PSObject.Properties['chat.instructionsFilesLocations']
    if ($null -ne $locationsProperty -and $null -ne $locationsProperty.Value) {
        foreach ($location in $locationsProperty.Value.PSObject.Properties) {
            if ($location.Value -ne $true) {
                continue
            }

            $resolved = Convert-UserProfileReferenceToRepoPath -Root $Root -Reference ([string]$location.Name)
            if ($null -eq $resolved) {
                continue
            }

            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-ValidationFailure ("VS Code instruction location not found: {0}" -f $location.Name)
            }
        }
    }

    $instructionProperties = @(
        'github.copilot.chat.reviewSelection.instructions',
        'github.copilot.chat.commitMessageGeneration.instructions',
        'github.copilot.chat.pullRequestDescriptionGeneration.instructions'
    )

    foreach ($propertyName in $instructionProperties) {
        $property = $Settings.PSObject.Properties[$propertyName]
        if ($null -eq $property -or $null -eq $property.Value) {
            continue
        }

        foreach ($entry in @($property.Value)) {
            if ($null -eq $entry) {
                continue
            }

            $fileReference = $null
            if ($entry -is [string]) {
                $fileReference = [string] $entry
            }
            else {
                $fileProperty = $entry.PSObject.Properties['file']
                if ($null -ne $fileProperty) {
                    $fileReference = [string] $fileProperty.Value
                }
            }

            if ([string]::IsNullOrWhiteSpace($fileReference)) {
                continue
            }

            $resolved = Convert-UserProfileReferenceToRepoPath -Root $Root -Reference $fileReference
            if ($null -eq $resolved) {
                continue
            }

            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-ValidationFailure ("VS Code instruction file not found: {0} ({1})" -f $fileReference, $propertyName)
            }
        }
    }
}

# Verifies required governance and instruction files exist in the repository.
function Test-RequiredFile {
    param(
        [string] $Root,
        [string[]] $RequiredFiles
    )

    foreach ($required in $RequiredFiles) {
        $absolute = Resolve-RepoPath -Root $Root -Path $required
        if (-not (Test-Path -LiteralPath $absolute)) {
            Add-ValidationFailure "Required file not found: $required"
            continue
        }

        Write-StyledOutput ("[OK] Required file: {0}" -f $required)
    }
}

# Validates that catalog-referenced files and directories exist.
function Test-CatalogPath {
    param(
        [string] $Root,
        [string] $CatalogRelativePath
    )

    $catalogPath = Resolve-RepoPath -Root $Root -Path $CatalogRelativePath
    if (-not (Test-Path -LiteralPath $catalogPath)) {
        return
    }

    $catalogLines = Get-Content -LiteralPath $catalogPath
    $catalogPaths = New-Object System.Collections.Generic.List[string]

    foreach ($line in $catalogLines) {
        $pathMatch = [regex]::Match($line, '^\s*-\s*path:\s*(?<value>.+?)\s*$')
        if (-not $pathMatch.Success) {
            $pathMatch = [regex]::Match($line, '^\s*path:\s*(?<value>.+?)\s*$')
        }

        if (-not $pathMatch.Success) {
            continue
        }

        $pathValue = $pathMatch.Groups['value'].Value.Trim().Trim("'").Trim('"')
        if (-not [string]::IsNullOrWhiteSpace($pathValue)) {
            $catalogPaths.Add($pathValue) | Out-Null
        }
    }

    if ($catalogPaths.Count -eq 0) {
        Add-ValidationFailure 'No path entries found in instruction-routing.catalog.yml'
        return
    }

    $catalogDir = Split-Path -Parent $catalogPath
    foreach ($entry in ($catalogPaths | Select-Object -Unique)) {
        $absolute = $null
        if ([System.IO.Path]::IsPathRooted($entry)) {
            $absolute = [System.IO.Path]::GetFullPath($entry)
        }
        else {
            $absolute = [System.IO.Path]::GetFullPath((Join-Path $catalogDir $entry))
        }

        if (-not (Test-Path -LiteralPath $absolute)) {
            Add-ValidationFailure ("Catalog path not found: {0}" -f $entry)
        }
    }

    Write-StyledOutput ("[OK] Catalog paths checked: {0}" -f $catalogPaths.Count)
}

# Collects markdown files that must be checked by validators.
function Get-MarkdownFilesForValidation {
    param(
        [string] $Root
    )

    $markdownFiles = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    $explicitMarkdown = @(
        'README.md',
        'scripts/README.md',
        '.github/AGENTS.md',
        '.github/copilot-instructions.md',
        '.codex/README.md',
        '.codex/mcp/README.md',
        '.codex/scripts/README.md',
        '.codex/orchestration/README.md',
        '.codex/skills/README.md'
    )

    foreach ($relative in $explicitMarkdown) {
        $absolute = Resolve-RepoPath -Root $Root -Path $relative
        if (Test-Path -LiteralPath $absolute) {
            $markdownFiles.Add($absolute) | Out-Null
        }
        else {
            Add-ValidationWarning "Skipping missing markdown file in set: $relative"
        }
    }

    $markdownFolders = @(
        '.github/instructions',
        '.github/chatmodes',
        '.github/prompts',
        '.github/runbooks'
    )

    foreach ($folder in $markdownFolders) {
        $absoluteFolder = Resolve-RepoPath -Root $Root -Path $folder
        if (-not (Test-Path -LiteralPath $absoluteFolder)) {
            Add-ValidationWarning "Skipping missing markdown folder: $folder"
            continue
        }

        Get-ChildItem -LiteralPath $absoluteFolder -Recurse -File -Filter '*.md' | ForEach-Object {
            $markdownFiles.Add($_.FullName) | Out-Null
        }
    }

    return $markdownFiles
}

# Validates markdown links and reports missing or invalid targets.
function Test-MarkdownLink {
    param(
        [string] $Root,
        [System.Collections.Generic.HashSet[string]] $MarkdownFiles
    )

    $checkedLinks = 0

    foreach ($file in ($MarkdownFiles | Sort-Object)) {
        foreach ($target in (Get-MarkdownLinkTarget -Path $file)) {
            if (-not (Test-IsLinkTargetValidatable -Target $target)) {
                continue
            }

            $checkedLinks++
            $resolved = Resolve-MarkdownTarget -SourceFilePath $file -Target $target -Root $Root
            if ($null -eq $resolved -or -not (Test-Path -LiteralPath $resolved)) {
                $relativeFile = [System.IO.Path]::GetRelativePath($Root, $file)
                Add-ValidationFailure ("Broken markdown link in {0} -> {1}" -f $relativeFile, $target)
            }
        }
    }

    return $checkedLinks
}

# Parses frontmatter metadata from skill markdown files.
function Get-SkillFrontmatter {
    param(
        [string] $SkillFilePath
    )

    $lines = Get-Content -LiteralPath $SkillFilePath
    if ($lines.Count -lt 3) {
        return $null
    }

    if ($lines[0].Trim() -ne '---') {
        return $null
    }

    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $endIndex = $i
            break
        }
    }

    if ($endIndex -lt 1) {
        return $null
    }

    $yamlText = ($lines[1..($endIndex - 1)] -join "`n")
    return [pscustomobject]@{
        YamlText = $yamlText
        TotalLines = $lines.Count
    }
}

# Converts frontmatter text into a normalized key-value map.
function Convert-FrontmatterToMap {
    param(
        [string] $YamlText
    )

    $map = @{}
    $yamlLines = $YamlText -split "`r?`n"

    foreach ($line in $yamlLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('#')) {
            continue
        }

        $match = [regex]::Match($line, '^\s*(?<key>[A-Za-z0-9_-]+)\s*:\s*(?<value>.*)\s*$')
        if (-not $match.Success) {
            continue
        }

        $key = $match.Groups['key'].Value
        $value = $match.Groups['value'].Value.Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $map[$key] = $value
    }

    return $map
}

# Discovers SKILL.md files under configured skill root directories.
function Get-SkillMarkdownFile {
    param(
        [string] $Root
    )

    $skillsRoot = Resolve-RepoPath -Root $Root -Path '.codex/skills'
    if (-not (Test-Path -LiteralPath $skillsRoot)) {
        return @()
    }

    return Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter 'SKILL.md' | Select-Object -ExpandProperty FullName
}

# Normalizes path lists into a hash set for efficient lookup.
function Convert-PathListToHashSet {
    param(
        [string[]] $Paths
    )

    $set = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $Paths) {
        $set.Add($path) | Out-Null
    }
    return $set
}

# Validates skill declarations against discovered skill markdown files.
function Test-SkillDefinition {
    param(
        [string] $Root
    )

    $stats = [pscustomobject]@{
        SkillsChecked = 0
        SkillFilesChecked = 0
        OpenAiFilesChecked = 0
        SkillLinkChecks = 0
    }

    $skillsRoot = Resolve-RepoPath -Root $Root -Path '.codex/skills'
    if (-not (Test-Path -LiteralPath $skillsRoot)) {
        Add-ValidationWarning 'Skipping skill lint: .codex/skills not found.'
        return $stats
    }

    $skillDirs = Get-ChildItem -LiteralPath $skillsRoot -Directory | Where-Object { -not $_.Name.StartsWith('.') }

    foreach ($dir in $skillDirs) {
        $stats.SkillsChecked++

        $skillFile = Join-Path $dir.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillFile)) {
            Add-ValidationFailure ("Skill missing SKILL.md: .codex/skills/{0}" -f $dir.Name)
            continue
        }

        $stats.SkillFilesChecked++
        $frontmatter = Get-SkillFrontmatter -SkillFilePath $skillFile
        if ($null -eq $frontmatter) {
            Add-ValidationFailure ("Invalid or missing frontmatter in skill: .codex/skills/{0}/SKILL.md" -f $dir.Name)
            continue
        }

        $frontmatterMap = Convert-FrontmatterToMap -YamlText $frontmatter.YamlText
        $requiredKeys = @('name', 'description')
        foreach ($requiredKey in $requiredKeys) {
            if (-not $frontmatterMap.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($frontmatterMap[$requiredKey])) {
                Add-ValidationFailure ("Skill frontmatter missing '{0}': .codex/skills/{1}/SKILL.md" -f $requiredKey, $dir.Name)
            }
        }

        if ($frontmatterMap.ContainsKey('name')) {
            $skillName = $frontmatterMap['name']
            if ($skillName -notmatch '^[a-z0-9-]{1,64}$') {
                Add-ValidationFailure ("Skill name must match ^[a-z0-9-]{{1,64}}`$: .codex/skills/{0}/SKILL.md" -f $dir.Name)
            }
            elseif ($skillName -ne $dir.Name) {
                Add-ValidationFailure ("Skill folder/name mismatch: folder='{0}' frontmatter.name='{1}'" -f $dir.Name, $skillName)
            }
        }

        $extraKeys = @($frontmatterMap.Keys | Where-Object { $_ -notin @('name', 'description') })
        if ($extraKeys.Count -gt 0) {
            Add-ValidationWarning ("Skill frontmatter has non-standard keys ({0}): .codex/skills/{1}/SKILL.md" -f ($extraKeys -join ', '), $dir.Name)
        }

        if ($frontmatter.TotalLines -gt 500) {
            Add-ValidationFailure ("Skill exceeds 500 lines: .codex/skills/{0}/SKILL.md ({1} lines)" -f $dir.Name, $frontmatter.TotalLines)
        }

        $openAiFile = Join-Path $dir.FullName 'agents\openai.yaml'
        if (-not (Test-Path -LiteralPath $openAiFile)) {
            Add-ValidationFailure ("Skill missing agents/openai.yaml: .codex/skills/{0}" -f $dir.Name)
            continue
        }

        $stats.OpenAiFilesChecked++
        $openAiContent = Get-Content -Raw -LiteralPath $openAiFile
        foreach ($requiredPattern in @('display_name:', 'short_description:', 'default_prompt:')) {
            if ($openAiContent -notmatch [regex]::Escape($requiredPattern)) {
                Add-ValidationFailure ("openai.yaml missing '{0}': .codex/skills/{1}/agents/openai.yaml" -f $requiredPattern.TrimEnd(':'), $dir.Name)
            }
        }

        if ($openAiContent -notmatch [regex]::Escape('$' + $dir.Name)) {
            $expectedSkillToken = '$' + $dir.Name
            Add-ValidationWarning ("openai.yaml default_prompt should reference {0}: .codex/skills/{1}/agents/openai.yaml" -f $expectedSkillToken, $dir.Name)
        }
    }

    $skillMarkdownFiles = Get-SkillMarkdownFile -Root $Root
    $skillMarkdownSet = Convert-PathListToHashSet -Paths $skillMarkdownFiles
    $stats.SkillLinkChecks = Test-MarkdownLink -Root $Root -MarkdownFiles $skillMarkdownSet

    return $stats
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$requiredFiles = @(
    '.github/AGENTS.md',
    '.github/copilot-instructions.md',
    '.github/instruction-routing.catalog.yml',
    '.github/prompts/route-instructions.prompt.md',
    '.github/schemas/instruction-routing.catalog.schema.json',
    '.github/governance/readme-standards.baseline.json',
    '.github/governance/architecture-boundaries.baseline.json',
    '.github/governance/security-baseline.json',
    '.github/governance/release-provenance.baseline.json',
    '.github/governance/validation-profiles.json',
    '.github/governance/agent-skill-permissions.matrix.json',
    '.github/governance/supply-chain.baseline.json',
    '.github/governance/warning-baseline.json',
    '.github/runbooks/README.md',
    '.github/runbooks/validation-failures.runbook.md',
    '.github/runbooks/runtime-drift.runbook.md',
    '.github/runbooks/release-rollback.runbook.md',
    '.github/schemas/agent.contract.schema.json',
    '.github/schemas/agent.pipeline.schema.json',
    '.github/schemas/agent.handoff.schema.json',
    '.github/schemas/agent.run-artifact.schema.json',
    '.github/schemas/agent.evals.schema.json',
    '.codex/orchestration/agents.manifest.json',
    '.codex/orchestration/pipelines/default.pipeline.json',
    '.codex/orchestration/templates/handoff.template.json',
    '.codex/orchestration/templates/run-artifact.template.json',
    '.codex/orchestration/evals/golden-tests.json',
    'scripts/validation/validate-agent-orchestration.ps1',
    'scripts/validation/validate-readme-standards.ps1',
    'scripts/validation/validate-powershell-standards.ps1',
    'scripts/validation/validate-dotnet-standards.ps1',
    'scripts/validation/validate-architecture-boundaries.ps1',
    'scripts/validation/validate-instruction-metadata.ps1',
    'scripts/validation/validate-routing-coverage.ps1',
    'scripts/validation/validate-agent-skill-alignment.ps1',
    'scripts/validation/validate-agent-permissions.ps1',
    'scripts/validation/validate-security-baseline.ps1',
    'scripts/validation/validate-warning-baseline.ps1',
    'scripts/validation/validate-supply-chain.ps1',
    'scripts/validation/validate-audit-ledger.ps1',
    'scripts/validation/validate-release-provenance.ps1',
    'scripts/validation/validate-all.ps1',
    'scripts/runtime/run-agent-pipeline.ps1',
    'scripts/runtime/clean-codex-runtime.ps1',
    'scripts/orchestration/stages/plan-stage.ps1',
    'scripts/orchestration/stages/implement-stage.ps1',
    'scripts/orchestration/stages/validate-stage.ps1',
    'scripts/orchestration/stages/review-stage.ps1'
)

Test-RequiredFile -Root $resolvedRepoRoot -RequiredFiles $requiredFiles
Test-CatalogPath -Root $resolvedRepoRoot -CatalogRelativePath '.github/instruction-routing.catalog.yml'

$schema = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/schemas/instruction-routing.catalog.schema.json'
if ($null -ne $schema) {
    foreach ($property in @('$schema', 'title', 'type', 'properties')) {
        if ($null -eq $schema.$property) {
            Add-ValidationFailure ("Schema missing expected property: {0}" -f $property)
        }
    }
}

$manifest = Test-JsonFile -Root $resolvedRepoRoot -Path '.codex/mcp/servers.manifest.json'
if ($null -ne $manifest) {
    if ($null -eq $manifest.servers -or @($manifest.servers).Count -eq 0) {
        Add-ValidationFailure 'MCP manifest must contain at least one server.'
    }
}

$codexCliSnippets = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/snippets/codex-cli.code-snippets'
$copilotSnippets = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/snippets/copilot.code-snippets'
$vscodeSettings = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/settings.tamplate.jsonc'
$vscodeMcp = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/mcp.tamplate.jsonc'

$orchestrationJsonFiles = @(
    '.github/schemas/agent.contract.schema.json',
    '.github/schemas/agent.pipeline.schema.json',
    '.github/schemas/agent.handoff.schema.json',
    '.github/schemas/agent.run-artifact.schema.json',
    '.github/schemas/agent.evals.schema.json',
    '.codex/orchestration/agents.manifest.json',
    '.codex/orchestration/pipelines/default.pipeline.json',
    '.codex/orchestration/templates/handoff.template.json',
    '.codex/orchestration/templates/run-artifact.template.json',
    '.codex/orchestration/evals/golden-tests.json'
)

foreach ($jsonPath in $orchestrationJsonFiles) {
    Test-JsonFile -Root $resolvedRepoRoot -Path $jsonPath | Out-Null
}

if ($null -ne $vscodeMcp) {
    if ($null -eq $vscodeMcp.servers -or @($vscodeMcp.servers.PSObject.Properties).Count -eq 0) {
        Add-ValidationFailure 'VS Code MCP template must contain at least one server.'
    }
}

Test-VscodeSettingsReference -Root $resolvedRepoRoot -Settings $vscodeSettings
Test-SnippetReference -Root $resolvedRepoRoot -SnippetFiles @{
    '.vscode/snippets/codex-cli.code-snippets' = $codexCliSnippets
    '.vscode/snippets/copilot.code-snippets' = $copilotSnippets
}

$skillStats = Test-SkillDefinition -Root $resolvedRepoRoot
$markdownFiles = Get-MarkdownFilesForValidation -Root $resolvedRepoRoot
$checkedLinks = Test-MarkdownLink -Root $resolvedRepoRoot -MarkdownFiles $markdownFiles

$routingGoldenStatus = 'not-run'
$routingGoldenScript = Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/validation/test-routing-selection.ps1'
if (Test-Path -LiteralPath $routingGoldenScript) {
    & $routingGoldenScript -RepoRoot $resolvedRepoRoot
    if ($LASTEXITCODE -eq 0) {
        $routingGoldenStatus = 'passed'
    }
    else {
        $routingGoldenStatus = 'failed'
        Add-ValidationFailure 'Routing golden tests failed (scripts/validation/test-routing-selection.ps1).'
    }
}
else {
    $routingGoldenStatus = 'missing-script'
    Add-ValidationWarning 'Routing golden test script not found: scripts/validation/test-routing-selection.ps1'
}

Write-StyledOutput ''
Write-StyledOutput 'Validation summary'
Write-StyledOutput ("  Skills checked: {0}" -f $skillStats.SkillsChecked)
Write-StyledOutput ("  Skill files checked: {0}" -f $skillStats.SkillFilesChecked)
Write-StyledOutput ("  Skill openai.yaml checked: {0}" -f $skillStats.OpenAiFilesChecked)
Write-StyledOutput ("  Skill links checked: {0}" -f $skillStats.SkillLinkChecks)
Write-StyledOutput ("  Routing golden tests: {0}" -f $routingGoldenStatus)
Write-StyledOutput ("  Markdown files checked: {0}" -f $markdownFiles.Count)
Write-StyledOutput ("  Markdown links checked: {0}" -f $checkedLinks)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0) {
    exit 1
}

Write-StyledOutput 'All instruction validations passed.'
exit 0