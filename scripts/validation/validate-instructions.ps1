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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging', 'mcp-runtime-catalog', 'local-context-index', 'provider-surface-catalog')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
Initialize-ValidationState -VerboseEnabled $script:IsVerboseEnabled

# -------------------------------
# Helpers
# -------------------------------

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
    if ($value -match '^(\.github|\.codex|prompts|chatmodes|schemas|scripts|src|tests|definitions|templates)/') { return $true }

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

# Converts one object graph into stable JSON for content comparison.
function ConvertTo-StableJson {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Value
    )

    return ($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n")
}

# Returns a deterministic relative-path -> SHA256 map for one directory tree.
function Get-StableDirectoryFileMap {
    param(
        [string] $RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }

    $result = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
        $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $file.FullName) -replace '\\', '/'
        $result[$relativePath] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    return $result
}

# Returns a deterministic relative-file-name -> SHA256 map for one flat directory.
function Get-StableFileMap {
    param(
        [string] $RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }

    $result = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $RootPath -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $result[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    return $result
}

# Returns a deterministic selected-file-name -> SHA256 map for one flat directory.
function Get-StableSelectedFileMap {
    param(
        [string] $RootPath,
        [string[]] $FileNames
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }

    $result = [ordered]@{}
    foreach ($fileName in @($FileNames | Sort-Object -Unique)) {
        $candidatePath = Join-Path $RootPath $fileName
        if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
            return $null
        }

        $result[$fileName] = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    return $result
}

# Converts JSON-like objects into a hashtable keyed by property name.
function ConvertTo-PropertyMap {
    param(
        [object] $Value
    )

    $result = @{}
    if ($null -eq $Value) {
        return $result
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $result[[string] $key] = $Value[$key]
        }

        return $result
    }

    foreach ($property in $Value.PSObject.Properties) {
        $result[[string] $property.Name] = $property.Value
    }

    return $result
}

