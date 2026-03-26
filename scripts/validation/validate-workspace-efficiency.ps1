<#
.SYNOPSIS
    Validates VS Code workspace files against repository workspace-efficiency rules.

.DESCRIPTION
    Loads `.github/governance/workspace-efficiency.baseline.json` and validates
    `.code-workspace` files for settings required to keep Codex/Copilot usage
    efficient when multiple VS Code windows are open.

    Checks include:
    - Workspace JSON or JSONC parsing
    - Required settings and exclude maps
    - Forbidden settings values
    - Recommended throttling settings
    - Folder-count and mixed-support-folder heuristics
    - Duplicate folder path detection within one workspace

    Exit code:
    - 0 when validation passes or only warnings are found
    - 1 when failures are found and WarningOnly is false

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER BaselinePath
    Baseline JSON path. Defaults to `.github/governance/workspace-efficiency.baseline.json`.

.PARAMETER SettingsTemplatePath
    Settings template path used to validate effective global-plus-workspace settings.

.PARAMETER WorkspaceSearchRoot
    Root path used to discover `.code-workspace` files. Defaults to repository root.

.PARAMETER WarningOnly
    When true (default), failures are emitted as warnings and execution exits with code 0.

.PARAMETER DetailedOutput
    Prints file-level details for warnings and failures.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-workspace-efficiency.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-workspace-efficiency.ps1 -WorkspaceSearchRoot "C:\Users\me\Projects"

.EXAMPLE
    pwsh -File scripts/validation/validate-workspace-efficiency.ps1 -WarningOnly:$false -DetailedOutput

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $BaselinePath = '.github/governance/workspace-efficiency.baseline.json',
    [string] $SettingsTemplatePath = '.vscode/settings.tamplate.jsonc',
    [string] $WorkspaceSearchRoot = '.',
    [bool] $WarningOnly = $true,
    [switch] $DetailedOutput,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $script:IsVerboseEnabled
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput

# Resolves repository root from input and fallbacks.

# Resolves a path from repo root.

# Reads and parses JSON from file path.
function Read-JsonFile {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationFailure ("Missing {0}: {1}" -f $Label, $Path)
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 200
    }
    catch {
        Add-ValidationFailure ("Invalid JSON/JSONC in {0}: {1}" -f $Label, $_.Exception.Message)
        return $null
    }
}

# Converts null, scalar, or arrays to string arrays.
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

