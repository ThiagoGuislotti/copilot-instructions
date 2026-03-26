<#
.SYNOPSIS
    Generates or synchronizes efficient VS Code workspace settings from the shared template.

.DESCRIPTION
    VS Code does not provide native inheritance from an external `.vscode/settings.json`
    into `.code-workspace` files. This script implements repository-managed pseudo-inheritance
    by combining:
    - `.vscode/base.code-workspace`
    - `.vscode/settings.tamplate.jsonc`
    - `.github/governance/workspace-efficiency.baseline.json`

    The script keeps the workspace file lean:
    - preserves existing `folders` and workspace-specific top-level properties
    - merges shared recommendations from the base workspace `extensions` block
    - carries missing top-level defaults from the base workspace when creating/updating files
    - replaces only the `settings` object
    - removes duplicated settings already covered by the global VS Code template
    - applies only approved local overrides for multi-window Codex/Copilot usage

    When the workspace file does not exist, provide `-FolderPath` to create it.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER WorkspacePath
    Target `.code-workspace` file path. Can be relative to the repository root or absolute.

.PARAMETER FolderPath
    Folder paths used when creating a new workspace file. Ignored when the workspace already exists.

.PARAMETER BaselinePath
    Optional workspace-efficiency baseline path relative to repository root.

.PARAMETER SettingsTemplatePath
    Optional VS Code settings template path relative to repository root.

.PARAMETER BaseWorkspacePath
    Optional base workspace path relative to repository root.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/sync-workspace-settings.ps1 -WorkspacePath .\workspaces\api.code-workspace -FolderPath src\Api

.EXAMPLE
    pwsh -File scripts/runtime/sync-workspace-settings.ps1 -WorkspacePath C:\Users\me\Projects\app.code-workspace

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $WorkspacePath,
    [string[]] $FolderPath,
    [string] $BaselinePath = '.github/governance/workspace-efficiency.baseline.json',
    [string] $SettingsTemplatePath = '.vscode/settings.tamplate.jsonc',
    [string] $BaseWorkspacePath = '.vscode/base.code-workspace',
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
# Reads one JSON or JSONC file.
function Read-JsonFile {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing ${Label}: $Path"
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        throw "Invalid JSON/JSONC in ${Label}: $($Path) :: $($_.Exception.Message)"
    }
}

# Converts JSON-like objects to a property map keyed by property name.
function Convert-ToPropertyMap {
    param(
        [object] $Value
    )

    $result = [ordered]@{}
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

# Gets a direct property value from a JSON-like object.
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

# Converts null, scalar, or arrays to a string array.
function Convert-ToStringArray {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        return @([string] $Value)
    }

    return @($Value | ForEach-Object { [string] $_ })
}

# Merges string arrays while preserving first-seen order and uniqueness.
function Merge-UniqueStringValues {
    param(
        [object[]] $PrimaryValues,
        [object[]] $SecondaryValues
    )

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($PrimaryValues) + @($SecondaryValues)) {
        $text = [string] $value
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        if (-not $items.Contains($text)) {
            $items.Add($text) | Out-Null
        }
    }

    return $items.ToArray()
}

# Merges workspace extension recommendations with the shared base workspace.
function Merge-WorkspaceExtensions {
    param(
        [object] $ExistingExtensions,
        [object] $BaseExtensions
    )

    $existingRecommendations = Convert-ToStringArray -Value (Get-JsonPropertyValue -InputObject $ExistingExtensions -PropertyName 'recommendations')
    $baseRecommendations = Convert-ToStringArray -Value (Get-JsonPropertyValue -InputObject $BaseExtensions -PropertyName 'recommendations')
    $existingUnwanted = Convert-ToStringArray -Value (Get-JsonPropertyValue -InputObject $ExistingExtensions -PropertyName 'unwantedRecommendations')
    $baseUnwanted = Convert-ToStringArray -Value (Get-JsonPropertyValue -InputObject $BaseExtensions -PropertyName 'unwantedRecommendations')

    [string[]] $mergedRecommendations = Merge-UniqueStringValues -PrimaryValues $existingRecommendations -SecondaryValues $baseRecommendations
    [string[]] $mergedUnwanted = Merge-UniqueStringValues -PrimaryValues $existingUnwanted -SecondaryValues $baseUnwanted

    if (@($mergedRecommendations).Count -eq 0 -and @($mergedUnwanted).Count -eq 0) {
        return $null
    }

    $extensions = [ordered]@{}
    if (@($mergedRecommendations).Count -gt 0) {
        $extensions['recommendations'] = $mergedRecommendations
    }

    if (@($mergedUnwanted).Count -gt 0) {
        $extensions['unwantedRecommendations'] = $mergedUnwanted
    }

    return [pscustomobject] $extensions
}