# Gets a direct property value from a JSON-like object when present.
function Get-JsonPropertyValue {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($PropertyName)) {
            return $InputObject[$PropertyName]
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
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

# Converts runtime-home absolute paths into repository-relative paths when possible.
function Convert-UserProfileReferenceToRepoPath {
    param(
        [string] $Root,
        [string] $Reference
    )

    if ([string]::IsNullOrWhiteSpace($Reference)) {
        return $null
    }

    $normalized = $Reference.Replace('/', '\')
    $githubPrefixes = @(
        '%USERPROFILE%\.github\',
        '%USERPROFILE%\.github',
        '${env:USERPROFILE}\.github\',
        '${env:USERPROFILE}\.github',
        '${env:HOME}\.github\',
        '${env:HOME}\.github',
        '$HOME\.github\',
        '$HOME\.github',
        '~\.github\',
        '~\.github'
    )

    $codexPrefixes = @(
        '%USERPROFILE%\.codex\',
        '%USERPROFILE%\.codex',
        '${env:USERPROFILE}\.codex\',
        '${env:USERPROFILE}\.codex',
        '${env:HOME}\.codex\',
        '${env:HOME}\.codex',
        '$HOME\.codex\',
        '$HOME\.codex',
        '~\.codex\',
        '~\.codex'
    )

    foreach ($prefix in $githubPrefixes) {
        if (-not $normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $rest = $normalized.Substring($prefix.Length).TrimStart('\')
        $relative = if ([string]::IsNullOrWhiteSpace($rest)) { '.github' } else { ".github\$rest" }
        return Resolve-RepoPath -Root $Root -Path $relative
    }

    foreach ($prefix in $codexPrefixes) {
        if (-not $normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $rest = $normalized.Substring($prefix.Length).TrimStart('\')
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

# Validates that workspace-generation rules only diverge from the shared VS Code template in approved local throttles.
function Test-WorkspaceTemplateCompatibility {
    param(
        [object] $WorkspaceBaseline,
        [object] $VscodeSettings
    )

    if ($null -eq $WorkspaceBaseline -or $null -eq $VscodeSettings) {
        return
    }

    $requiredSettings = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'requiredSettings')
    $recommendedSettings = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'recommendedSettings')
    $recommendedBounds = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'recommendedNumericUpperBounds')
    $forbiddenSettings = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'forbiddenSettings')
    $allowedWorkspaceOverrides = @((Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'allowedWorkspaceOverrideSettings'))
    $templateFilesExclude = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName 'files.exclude')
    $templateWatcherExclude = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName 'files.watcherExclude')
    $templateSearchExclude = ConvertTo-PropertyMap -Value (Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName 'search.exclude')

    $requiredFilesExcludeKeys = @((Get-JsonPropertyValue -InputObject $requiredSettings['files.exclude'] -PropertyName 'requiredKeys'))
    foreach ($key in $requiredFilesExcludeKeys) {
        if (-not $templateFilesExclude.ContainsKey([string] $key) -or -not [bool] $templateFilesExclude[[string] $key]) {
            Add-ValidationFailure ("Workspace efficiency baseline requires files.exclude entry '{0}' but VS Code template does not provide it." -f $key)
        }
    }

    $requiredWatcherKeys = @((Get-JsonPropertyValue -InputObject $requiredSettings['files.watcherExclude'] -PropertyName 'requiredKeys'))
    foreach ($key in $requiredWatcherKeys) {
        if (-not $templateWatcherExclude.ContainsKey([string] $key) -or -not [bool] $templateWatcherExclude[[string] $key]) {
            Add-ValidationFailure ("Workspace efficiency baseline requires watcher exclude '{0}' but VS Code template does not provide it." -f $key)
        }
    }

    $requiredSearchKeys = @((Get-JsonPropertyValue -InputObject $requiredSettings['search.exclude'] -PropertyName 'requiredKeys'))
    foreach ($key in $requiredSearchKeys) {
        if (-not $templateSearchExclude.ContainsKey([string] $key) -or -not [bool] $templateSearchExclude[[string] $key]) {
            Add-ValidationFailure ("Workspace efficiency baseline requires search exclude '{0}' but VS Code template does not provide it." -f $key)
        }
    }

    foreach ($settingName in $requiredSettings.Keys) {
        if ($settingName -in @('files.exclude', 'files.watcherExclude', 'search.exclude')) {
            continue
        }

        if ($settingName -notin $allowedWorkspaceOverrides) {
            $templateValue = Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName $settingName
            if ($null -ne $templateValue -and ([string] $templateValue -ne [string] $requiredSettings[$settingName])) {
                Add-ValidationFailure ("Workspace baseline setting '{0}' diverges from VS Code template without approval." -f $settingName)
            }
        }
    }

    foreach ($settingName in $recommendedSettings.Keys) {
        if ($settingName -notin $allowedWorkspaceOverrides) {
            $templateValue = Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName $settingName
            if ($null -ne $templateValue -and ([string] $templateValue -ne [string] $recommendedSettings[$settingName])) {
                Add-ValidationFailure ("Workspace recommended setting '{0}' diverges from VS Code template without approval." -f $settingName)
            }
        }
    }

    foreach ($settingName in $recommendedBounds.Keys) {
        if ($settingName -in $allowedWorkspaceOverrides) {
            continue
        }

        $templateValue = Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName $settingName
        if ($null -eq $templateValue) {
            continue
        }

        $templateNumber = 0.0
        if (-not [double]::TryParse(([string] $templateValue), [ref] $templateNumber)) {
            Add-ValidationFailure ("VS Code template numeric setting '{0}' is not numeric." -f $settingName)
            continue
        }

        if ($templateNumber -gt [double] $recommendedBounds[$settingName]) {
            Add-ValidationFailure ("VS Code template numeric setting '{0}' exceeds the approved bound {1}." -f $settingName, $recommendedBounds[$settingName])
        }
    }

    foreach ($settingName in $forbiddenSettings.Keys) {
        $templateValue = Get-JsonPropertyValue -InputObject $VscodeSettings -PropertyName $settingName
        if ($null -eq $templateValue) {
            continue
        }

        foreach ($forbiddenValue in @($forbiddenSettings[$settingName])) {
            if ([string] $templateValue -eq [string] $forbiddenValue) {
                Add-ValidationFailure ("VS Code template setting '{0}' must not be '{1}'." -f $settingName, $forbiddenValue)
            }
        }
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
    '.github/instructions/authoritative-sources.instructions.md',
    '.github/instructions/brainstorm-spec-workflow.instructions.md',
    '.github/instructions/super-agent.instructions.md',
    '.github/instructions/worktree-isolation.instructions.md',
    '.github/instructions/tdd-verification.instructions.md',
    '.github/instructions/repository-operating-model.instructions.md',
    '.github/instructions/subagent-planning-workflow.instructions.md',
    '.github/prompts/route-instructions.prompt.md',
    '.github/schemas/instruction-routing.catalog.schema.json',
    '.github/governance/authoritative-source-map.json',
    '.github/governance/instruction-ownership.manifest.json',
    '.github/governance/readme-standards.baseline.json',
    '.github/governance/template-standards.baseline.json',
    '.github/governance/workspace-efficiency.baseline.json',
    '.github/governance/architecture-boundaries.baseline.json',
    '.github/governance/security-baseline.json',
    '.github/governance/release-provenance.baseline.json',
    '.github/governance/validation-profiles.json',
    '.github/governance/agent-skill-permissions.matrix.json',
    '.github/governance/supply-chain.baseline.json',
    '.github/governance/warning-baseline.json',
    '.github/governance/shared-script-checksums.manifest.json',
    '.github/governance/codex-runtime-hygiene.catalog.json',
    '.github/governance/vscode-runtime-hygiene.catalog.json',
    '.github/governance/mcp-runtime.catalog.json',
    '.github/governance/provider-surface-projection.catalog.json',
    '.github/governance/local-context-index.catalog.json',
    'definitions/README.md',
    'definitions/shared/README.md',
    'definitions/shared/prompts/README.md',
    'definitions/shared/prompts/poml/README.md',
    'definitions/providers/github/root/AGENTS.md',
    'definitions/providers/github/root/COMMANDS.md',
    'definitions/providers/github/root/copilot-instructions.md',
    'definitions/providers/github/root/instruction-routing.catalog.yml',
    'definitions/providers/github/agents/super-agent.agent.md',
    'definitions/providers/github/chatmodes/clean-architecture-review.chatmode.md',
    'definitions/shared/instructions/repository-operating-model.instructions.md',
    'definitions/shared/prompts/poml/prompt-engineering-poml.md',
    'definitions/shared/prompts/poml/templates/changelog-entry.poml',
    'definitions/providers/github/prompts/route-instructions.prompt.md',
    'definitions/providers/github/hooks/super-agent.bootstrap.json',
    'definitions/providers/github/hooks/super-agent.selector.json',
    'definitions/providers/github/hooks/scripts/common.ps1',
    'definitions/providers/github/hooks/scripts/session-start.ps1',
    'definitions/providers/github/hooks/scripts/subagent-start.ps1',
    'definitions/providers/github/hooks/scripts/pre-tool-use.ps1',
    'definitions/shared/templates/readme-template.md',
    'definitions/providers/vscode/workspace/README.md',
    'definitions/providers/vscode/workspace/base.code-workspace',
    'definitions/providers/vscode/workspace/settings.tamplate.jsonc',
    'definitions/providers/vscode/workspace/snippets/codex-cli.tamplate.code-snippets',
    'definitions/providers/codex/mcp/README.md',
    'definitions/providers/codex/mcp/codex.config.template.toml',
    'definitions/providers/codex/mcp/vscode.mcp.template.json',
    'definitions/providers/codex/scripts/README.md',
    'definitions/providers/codex/scripts/render-vscode-mcp.ps1',
    'definitions/providers/codex/scripts/sync-mcp-to-codex-config.ps1',
    'definitions/providers/codex/orchestration/agents.manifest.json',
    'definitions/providers/codex/orchestration/pipelines/default.pipeline.json',
    'definitions/providers/codex/orchestration/prompts/super-agent-intake-stage.prompt.md',
    'definitions/providers/codex/orchestration/templates/run-artifact.template.json',
    'definitions/providers/claude/runtime/settings.json',
    '.vscode/base.code-workspace',
    '.github/runbooks/README.md',
    '.github/runbooks/validation-failures.runbook.md',
    '.github/runbooks/runtime-drift.runbook.md',
    '.github/runbooks/release-rollback.runbook.md',
    '.github/schemas/agent.contract.schema.json',
    '.github/schemas/agent.pipeline.schema.json',
    '.github/schemas/agent.handoff.schema.json',
    '.github/schemas/agent.run-artifact.schema.json',
    '.github/schemas/agent.evals.schema.json',
    '.github/schemas/agent.trace-record.schema.json',
    '.github/schemas/agent.policy-evaluation.schema.json',
    '.github/schemas/agent.checkpoint-state.schema.json',
    '.github/schemas/mcp-runtime.catalog.schema.json',
    '.github/schemas/provider-surface-projection.catalog.schema.json',
    '.github/schemas/local-context-index.catalog.schema.json',
    '.github/schemas/agent.stage-intake-result.schema.json',
    '.github/schemas/agent.stage-spec-result.schema.json',
    '.github/schemas/agent.stage-plan-result.schema.json',
    '.github/schemas/agent.stage-route-result.schema.json',
    '.github/schemas/agent.stage-implementation-result.schema.json',
    '.github/schemas/agent.stage-review-result.schema.json',
    '.github/schemas/agent.stage-closeout-result.schema.json',
    '.github/schemas/agent.task-review-result.schema.json',
    '.codex/orchestration/agents.manifest.json',
    '.codex/orchestration/pipelines/default.pipeline.json',
    '.codex/orchestration/prompts/super-agent-intake-stage.prompt.md',
    '.codex/orchestration/prompts/spec-stage.prompt.md',
    '.codex/orchestration/prompts/planner-stage.prompt.md',
    '.codex/orchestration/prompts/router-stage.prompt.md',
    '.codex/orchestration/prompts/executor-task.prompt.md',
    '.codex/orchestration/prompts/task-spec-review.prompt.md',
    '.codex/orchestration/prompts/task-quality-review.prompt.md',
    '.codex/orchestration/prompts/reviewer-stage.prompt.md',
    '.codex/orchestration/prompts/closeout-stage.prompt.md',
    '.codex/scripts/README.md',
    '.codex/scripts/render-vscode-mcp.ps1',
    '.codex/scripts/sync-mcp-to-codex-config.ps1',
    '.codex/mcp/README.md',
    '.codex/mcp/codex.config.template.toml',
    '.codex/mcp/vscode.mcp.template.json',
    '.codex/orchestration/templates/handoff.template.json',
    '.codex/orchestration/templates/run-artifact.template.json',
    '.codex/orchestration/templates/trace-record.template.json',
    '.codex/orchestration/templates/policy-evaluations.template.json',
    '.codex/orchestration/templates/checkpoint-state.template.json',
    '.codex/orchestration/evals/golden-tests.json',
    '.github/governance/agent-runtime-policy.catalog.json',
    '.github/governance/agent-model-routing.catalog.json',
    'planning/README.md',
    'planning/specs/README.md',
    'scripts/validation/validate-agent-orchestration.ps1',
    'scripts/validation/validate-planning-structure.ps1',
    'scripts/validation/validate-readme-standards.ps1',
    'scripts/validation/validate-authoritative-source-policy.ps1',
    'scripts/validation/validate-instruction-architecture.ps1',
    'scripts/validation/validate-template-standards.ps1',
    'scripts/validation/validate-workspace-efficiency.ps1',
    'scripts/validation/validate-powershell-standards.ps1',
    'scripts/validation/validate-dotnet-standards.ps1',
    'scripts/validation/validate-architecture-boundaries.ps1',
    'scripts/validation/validate-instruction-metadata.ps1',
    'scripts/validation/validate-routing-coverage.ps1',
    'scripts/validation/validate-agent-skill-alignment.ps1',
    'scripts/validation/validate-agent-permissions.ps1',
    'scripts/validation/validate-security-baseline.ps1',
    'scripts/validation/validate-shared-script-checksums.ps1',
    'scripts/validation/validate-warning-baseline.ps1',
    'scripts/validation/validate-supply-chain.ps1',
    'scripts/validation/validate-audit-ledger.ps1',
    'scripts/validation/validate-release-provenance.ps1',
    'scripts/validation/validate-all.ps1',
    'scripts/governance/update-shared-script-checksums-manifest.ps1',
    'scripts/runtime/run-agent-pipeline.ps1',
    'scripts/runtime/resume-agent-pipeline.ps1',
    'scripts/runtime/replay-agent-run.ps1',
    'scripts/runtime/evaluate-agent-pipeline.ps1',
    'scripts/runtime/setup-vscode-profiles.ps1',
    'scripts/runtime/render-github-instruction-surfaces.ps1',
    'scripts/runtime/render-mcp-runtime-artifacts.ps1',
    'scripts/runtime/render-vscode-mcp-template.ps1',
    'scripts/runtime/render-provider-surfaces.ps1',
    'scripts/runtime/render-provider-skill-surfaces.ps1',
    'scripts/runtime/render-codex-compatibility-surfaces.ps1',
    'scripts/runtime/render-vscode-profile-surfaces.ps1',
    'scripts/runtime/render-vscode-workspace-surfaces.ps1',
    'scripts/runtime/render-codex-orchestration-surfaces.ps1',
    'scripts/runtime/render-claude-runtime-surfaces.ps1',
    'scripts/runtime/sync-codex-mcp-config.ps1',
    'scripts/runtime/hooks/common.ps1',
    'scripts/runtime/hooks/session-start.ps1',
    'scripts/runtime/hooks/subagent-start.ps1',
    'scripts/runtime/hooks/pre-tool-use.ps1',
    'scripts/common/provider-surface-catalog.ps1',
    'scripts/runtime/update-local-context-index.ps1',
    'scripts/runtime/query-local-context-index.ps1',
    'scripts/runtime/new-super-agent-worktree.ps1',
    'scripts/runtime/invoke-super-agent-brainstorm.ps1',
    'scripts/runtime/invoke-super-agent-plan.ps1',
    'scripts/runtime/invoke-super-agent-execute.ps1',
    'scripts/runtime/invoke-super-agent-parallel-dispatch.ps1',
    'scripts/orchestration/engine/invoke-codex-dispatch.ps1',
    'scripts/orchestration/engine/invoke-task-worker.ps1',
    'scripts/orchestration/stages/intake-stage.ps1',
    'scripts/runtime/sync-vscode-global-settings.ps1',
    'scripts/runtime/sync-vscode-global-snippets.ps1',
    'scripts/runtime/sync-workspace-settings.ps1',
    'scripts/runtime/clean-codex-runtime.ps1',
    'scripts/runtime/clean-vscode-user-runtime.ps1',
    'scripts/runtime/set-codex-runtime-preferences.ps1',
    'scripts/orchestration/stages/plan-stage.ps1',
    'scripts/orchestration/stages/route-stage.ps1',
    'scripts/orchestration/stages/implement-stage.ps1',
    'scripts/orchestration/stages/validate-stage.ps1',
    'scripts/orchestration/stages/review-stage.ps1',
    'scripts/orchestration/stages/closeout-stage.ps1',
    'scripts/tests/runtime/vscode-global-settings-sync.tests.ps1',
    'scripts/tests/runtime/vscode-global-snippets-sync.tests.ps1',
    'scripts/tests/runtime/authoritative-source-policy.tests.ps1',
    'scripts/tests/runtime/agent-orchestration-engine.tests.ps1',
    'scripts/tests/runtime/instruction-architecture.tests.ps1',
    'scripts/tests/runtime/mcp-config-sync.tests.ps1',
    'scripts/tests/runtime/planning-structure.tests.ps1',
    'scripts/tests/runtime/super-agent-entrypoints.tests.ps1',
    'scripts/tests/runtime/super-agent-worktree.tests.ps1',
    'scripts/tests/runtime/workspace-efficiency.tests.ps1',
    'scripts/tests/runtime/workspace-settings-sync.tests.ps1'
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

$mcpRuntimeCatalog = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/mcp-runtime.catalog.json'
$providerSurfaceProjectionCatalog = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/provider-surface-projection.catalog.json'
$mcpManifest = Test-JsonFile -Root $resolvedRepoRoot -Path '.codex/mcp/servers.manifest.json'
if ($null -ne $mcpManifest) {
    if ($null -eq $mcpManifest.servers -or @($mcpManifest.servers).Count -eq 0) {
        Add-ValidationFailure 'MCP manifest must contain at least one server.'
    }
}

$localContextIndexCatalog = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/local-context-index.catalog.json'
if ($null -ne $localContextIndexCatalog) {
    if ($null -eq $localContextIndexCatalog.includeGlobs -or @($localContextIndexCatalog.includeGlobs).Count -eq 0) {
        Add-ValidationFailure 'Local context index catalog must contain at least one includeGlobs entry.'
    }
}

$providerSurfaceCatalogInfo = $null
if ($null -ne $providerSurfaceProjectionCatalog) {
    try {
        $providerSurfaceCatalogInfo = Read-ProviderSurfaceProjectionCatalog -RepoRoot $resolvedRepoRoot
        if (@($providerSurfaceCatalogInfo.Catalog.renderers).Count -eq 0) {
            Add-ValidationFailure 'Provider surface projection catalog must contain at least one renderer.'
        }
        if (@($providerSurfaceCatalogInfo.Catalog.surfaces).Count -eq 0) {
            Add-ValidationFailure 'Provider surface projection catalog must contain at least one surface.'
        }
    }
    catch {
        Add-ValidationFailure ("Unable to read provider surface projection catalog: {0}" -f $_.Exception.Message)
    }
}

$sharedChecksumsManifest = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/shared-script-checksums.manifest.json'
if ($null -ne $sharedChecksumsManifest) {
    if ([string] $sharedChecksumsManifest.hashAlgorithm -ne 'SHA256') {
        Add-ValidationFailure "Shared script checksum manifest hashAlgorithm must be 'SHA256'."
    }

    if ($null -eq $sharedChecksumsManifest.entries -or @($sharedChecksumsManifest.entries).Count -eq 0) {
        Add-ValidationFailure 'Shared script checksum manifest must contain at least one entry.'
    }
}

$authoritativeSourceMap = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/authoritative-source-map.json'
if ($null -ne $authoritativeSourceMap) {
    if ($null -eq $authoritativeSourceMap.stackRules -or @($authoritativeSourceMap.stackRules).Count -eq 0) {
        Add-ValidationFailure 'Authoritative source map must contain at least one stackRules entry.'
    }
}

$instructionOwnershipManifest = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/instruction-ownership.manifest.json'
if ($null -ne $instructionOwnershipManifest) {
    if ($null -eq $instructionOwnershipManifest.layers -or @($instructionOwnershipManifest.layers).Count -eq 0) {
        Add-ValidationFailure 'Instruction ownership manifest must contain at least one layer.'
    }
}

$templateStandardsBaseline = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/template-standards.baseline.json'
if ($null -ne $templateStandardsBaseline) {
    if ($null -eq $templateStandardsBaseline.templateRules -or @($templateStandardsBaseline.templateRules).Count -eq 0) {
        Add-ValidationFailure 'Template standards baseline must contain at least one templateRules entry.'
    }
}

$workspaceEfficiencyBaseline = Test-JsonFile -Root $resolvedRepoRoot -Path '.github/governance/workspace-efficiency.baseline.json'
if ($null -ne $workspaceEfficiencyBaseline) {
    if ($null -eq $workspaceEfficiencyBaseline.requiredSettings) {
        Add-ValidationFailure 'Workspace efficiency baseline must contain requiredSettings.'
    }

    if ($null -eq $workspaceEfficiencyBaseline.heuristics) {
        Add-ValidationFailure 'Workspace efficiency baseline must contain heuristics.'
    }
}

$codexCliSnippets = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/snippets/codex-cli.tamplate.code-snippets'
$copilotSnippets = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/snippets/copilot.tamplate.code-snippets'
$vscodeBaseWorkspace = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/base.code-workspace'
$vscodeSettings = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/settings.tamplate.jsonc'
$vscodeMcp = Test-JsonFile -Root $resolvedRepoRoot -Path '.vscode/mcp.tamplate.jsonc'

if ($null -ne $vscodeBaseWorkspace) {
    if ($null -eq $vscodeBaseWorkspace.folders) {
        Add-ValidationFailure 'VS Code base workspace must contain a folders property.'
    }

    if ($null -eq $vscodeBaseWorkspace.extensions -or $null -eq $vscodeBaseWorkspace.extensions.recommendations -or @($vscodeBaseWorkspace.extensions.recommendations).Count -eq 0) {
        Add-ValidationFailure 'VS Code base workspace must contain at least one extension recommendation.'
    }
}

$orchestrationJsonFiles = @(
    '.github/schemas/agent.contract.schema.json',
    '.github/schemas/agent.pipeline.schema.json',
    '.github/schemas/agent.handoff.schema.json',
    '.github/schemas/agent.run-artifact.schema.json',
    '.github/schemas/agent.evals.schema.json',
    '.github/schemas/agent.trace-record.schema.json',
    '.github/schemas/agent.policy-evaluation.schema.json',
    '.github/schemas/agent.checkpoint-state.schema.json',
    '.github/schemas/agent.stage-spec-result.schema.json',
    '.github/schemas/agent.stage-plan-result.schema.json',
    '.github/schemas/agent.stage-implementation-result.schema.json',
    '.github/schemas/agent.stage-review-result.schema.json',
    '.codex/orchestration/agents.manifest.json',
    '.codex/orchestration/pipelines/default.pipeline.json',
    '.codex/orchestration/templates/handoff.template.json',
    '.codex/orchestration/templates/run-artifact.template.json',
    '.codex/orchestration/templates/trace-record.template.json',
    '.codex/orchestration/templates/policy-evaluations.template.json',
    '.codex/orchestration/templates/checkpoint-state.template.json',
    '.github/governance/agent-runtime-policy.catalog.json',
    '.github/governance/agent-model-routing.catalog.json',
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

if ($null -ne $mcpRuntimeCatalog -and $null -ne $vscodeMcp) {
    try {
        $catalogInfo = Read-McpRuntimeCatalog -RepoRoot $resolvedRepoRoot
        $renderedVscodeDocument = Convert-McpRuntimeCatalogToVscodeDocument -Catalog $catalogInfo.Catalog
        if ((ConvertTo-StableJson -Value $renderedVscodeDocument) -ne (ConvertTo-StableJson -Value $vscodeMcp)) {
            Add-ValidationFailure 'VS Code MCP template drift detected. Re-run scripts/runtime/render-mcp-runtime-artifacts.ps1.'
        }

        $renderedCodexManifest = Convert-McpRuntimeCatalogToCodexManifest -Catalog $catalogInfo.Catalog
        if ($null -ne $mcpManifest -and ((ConvertTo-StableJson -Value $renderedCodexManifest) -ne (ConvertTo-StableJson -Value $mcpManifest))) {
            Add-ValidationFailure 'Codex MCP manifest drift detected. Re-run scripts/runtime/render-mcp-runtime-artifacts.ps1.'
        }
    }
    catch {
        Add-ValidationFailure ("Unable to validate MCP runtime catalog parity: {0}" -f $_.Exception.Message)
    }
}

if ($null -ne $providerSurfaceCatalogInfo) {
    $rendererMap = Get-ProviderSurfaceCatalogRendererMap -Catalog $providerSurfaceCatalogInfo.Catalog
    $validatedProjectionSurfaces = Get-ProviderSurfaceProjectionSurfaces -Catalog $providerSurfaceCatalogInfo.Catalog -ValidationEnabledOnly:$true
    foreach ($surface in @($validatedProjectionSurfaces)) {
        $surfaceId = [string] (Get-ProviderSurfaceCatalogOptionalValue -Object $surface -PropertyName 'id' -DefaultValue '')
        $surfaceLabel = [string] (Get-ProviderSurfaceCatalogOptionalValue -Object $surface -PropertyName 'description' -DefaultValue $surfaceId)
        $rendererId = [string] (Get-ProviderSurfaceCatalogOptionalValue -Object $surface -PropertyName 'rendererId' -DefaultValue '')
        $validation = Get-ProviderSurfaceCatalogOptionalValue -Object $surface -PropertyName 'validation'
        $validationMode = [string] (Get-ProviderSurfaceCatalogOptionalValue -Object $validation -PropertyName 'mode' -DefaultValue 'skip')

        if (-not $rendererMap.ContainsKey($rendererId)) {
            Add-ValidationFailure ("Projection surface '{0}' references unknown renderer '{1}'." -f $surfaceId, $rendererId)
            continue
        }

        if ($validationMode -in @('skip', 'generatedCatalogMcp')) {
            continue
        }

        $sourceRoot = Resolve-ProviderSurfaceCatalogPathValue -RepoRoot $resolvedRepoRoot -PathValue ([string] (Get-ProviderSurfaceCatalogOptionalValue -Object $surface -PropertyName 'sourcePath' -DefaultValue ''))
        $destinationRoot = Resolve-ProviderSurfaceCatalogPathValue -RepoRoot $resolvedRepoRoot -PathValue ([string] (Get-ProviderSurfaceCatalogOptionalValue -Object $surface -PropertyName 'projectedPath' -DefaultValue ''))
        $fixHint = ("Re-run scripts/runtime/render-provider-surfaces.ps1 -RepoRoot . -RendererId {0}." -f $rendererId)

        switch ($validationMode) {
            'directory' {
                $sourceMap = Get-StableDirectoryFileMap -RootPath $sourceRoot
                $destinationMap = Get-StableDirectoryFileMap -RootPath $destinationRoot

                if ($null -eq $sourceMap) {
                    Add-ValidationFailure ("Missing projected source tree: {0}" -f $sourceRoot)
                    continue
                }

                if ($null -eq $destinationMap) {
                    Add-ValidationFailure ("Missing projected destination tree: {0}" -f $destinationRoot)
                    continue
                }

                if ((ConvertTo-StableJson -Value $sourceMap) -ne (ConvertTo-StableJson -Value $destinationMap)) {
                    Add-ValidationFailure ("{0} drift detected. {1}" -f $surfaceLabel, $fixHint)
                }
            }
            'selectedFiles' {
                $fileNames = @((Get-ProviderSurfaceCatalogOptionalValue -Object $validation -PropertyName 'fileNames' -DefaultValue @()) | ForEach-Object { [string] $_ })
                if ($fileNames.Count -eq 0) {
                    Add-ValidationFailure ("Projection surface '{0}' uses selectedFiles validation but declares no fileNames." -f $surfaceId)
                    continue
                }

                $sourceMap = Get-StableSelectedFileMap -RootPath $sourceRoot -FileNames $fileNames
                $destinationMap = Get-StableSelectedFileMap -RootPath $destinationRoot -FileNames $fileNames

                if ($null -eq $sourceMap) {
                    Add-ValidationFailure ("Missing selected-file source tree: {0}" -f $sourceRoot)
                    continue
                }

                if ($null -eq $destinationMap) {
                    Add-ValidationFailure ("Missing selected-file destination tree: {0}" -f $destinationRoot)
                    continue
                }

                if ((ConvertTo-StableJson -Value $sourceMap) -ne (ConvertTo-StableJson -Value $destinationMap)) {
                    Add-ValidationFailure ("{0} drift detected. {1}" -f $surfaceLabel, $fixHint)
                }
            }
            default {
                Add-ValidationFailure ("Projection surface '{0}' uses unsupported validation mode '{1}'." -f $surfaceId, $validationMode)
            }
        }
    }
}

Test-VscodeSettingsReference -Root $resolvedRepoRoot -Settings $vscodeSettings
Test-WorkspaceTemplateCompatibility -WorkspaceBaseline $workspaceEfficiencyBaseline -VscodeSettings $vscodeSettings
Test-SnippetReference -Root $resolvedRepoRoot -SnippetFiles @{
    '.vscode/snippets/codex-cli.tamplate.code-snippets' = $codexCliSnippets
    '.vscode/snippets/copilot.tamplate.code-snippets' = $copilotSnippets
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