# Converts input object to hashtable keyed by property name.
function Convert-ToPropertyMap {
    param(
        [object] $Value
    )

    $result = @{}
    if ($null -eq $Value) {
        return $result
    }

    if (($Value -is [string]) -or ($Value -is [ValueType])) {
        return $result
    }

    if ($Value -is [hashtable]) {
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

# Merges two JSON-like objects so workspace settings can override the global template.
function Merge-JsonObject {
    param(
        [object] $BaseObject,
        [object] $OverrideObject
    )

    $baseMap = Convert-ToPropertyMap -Value $BaseObject
    $overrideMap = Convert-ToPropertyMap -Value $OverrideObject
    $merged = [ordered]@{}

    foreach ($key in $baseMap.Keys) {
        $merged[$key] = $baseMap[$key]
    }

    foreach ($key in $overrideMap.Keys) {
        $baseValue = if ($merged.Contains($key)) { $merged[$key] } else { $null }
        $overrideValue = $overrideMap[$key]
        $baseValueMap = Convert-ToPropertyMap -Value $baseValue
        $overrideValueMap = Convert-ToPropertyMap -Value $overrideValue

        if ($baseValueMap.Count -gt 0 -and $overrideValueMap.Count -gt 0) {
            $merged[$key] = [pscustomobject] (Merge-JsonObject -BaseObject $baseValue -OverrideObject $overrideValue)
            continue
        }

        $merged[$key] = $overrideValue
    }

    return $merged
}

# Returns a direct property value when available.
function Get-DirectPropertyValue {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
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

# Converts paths to a stable key for duplicate comparison.
function ConvertTo-PathKey {
    param(
        [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    $normalized = $Path.Replace('\', '/').TrimEnd('/')
    if ($IsWindows) {
        return $normalized.ToLowerInvariant()
    }

    return $normalized
}

# Converts a path to repo-relative display path when possible.
function Convert-ToDisplayPath {
    param(
        [string] $Root,
        [string] $Path
    )

    try {
        $relative = [System.IO.Path]::GetRelativePath($Root, $Path)
        if (-not $relative.StartsWith('..')) {
            return $relative
        }
    }
    catch {
        Write-VerboseLog ("Could not convert path to display form: {0}" -f $Path)
    }

    return $Path
}

# Returns true when the workspace file is a versioned template rather than an active workspace.
function Test-IsTemplateWorkspacePath {
    param(
        [string] $WorkspaceDisplayPath,
        [object] $Baseline
    )

    $templatePaths = Convert-ToStringArray -Value (Get-DirectPropertyValue -InputObject $Baseline -PropertyName 'templateWorkspacePaths')
    $normalizedDisplayPath = ConvertTo-PathKey -Path $WorkspaceDisplayPath

    foreach ($templatePath in $templatePaths) {
        $normalizedTemplatePath = ConvertTo-PathKey -Path $templatePath
        if ($normalizedDisplayPath -eq $normalizedTemplatePath) {
            return $true
        }

        $templateLeaf = Split-Path -Path $normalizedTemplatePath -Leaf
        $displayLeaf = Split-Path -Path $normalizedDisplayPath -Leaf
        if ($templateLeaf -eq $normalizedTemplatePath -and $displayLeaf -eq $templateLeaf) {
            return $true
        }
    }

    return $false
}

# Returns true when the input object declares a direct property.
function Test-DirectPropertyExists {
    param(
        [object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject) {
        return $false
    }

    return $null -ne $InputObject.PSObject.Properties[$PropertyName]
}

# Validates one boolean or scalar setting against expected literal value.
function Test-RequiredLiteralSetting {
    param(
        [string] $WorkspaceDisplayPath,
        [object] $SettingsObject,
        [string] $SettingName,
        [object] $ExpectedValue
    )

    $actualValue = Get-DirectPropertyValue -InputObject $SettingsObject -PropertyName $SettingName
    if ($null -eq $actualValue) {
        Add-ValidationFailure ("Workspace missing required setting '{0}': {1}" -f $SettingName, $WorkspaceDisplayPath)
        return
    }

    if ([string] $actualValue -ne [string] $ExpectedValue) {
        Add-ValidationFailure ("Workspace setting '{0}' must be '{1}': {2}" -f $SettingName, $ExpectedValue, $WorkspaceDisplayPath)
    }
}

# Validates object-based settings that must contain required keys.
function Test-RequiredObjectSetting {
    param(
        [string] $WorkspaceDisplayPath,
        [object] $SettingsObject,
        [string] $SettingName,
        [object] $RuleObject
    )

    $actualValue = Get-DirectPropertyValue -InputObject $SettingsObject -PropertyName $SettingName
    if ($null -eq $actualValue) {
        Add-ValidationFailure ("Workspace missing required object setting '{0}': {1}" -f $SettingName, $WorkspaceDisplayPath)
        return
    }

    $map = Convert-ToPropertyMap -Value $actualValue
    $requiredKeys = Convert-ToStringArray -Value (Get-DirectPropertyValue -InputObject $RuleObject -PropertyName 'requiredKeys')
    foreach ($requiredKey in $requiredKeys) {
        if (-not $map.ContainsKey($requiredKey) -or -not [bool] $map[$requiredKey]) {
            Add-ValidationFailure ("Workspace setting '{0}' must include '{1}': {2}" -f $SettingName, $requiredKey, $WorkspaceDisplayPath)
        }
    }
}

# Validates forbidden literal setting values.
function Test-ForbiddenSetting {
    param(
        [string] $WorkspaceDisplayPath,
        [object] $SettingsObject,
        [string] $SettingName,
        [string[]] $ForbiddenValues
    )

    $actualValue = Get-DirectPropertyValue -InputObject $SettingsObject -PropertyName $SettingName
    if ($null -eq $actualValue) {
        return
    }

    $actualText = [string] $actualValue
    foreach ($forbiddenValue in $ForbiddenValues) {
        if ($actualText -eq [string] $forbiddenValue) {
            Add-ValidationFailure ("Workspace setting '{0}' must not be '{1}': {2}" -f $SettingName, $forbiddenValue, $WorkspaceDisplayPath)
        }
    }
}

# Validates recommended literal settings and emits warnings on drift.
function Test-RecommendedLiteralSetting {
    param(
        [string] $WorkspaceDisplayPath,
        [object] $SettingsObject,
        [string] $SettingName,
        [object] $ExpectedValue
    )

    $actualValue = Get-DirectPropertyValue -InputObject $SettingsObject -PropertyName $SettingName
    if ($null -eq $actualValue) {
        Add-ValidationWarning ("Workspace should define recommended setting '{0}' with value '{1}': {2}" -f $SettingName, $ExpectedValue, $WorkspaceDisplayPath)
        return
    }

    if ([string] $actualValue -ne [string] $ExpectedValue) {
        Add-ValidationWarning ("Workspace recommended setting '{0}' should be '{1}': {2}" -f $SettingName, $ExpectedValue, $WorkspaceDisplayPath)
    }
}

# Validates numeric upper bounds for recommended settings.
function Test-RecommendedNumericBound {
    param(
        [string] $WorkspaceDisplayPath,
        [object] $SettingsObject,
        [string] $SettingName,
        [double] $UpperBound
    )

    $actualValue = Get-DirectPropertyValue -InputObject $SettingsObject -PropertyName $SettingName
    if ($null -eq $actualValue) {
        return
    }

    $actualNumber = 0.0
    if (-not [double]::TryParse(([string] $actualValue), [ref] $actualNumber)) {
        Add-ValidationWarning ("Workspace numeric setting '{0}' is not numeric: {1}" -f $SettingName, $WorkspaceDisplayPath)
        return
    }

    if ($actualNumber -gt $UpperBound) {
        Add-ValidationWarning ("Workspace numeric setting '{0}' should be <= {1}: {2}" -f $SettingName, $UpperBound, $WorkspaceDisplayPath)
    }
}

# Validates folder-path duplication and workspace composition heuristics.
function Test-WorkspaceFolders {
    param(
        [string] $WorkspaceFilePath,
        [string] $WorkspaceDisplayPath,
        [object[]] $FolderList,
        [object] $HeuristicConfig
    )

    if ($FolderList.Count -eq 0) {
        Add-ValidationFailure ("Workspace must contain at least one folder: {0}" -f $WorkspaceDisplayPath)
        return
    }

    $supportPatterns = Convert-ToStringArray -Value (Get-DirectPropertyValue -InputObject $HeuristicConfig -PropertyName 'supportFolderPatterns')
    $maxFolderCountWarning = [int] (Get-DirectPropertyValue -InputObject $HeuristicConfig -PropertyName 'maxFolderCountWarning')
    $warnWhenMultipleProductFolders = [bool] (Get-DirectPropertyValue -InputObject $HeuristicConfig -PropertyName 'warnWhenMultipleProductFolders')
    $warnWhenSupportFoldersMixed = [bool] (Get-DirectPropertyValue -InputObject $HeuristicConfig -PropertyName 'warnWhenSupportFoldersMixedWithProductFolders')

    $seenPaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $supportFolderCount = 0
    $productFolderCount = 0

    foreach ($folderItem in $FolderList) {
        $folderPath = [string] (Get-DirectPropertyValue -InputObject $folderItem -PropertyName 'path')
        if ([string]::IsNullOrWhiteSpace($folderPath)) {
            Add-ValidationFailure ("Workspace folder entry missing path: {0}" -f $WorkspaceDisplayPath)
            continue
        }

        $resolvedFolderPath = Resolve-WorkspaceFolderPath -WorkspaceFilePath $WorkspaceFilePath -FolderPath $folderPath
        $normalizedKey = ConvertTo-PathKey -Path $resolvedFolderPath
        if ([string]::IsNullOrWhiteSpace($normalizedKey)) {
            Add-ValidationFailure ("Workspace folder path could not be normalized: {0} :: {1}" -f $WorkspaceDisplayPath, $folderPath)
            continue
        }

        if (-not $seenPaths.Add($normalizedKey)) {
            Add-ValidationFailure ("Workspace contains duplicate folder path '{0}': {1}" -f $folderPath, $WorkspaceDisplayPath)
        }

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

    if ($maxFolderCountWarning -gt 0 -and $FolderList.Count -gt $maxFolderCountWarning) {
        Add-ValidationWarning ("Workspace opens {0} folders; recommended maximum is {1}: {2}" -f $FolderList.Count, $maxFolderCountWarning, $WorkspaceDisplayPath)
    }

    if ($warnWhenMultipleProductFolders -and $productFolderCount -gt 1) {
        Add-ValidationWarning ("Workspace mixes {0} product folders; prefer a smaller active workspace: {1}" -f $productFolderCount, $WorkspaceDisplayPath)
    }

    if ($warnWhenSupportFoldersMixed -and $supportFolderCount -gt 0 -and $productFolderCount -gt 0) {
        Add-ValidationWarning ("Workspace mixes shared AI/config folders with product code; prefer a dedicated configuration workspace: {0}" -f $WorkspaceDisplayPath)
    }
}

# Validates one workspace file against baseline rules.
function Test-WorkspaceFile {
    param(
        [string] $Root,
        [string] $WorkspaceFilePath,
        [object] $Baseline,
        [object] $SettingsTemplate
    )

    $workspaceDisplayPath = Convert-ToDisplayPath -Root $Root -Path $WorkspaceFilePath
    Write-VerboseLog ("Validating workspace file: {0}" -f $workspaceDisplayPath)

    $workspaceDocument = Read-JsonFile -Path $WorkspaceFilePath -Label ("workspace file {0}" -f $workspaceDisplayPath)
    if ($null -eq $workspaceDocument) {
        return
    }

    $folderList = @((Get-DirectPropertyValue -InputObject $workspaceDocument -PropertyName 'folders'))
    if (Test-IsTemplateWorkspacePath -WorkspaceDisplayPath $workspaceDisplayPath -Baseline $Baseline) {
        if (-not (Test-DirectPropertyExists -InputObject $workspaceDocument -PropertyName 'folders')) {
            Add-ValidationFailure ("Template workspace must declare a folders array: {0}" -f $workspaceDisplayPath)
            return
        }

        if ($folderList.Count -gt 0) {
            Add-ValidationWarning ("Template workspace should keep folders empty so it remains reusable: {0}" -f $workspaceDisplayPath)
        }

        return
    }

    $settingsObject = Get-DirectPropertyValue -InputObject $workspaceDocument -PropertyName 'settings'
    if ($null -eq $settingsObject) {
        Add-ValidationFailure ("Workspace must define a settings object: {0}" -f $workspaceDisplayPath)
    }

    Test-WorkspaceFolders -WorkspaceFilePath $WorkspaceFilePath -WorkspaceDisplayPath $workspaceDisplayPath -FolderList $folderList -HeuristicConfig $Baseline.heuristics
    if ($null -eq $settingsObject) {
        return
    }

    $allowedWorkspaceOverrides = Convert-ToStringArray -Value (Get-DirectPropertyValue -InputObject $Baseline -PropertyName 'allowedWorkspaceOverrideSettings')
    $workspaceSettingMap = Convert-ToPropertyMap -Value $settingsObject
    foreach ($settingName in $workspaceSettingMap.Keys) {
        if ($settingName -notin $allowedWorkspaceOverrides) {
            Add-ValidationFailure ("Workspace setting '{0}' is redundant in workspace scope; inherit it from the global template instead: {1}" -f $settingName, $workspaceDisplayPath)
        }
    }

    $effectiveSettings = [pscustomobject] (Merge-JsonObject -BaseObject $SettingsTemplate -OverrideObject $settingsObject)

    $requiredSettingsMap = Convert-ToPropertyMap -Value $Baseline.requiredSettings
    foreach ($settingName in $requiredSettingsMap.Keys) {
        $ruleValue = $requiredSettingsMap[$settingName]
        $ruleMap = Convert-ToPropertyMap -Value $ruleValue
        if ($ruleMap.ContainsKey('requiredKeys')) {
            Test-RequiredObjectSetting -WorkspaceDisplayPath $workspaceDisplayPath -SettingsObject $effectiveSettings -SettingName $settingName -RuleObject $ruleValue
            continue
        }

        Test-RequiredLiteralSetting -WorkspaceDisplayPath $workspaceDisplayPath -SettingsObject $effectiveSettings -SettingName $settingName -ExpectedValue $ruleValue
    }

    $forbiddenSettingsMap = Convert-ToPropertyMap -Value $Baseline.forbiddenSettings
    foreach ($settingName in $forbiddenSettingsMap.Keys) {
        $forbiddenValues = Convert-ToStringArray -Value $forbiddenSettingsMap[$settingName]
        Test-ForbiddenSetting -WorkspaceDisplayPath $workspaceDisplayPath -SettingsObject $effectiveSettings -SettingName $settingName -ForbiddenValues $forbiddenValues
    }

    $recommendedSettingsMap = Convert-ToPropertyMap -Value $Baseline.recommendedSettings
    foreach ($settingName in $recommendedSettingsMap.Keys) {
        Test-RecommendedLiteralSetting -WorkspaceDisplayPath $workspaceDisplayPath -SettingsObject $effectiveSettings -SettingName $settingName -ExpectedValue $recommendedSettingsMap[$settingName]
    }

    $numericBoundsMap = Convert-ToPropertyMap -Value $Baseline.recommendedNumericUpperBounds
    foreach ($settingName in $numericBoundsMap.Keys) {
        Test-RecommendedNumericBound -WorkspaceDisplayPath $workspaceDisplayPath -SettingsObject $effectiveSettings -SettingName $settingName -UpperBound ([double] $numericBoundsMap[$settingName])
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$resolvedBaselinePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $BaselinePath
$resolvedSettingsTemplatePath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $SettingsTemplatePath
$resolvedWorkspaceSearchRoot = Resolve-RepoPath -Root $resolvedRepoRoot -Path $WorkspaceSearchRoot

$baseline = Read-JsonFile -Path $resolvedBaselinePath -Label 'workspace-efficiency baseline'
if ($null -eq $baseline) {
    exit 1
}

$settingsTemplate = Read-JsonFile -Path $resolvedSettingsTemplatePath -Label 'VS Code settings template'
if ($null -eq $settingsTemplate) {
    exit 1
}

if (-not (Test-Path -LiteralPath $resolvedWorkspaceSearchRoot -PathType Container)) {
    if (Test-Path -LiteralPath $resolvedWorkspaceSearchRoot -PathType Leaf) {
        $workspaceFiles = @($resolvedWorkspaceSearchRoot)
    }
    else {
        Add-ValidationFailure ("Workspace search root not found: {0}" -f $resolvedWorkspaceSearchRoot)
        $workspaceFiles = @()
    }
}
else {
    $workspaceFiles = @(
        Get-ChildItem -LiteralPath $resolvedWorkspaceSearchRoot -Recurse -File -Filter '*.code-workspace' | Select-Object -ExpandProperty FullName
    )
}

foreach ($workspaceFile in @($workspaceFiles | Select-Object -Unique | Sort-Object)) {
    Test-WorkspaceFile -Root $resolvedRepoRoot -WorkspaceFilePath $workspaceFile -Baseline $baseline -SettingsTemplate $settingsTemplate
}

Write-StyledOutput ''
Write-StyledOutput 'Workspace efficiency validation summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Settings template: {0}" -f $resolvedSettingsTemplatePath)
Write-StyledOutput ("  Workspace search root: {0}" -f $resolvedWorkspaceSearchRoot)
Write-StyledOutput ("  Workspace files checked: {0}" -f @($workspaceFiles).Count)
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

if ($script:Failures.Count -gt 0 -or $script:Warnings.Count -gt 0) {
    Write-StyledOutput 'Workspace efficiency validation completed with warnings.'
}
else {
    Write-StyledOutput 'Workspace efficiency validation passed.'
}

exit 0