# Resolves one workspace folder path relative to its file.
function Resolve-WorkspaceFolderPath {
    param(
        [string] $WorkspaceFilePath,
        [string] $FolderPath
    )

    if ([string]::IsNullOrWhiteSpace($FolderPath)) {
        return $null
    }

    $workspaceDirectory = Split-Path -Path $WorkspaceFilePath -Parent
    if ([System.IO.Path]::IsPathRooted($FolderPath)) {
        return [System.IO.Path]::GetFullPath($FolderPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $workspaceDirectory $FolderPath))
}

# Returns true when the workspace should apply local git.autorefresh throttling.
function Test-IsHeavyWorkspace {
    param(
        [string] $WorkspaceFilePath,
        [object[]] $FolderList,
        [object] $WorkspaceBaseline
    )

    $heuristics = Convert-ToPropertyMap -Value (Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'heuristics')
    $supportPatterns = Convert-ToStringArray -Value $heuristics['supportFolderPatterns']
    $supportFolderCount = 0
    $productFolderCount = 0

    foreach ($folderItem in @($FolderList)) {
        if ($null -eq $folderItem) {
            continue
        }

        $folderPath = [string] (Get-JsonPropertyValue -InputObject $folderItem -PropertyName 'path')
        if ([string]::IsNullOrWhiteSpace($folderPath)) {
            continue
        }

        $resolvedFolderPath = Resolve-WorkspaceFolderPath -WorkspaceFilePath $WorkspaceFilePath -FolderPath $folderPath
        $isSupportFolder = $false
        foreach ($pattern in $supportPatterns) {
            if ($resolvedFolderPath -match $pattern -or $folderPath -match $pattern) {
                $isSupportFolder = $true
                break
            }
        }

        if ($isSupportFolder) {
            $supportFolderCount++
        }
        else {
            $productFolderCount++
        }
    }

    if (@($FolderList).Count -gt 1) {
        return $true
    }

    if ($supportFolderCount -gt 0) {
        return $true
    }

    if ($productFolderCount -gt 1) {
        return $true
    }

    return $false
}

# Builds the allowed workspace settings subset from baseline and workspace composition.
function New-WorkspaceSettingsObject {
    param(
        [object] $WorkspaceBaseline,
        [string] $WorkspaceFilePath,
        [object[]] $FolderList
    )

    $recommendedBounds = Convert-ToPropertyMap -Value (Get-JsonPropertyValue -InputObject $WorkspaceBaseline -PropertyName 'recommendedNumericUpperBounds')
    $settings = [ordered]@{
        'chat.agent.maxRequests' = [int] $recommendedBounds['chat.agent.maxRequests']
    }

    if (Test-IsHeavyWorkspace -WorkspaceFilePath $WorkspaceFilePath -FolderList $FolderList -WorkspaceBaseline $WorkspaceBaseline) {
        $settings['git.autorefresh'] = $false
    }

    return [pscustomobject] $settings
}

# Creates a new workspace document with supplied folders.
function New-WorkspaceDocument {
    param(
        [object] $BaseWorkspaceDocument,
        [string[]] $FolderPaths,
        [object] $SettingsObject
    )

    $folders = @()
    foreach ($item in @($FolderPaths)) {
        if ([string]::IsNullOrWhiteSpace([string] $item)) {
            continue
        }

        $folders += [pscustomobject] ([ordered]@{
            path = [string] $item
        })
    }

    $document = [ordered]@{
        folders = $folders
    }

    if ($null -ne $BaseWorkspaceDocument) {
        $baseExtensions = Merge-WorkspaceExtensions -ExistingExtensions $null -BaseExtensions (Get-JsonPropertyValue -InputObject $BaseWorkspaceDocument -PropertyName 'extensions')
        if ($null -ne $baseExtensions) {
            $document['extensions'] = $baseExtensions
        }

        foreach ($property in $BaseWorkspaceDocument.PSObject.Properties) {
            if ($property.Name -in @('folders', 'settings', 'extensions')) {
                continue
            }

            $document[$property.Name] = $property.Value
        }
    }

    $document['settings'] = $SettingsObject
    return [pscustomobject] $document
}

# Replaces the workspace settings while preserving existing top-level properties.
function Set-WorkspaceSettings {
    param(
        [object] $WorkspaceDocument,
        [object] $BaseWorkspaceDocument,
        [object] $SettingsObject
    )

    $ordered = [ordered]@{}
    $settingsInserted = $false
    $foldersSeen = $false
    $baseExtensions = if ($null -ne $BaseWorkspaceDocument) { Get-JsonPropertyValue -InputObject $BaseWorkspaceDocument -PropertyName 'extensions' } else { $null }
    $extensionsMerged = $false

    foreach ($property in $WorkspaceDocument.PSObject.Properties) {
        if ($property.Name -eq 'settings') {
            $ordered['settings'] = $SettingsObject
            $settingsInserted = $true
            continue
        }

        if ($property.Name -eq 'extensions') {
            $mergedExtensions = Merge-WorkspaceExtensions -ExistingExtensions $property.Value -BaseExtensions $baseExtensions
            if ($null -ne $mergedExtensions) {
                $ordered['extensions'] = $mergedExtensions
            }
            $extensionsMerged = $true
            continue
        }

        $ordered[$property.Name] = $property.Value
        if ($property.Name -eq 'folders') {
            $foldersSeen = $true
            if (-not $settingsInserted) {
                $ordered['settings'] = $SettingsObject
                $settingsInserted = $true
            }
        }
    }

    if (-not $foldersSeen) {
        $ordered['folders'] = @()
        if (-not $settingsInserted) {
            $ordered['settings'] = $SettingsObject
            $settingsInserted = $true
        }
    }

    if (-not $settingsInserted) {
        $ordered['settings'] = $SettingsObject
    }

    if (-not $extensionsMerged) {
        $mergedExtensions = Merge-WorkspaceExtensions -ExistingExtensions $null -BaseExtensions $baseExtensions
        if ($null -ne $mergedExtensions) {
            $ordered['extensions'] = $mergedExtensions
        }
    }

    if ($null -ne $BaseWorkspaceDocument) {
        foreach ($property in $BaseWorkspaceDocument.PSObject.Properties) {
            if ($property.Name -in @('folders', 'settings', 'extensions')) {
                continue
            }

            if (-not $ordered.Contains($property.Name)) {
                $ordered[$property.Name] = $property.Value
            }
        }
    }

    return [pscustomobject] $ordered
}

# Writes one workspace document as JSON.
function Write-WorkspaceDocument {
    param(
        [string] $Path,
        [object] $Document
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $json = $Document | ConvertTo-Json -Depth 100
    Set-Content -LiteralPath $Path -Value $json
}

if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
    throw 'WorkspacePath is required.'
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedWorkspacePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $WorkspacePath
$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$resolvedSettingsTemplatePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $SettingsTemplatePath
$resolvedBaseWorkspacePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaseWorkspacePath

$workspaceBaseline = Read-JsonFile -Path $resolvedBaselinePath -Label 'workspace-efficiency baseline'
$baseWorkspaceDocument = Read-JsonFile -Path $resolvedBaseWorkspacePath -Label 'base workspace'
$workspaceExists = Test-Path -LiteralPath $resolvedWorkspacePath -PathType Leaf
if ($workspaceExists) {
    $workspaceDocument = Read-JsonFile -Path $resolvedWorkspacePath -Label 'workspace file'
    $workspaceSettings = New-WorkspaceSettingsObject -WorkspaceBaseline $workspaceBaseline -WorkspaceFilePath $resolvedWorkspacePath -FolderList @($workspaceDocument.folders)
    $updatedDocument = Set-WorkspaceSettings -WorkspaceDocument $workspaceDocument -BaseWorkspaceDocument $baseWorkspaceDocument -SettingsObject $workspaceSettings
    Write-WorkspaceDocument -Path $resolvedWorkspacePath -Document $updatedDocument
    Write-StyledOutput ("[OK] Workspace settings synchronized: {0}" -f $resolvedWorkspacePath)
    Write-StyledOutput ("Folders preserved: {0}" -f @($updatedDocument.folders).Count)
}
else {
    if (@($FolderPath).Count -eq 0) {
        throw 'Workspace file does not exist. Provide -FolderPath to create a new workspace.'
    }

    $folderItems = @($FolderPath | ForEach-Object { [pscustomobject] ([ordered]@{ path = [string] $_ }) })
    $workspaceSettings = New-WorkspaceSettingsObject -WorkspaceBaseline $workspaceBaseline -WorkspaceFilePath $resolvedWorkspacePath -FolderList $folderItems
    $newDocument = New-WorkspaceDocument -BaseWorkspaceDocument $baseWorkspaceDocument -FolderPaths $FolderPath -SettingsObject $workspaceSettings
    Write-WorkspaceDocument -Path $resolvedWorkspacePath -Document $newDocument
    Write-StyledOutput ("[OK] Workspace created with synchronized settings: {0}" -f $resolvedWorkspacePath)
    Write-StyledOutput ("Folders created: {0}" -f @($newDocument.folders).Count)
}

Write-StyledOutput ''
Write-StyledOutput 'Workspace settings sync summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Workspace path: {0}" -f $resolvedWorkspacePath)
Write-StyledOutput ("  Baseline: {0}" -f $resolvedBaselinePath)
Write-StyledOutput ("  Template: {0}" -f $resolvedSettingsTemplatePath)
Write-StyledOutput ("  Base workspace: {0}" -f $resolvedBaseWorkspacePath)

exit 0