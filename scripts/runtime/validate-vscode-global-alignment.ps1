<#
.SYNOPSIS
    Validates repository VS Code templates are contained in global VS Code user files.

.DESCRIPTION
    Compares repository-managed `.vscode` files against global VS Code user settings
    to confirm the repository baseline is present in the user profile.

    Containment mappings:
    - .vscode/settings.tamplate.jsonc -> <global-user>/settings.json
    - .vscode/mcp.tamplate.jsonc -> <global-user>/mcp.json
    - .vscode/snippets/*.tamplate.code-snippets -> <global-user>/snippets/*.code-snippets

    The comparison is subset-based:
    - Every key/value from source must exist in target.
    - For arrays, each source item must be found in target.
    - Extra keys in global files are allowed.

.PARAMETER RepoRoot
    Optional repository root. If omitted, script detects a root containing .github and .codex.

.PARAMETER WorkspaceVscodePath
    Optional path to repository `.vscode` folder. Defaults to `<RepoRoot>/.vscode`.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user folder path. Default is OS-specific:
    - Windows: `%APPDATA%\Code\User`
    - macOS: `~/Library/Application Support/Code/User`
    - Linux: `$XDG_CONFIG_HOME/Code/User` or `~/.config/Code/User`

.PARAMETER SkipSnippets
    Skips snippet containment checks.

.PARAMETER WarningOnly
    When true (default), mismatches are emitted as warnings and execution exits with code 0.

.PARAMETER DetailedOutput
    Prints detailed mismatch paths for each drifted mapping.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/validate-vscode-global-alignment.ps1

.EXAMPLE
    pwsh -File scripts/runtime/validate-vscode-global-alignment.ps1 -GlobalVscodeUserPath "C:\Users\me\AppData\Roaming\Code\User"

.EXAMPLE
    pwsh -File scripts/runtime/validate-vscode-global-alignment.ps1 -WarningOnly:$false -DetailedOutput

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $WorkspaceVscodePath,
    [string] $GlobalVscodeUserPath,
    [switch] $SkipSnippets,
    [bool] $WarningOnly = $true,
    [switch] $DetailedOutput,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../shared-scripts/common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $script:IsVerboseEnabled
$script:IsDetailedOutputEnabled = [bool] $DetailedOutput

# Resolves workspace .vscode folder path.
function Resolve-WorkspaceVscodePath {
    param(
        [string] $ResolvedRepoRoot,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedRepoRoot '.vscode'
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedRepoRoot $RequestedPath))
}

# Resolves VS Code global user folder path with OS-aware defaults.
function Resolve-GlobalVscodeUserPath {
    param(
        [string] $RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath -PathType Container) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }

        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    $homePath = Resolve-UserHomePath
    $candidates = @()

    if ($IsWindows) {
        if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
            $candidates += (Join-Path $env:APPDATA 'Code\User')
        }
        $candidates += (Join-Path $homePath 'AppData\Roaming\Code\User')
    }
    elseif ($IsMacOS) {
        $candidates += (Join-Path $homePath 'Library/Application Support/Code/User')
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
            $candidates += (Join-Path $env:XDG_CONFIG_HOME 'Code/User')
        }
        $candidates += (Join-Path $homePath '.config/Code/User')
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if ($candidates.Count -gt 0) {
        return [System.IO.Path]::GetFullPath($candidates[0])
    }

    throw 'Could not resolve VS Code global user path.'
}

# Reads one JSON or JSONC file and parses it into an object.
function Get-JsonDocument {
    param(
        [string] $FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return $null
    }

    try {
        return (Get-Content -Raw -LiteralPath $FilePath | ConvertFrom-Json -Depth 200)
    }
    catch {
        Add-ValidationFailure ("Invalid JSON/JSONC file: {0} :: {1}" -f $FilePath, $_.Exception.Message)
        return $null
    }
}

# Tests whether the value should be treated as a dictionary-like JSON object.
function Test-IsDictionaryValue {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [System.Collections.IDictionary]) {
        return $true
    }

    return ($Value -is [pscustomobject])
}

# Tests whether the value should be treated as an array-like JSON value.
function Test-IsListValue {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [string]) {
        return $false
    }

    if (Test-IsDictionaryValue -Value $Value) {
        return $false
    }

    return ($Value -is [System.Collections.IEnumerable])
}

# Gets key names from dictionary-like values.
function Get-DictionaryKeyList {
    param(
        [object] $Dictionary
    )

    if ($Dictionary -is [System.Collections.IDictionary]) {
        return @($Dictionary.Keys | ForEach-Object { [string] $_ })
    }

    return @($Dictionary.PSObject.Properties | ForEach-Object { $_.Name })
}

# Tests whether a dictionary-like value contains a key.
function Test-DictionaryContainsKey {
    param(
        [object] $Dictionary,
        [string] $Key
    )

    if ($Dictionary -is [System.Collections.IDictionary]) {
        return $Dictionary.Contains($Key)
    }

    return ($null -ne $Dictionary.PSObject.Properties[$Key])
}

# Gets a value by key from dictionary-like values.
function Get-DictionaryValue {
    param(
        [object] $Dictionary,
        [string] $Key
    )

    if ($Dictionary -is [System.Collections.IDictionary]) {
        return $Dictionary[$Key]
    }

    $property = $Dictionary.PSObject.Properties[$Key]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Converts values to short display text for mismatch diagnostics.
function ConvertTo-DisplayValue {
    param(
        [object] $Value
    )

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [string]) {
        return ("'{0}'" -f $Value)
    }

    if (($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [decimal]) -or ($Value -is [bool])) {
        return [string] $Value
    }

    try {
        return ($Value | ConvertTo-Json -Depth 8 -Compress)
    }
    catch {
        return [string] $Value
    }
}

# Normalizes path-like strings so template placeholders can match runtime paths.
function ConvertTo-NormalizedComparableString {
    param(
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $normalized = $Value.Trim()
    $homePath = Resolve-UserHomePath
    if (-not [string]::IsNullOrWhiteSpace($homePath)) {
        $normalized = $normalized.Replace('%USERPROFILE%', $homePath)
        $normalized = $normalized.Replace('${env:USERPROFILE}', $homePath)
        $normalized = $normalized.Replace('$env:USERPROFILE', $homePath)
        $normalized = $normalized.Replace('$HOME', $homePath)
    }

    if ($normalized -notmatch '^[a-zA-Z][a-zA-Z0-9+\-.]*://') {
        $normalized = $normalized.Replace('/', '\')
        if ($normalized.Length -gt 3) {
            $normalized = $normalized.TrimEnd('\')
        }
    }

    if ($IsWindows) {
        return $normalized.ToLowerInvariant()
    }

    return $normalized
}

# Tests whether two strings are equivalent after placeholder and path normalization.
function Test-EquivalentStringValue {
    param(
        [string] $ExpectedString,
        [string] $ActualString
    )

    if ([string]::Equals($ExpectedString, $ActualString, [System.StringComparison]::Ordinal)) {
        return $true
    }

    return [string]::Equals(
        (ConvertTo-NormalizedComparableString -Value $ExpectedString),
        (ConvertTo-NormalizedComparableString -Value $ActualString),
        [System.StringComparison]::Ordinal
    )
}

# Returns the actual dictionary key that matches the expected key.
function Get-MatchingDictionaryKey {
    param(
        [object] $Dictionary,
        [string] $ExpectedKey
    )

    if (Test-DictionaryContainsKey -Dictionary $Dictionary -Key $ExpectedKey) {
        return $ExpectedKey
    }

    foreach ($candidateKey in (Get-DictionaryKeyList -Dictionary $Dictionary)) {
        if (Test-EquivalentStringValue -ExpectedString $ExpectedKey -ActualString ([string] $candidateKey)) {
            return [string] $candidateKey
        }
    }

    return $null
}

# Recursively validates that ExpectedValue is contained inside ActualValue.
function Test-JsonSubset {
    param(
        [object] $ExpectedValue,
        [object] $ActualValue,
        [string] $CurrentPath,
        [System.Collections.Generic.List[string]] $IssueCollector
    )

    if ($null -eq $ExpectedValue) {
        if ($null -ne $ActualValue) {
            $IssueCollector.Add(("Path '{0}' expected null but target has {1}." -f $CurrentPath, (ConvertTo-DisplayValue -Value $ActualValue))) | Out-Null
            return $false
        }
        return $true
    }

    if (Test-IsDictionaryValue -Value $ExpectedValue) {
        if (-not (Test-IsDictionaryValue -Value $ActualValue)) {
            $IssueCollector.Add(("Path '{0}' expected object but target has {1}." -f $CurrentPath, (ConvertTo-DisplayValue -Value $ActualValue))) | Out-Null
            return $false
        }

        $isContained = $true
        $keys = Get-DictionaryKeyList -Dictionary $ExpectedValue
        foreach ($key in $keys) {
            $childPath = if ([string]::IsNullOrWhiteSpace($CurrentPath)) { $key } else { "{0}.{1}" -f $CurrentPath, $key }
            $matchedKey = Get-MatchingDictionaryKey -Dictionary $ActualValue -ExpectedKey $key
            if ($null -eq $matchedKey) {
                $IssueCollector.Add(("Path '{0}' is missing in target." -f $childPath)) | Out-Null
                $isContained = $false
                continue
            }

            $expectedChild = Get-DictionaryValue -Dictionary $ExpectedValue -Key $key
            $actualChild = Get-DictionaryValue -Dictionary $ActualValue -Key $matchedKey
            if (-not (Test-JsonSubset -ExpectedValue $expectedChild -ActualValue $actualChild -CurrentPath $childPath -IssueCollector $IssueCollector)) {
                $isContained = $false
            }
        }

        return $isContained
    }

    if (Test-IsListValue -Value $ExpectedValue) {
        if (-not (Test-IsListValue -Value $ActualValue)) {
            $IssueCollector.Add(("Path '{0}' expected array but target has {1}." -f $CurrentPath, (ConvertTo-DisplayValue -Value $ActualValue))) | Out-Null
            return $false
        }

        $isContained = $true
        $expectedItems = @($ExpectedValue)
        $actualItems = @($ActualValue)

        for ($index = 0; $index -lt $expectedItems.Count; $index++) {
            $expectedItem = $expectedItems[$index]
            $itemPath = "{0}[{1}]" -f $CurrentPath, $index
            $itemFound = $false

            foreach ($actualItem in $actualItems) {
                $scratchIssues = New-Object System.Collections.Generic.List[string]
                if (Test-JsonSubset -ExpectedValue $expectedItem -ActualValue $actualItem -CurrentPath $itemPath -IssueCollector $scratchIssues) {
                    $itemFound = $true
                    break
                }
            }

            if (-not $itemFound) {
                $IssueCollector.Add(("Path '{0}' item from source was not found in target array." -f $itemPath)) | Out-Null
                $isContained = $false
            }
        }

        return $isContained
    }

    if ($ExpectedValue -is [string]) {
        $matched = ($ActualValue -is [string]) -and (Test-EquivalentStringValue -ExpectedString $ExpectedValue -ActualString $ActualValue)
        if (-not $matched) {
            $IssueCollector.Add(("Path '{0}' mismatch. expected={1}, actual={2}" -f $CurrentPath, (ConvertTo-DisplayValue -Value $ExpectedValue), (ConvertTo-DisplayValue -Value $ActualValue))) | Out-Null
        }
        return $matched
    }

    $primitiveMatch = ($ExpectedValue -eq $ActualValue)
    if (-not $primitiveMatch) {
        $IssueCollector.Add(("Path '{0}' mismatch. expected={1}, actual={2}" -f $CurrentPath, (ConvertTo-DisplayValue -Value $ExpectedValue), (ConvertTo-DisplayValue -Value $ActualValue))) | Out-Null
    }

    return $primitiveMatch
}

# Executes a containment check for one source/target JSON mapping.
function Invoke-FileContainmentCheck {
    param(
        [string] $Name,
        [string] $SourceFilePath,
        [string] $TargetFilePath
    )

    if (-not (Test-Path -LiteralPath $SourceFilePath -PathType Leaf)) {
        Add-ValidationFailure ("Source file not found for mapping '{0}': {1}" -f $Name, $SourceFilePath)
        return [pscustomobject]@{
            Name = $Name
            SourceFile = $SourceFilePath
            TargetFile = $TargetFilePath
            IsAligned = $false
            Issues = @("Source file not found.")
        }
    }

    if (-not (Test-Path -LiteralPath $TargetFilePath -PathType Leaf)) {
        Add-ValidationFailure ("Target file not found for mapping '{0}': {1}" -f $Name, $TargetFilePath)
        return [pscustomobject]@{
            Name = $Name
            SourceFile = $SourceFilePath
            TargetFile = $TargetFilePath
            IsAligned = $false
            Issues = @("Target file not found.")
        }
    }

    $sourceDocument = Get-JsonDocument -FilePath $SourceFilePath
    $targetDocument = Get-JsonDocument -FilePath $TargetFilePath
    if ($null -eq $sourceDocument -or $null -eq $targetDocument) {
        Add-ValidationFailure ("Could not parse mapping '{0}' due JSON parse issues." -f $Name)
        return [pscustomobject]@{
            Name = $Name
            SourceFile = $SourceFilePath
            TargetFile = $TargetFilePath
            IsAligned = $false
            Issues = @('JSON parse failed.')
        }
    }

    $issues = New-Object System.Collections.Generic.List[string]
    $isContained = Test-JsonSubset -ExpectedValue $sourceDocument -ActualValue $targetDocument -CurrentPath '$' -IssueCollector $issues
    if (-not $isContained) {
        Add-ValidationFailure ("Containment drift detected: {0}" -f $Name)
    }

    return [pscustomobject]@{
        Name = $Name
        SourceFile = $SourceFilePath
        TargetFile = $TargetFilePath
        IsAligned = $isContained
        Issues = @($issues)
    }
}

# Converts a snippet template file name into the global target file name.
function Get-GlobalSnippetFileName {
    param(
        [string] $TemplateFileName
    )

    if ([string]::IsNullOrWhiteSpace($TemplateFileName)) {
        throw 'Template file name is required.'
    }

    if ($TemplateFileName -notmatch '\.tamplate\.code-snippets$') {
        throw "Snippet template file name must end with '.tamplate.code-snippets': $TemplateFileName"
    }

    return ($TemplateFileName -replace '\.tamplate(?=\.code-snippets$)', '')
}

# Prints a standardized report for a file containment check.
function Write-ContainmentReport {
    param(
        [object] $Report
    )

    $status = if ($Report.IsAligned) { '[OK]' } else { '[WARN]' }
    Write-StyledOutput ("{0} {1}" -f $status, $Report.Name)
    Write-StyledOutput ("  source: {0}" -f $Report.SourceFile)
    Write-StyledOutput ("  target: {0}" -f $Report.TargetFile)
    Write-StyledOutput ("  issues: {0}" -f $Report.Issues.Count)

    if ($script:IsDetailedOutputEnabled -and $Report.Issues.Count -gt 0) {
        foreach ($issue in $Report.Issues) {
            Write-StyledOutput ("    - {0}" -f $issue)
        }
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedWorkspaceVscodePath = Resolve-WorkspaceVscodePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $WorkspaceVscodePath
$resolvedGlobalVscodeUserPath = Resolve-GlobalVscodeUserPath -RequestedPath $GlobalVscodeUserPath

if (-not (Test-Path -LiteralPath $resolvedWorkspaceVscodePath -PathType Container)) {
    Add-ValidationFailure ("Workspace .vscode folder not found: {0}" -f $resolvedWorkspaceVscodePath)
}

if (-not (Test-Path -LiteralPath $resolvedGlobalVscodeUserPath -PathType Container)) {
    Add-ValidationFailure ("Global VS Code user folder not found: {0}" -f $resolvedGlobalVscodeUserPath)
}

$reports = New-Object System.Collections.Generic.List[object]

$coreMappings = @(
    [pscustomobject]@{
        Name = 'settings template -> global settings'
        Source = Join-Path $resolvedWorkspaceVscodePath 'settings.tamplate.jsonc'
        Target = Join-Path $resolvedGlobalVscodeUserPath 'settings.json'
    },
    [pscustomobject]@{
        Name = 'MCP template -> global MCP'
        Source = Join-Path $resolvedWorkspaceVscodePath 'mcp.tamplate.jsonc'
        Target = Join-Path $resolvedGlobalVscodeUserPath 'mcp.json'
    }
)

foreach ($mapping in $coreMappings) {
    $reports.Add((Invoke-FileContainmentCheck -Name $mapping.Name -SourceFilePath $mapping.Source -TargetFilePath $mapping.Target)) | Out-Null
}

if (-not $SkipSnippets) {
    $sourceSnippetsPath = Join-Path $resolvedWorkspaceVscodePath 'snippets'
    $targetSnippetsPath = Join-Path $resolvedGlobalVscodeUserPath 'snippets'

    if (-not (Test-Path -LiteralPath $sourceSnippetsPath -PathType Container)) {
        Add-ValidationFailure ("Workspace snippet folder not found: {0}" -f $sourceSnippetsPath)
    }
    else {
        $snippetFiles = @(Get-ChildItem -LiteralPath $sourceSnippetsPath -File -Filter '*.tamplate.code-snippets' | Sort-Object Name)
        foreach ($snippetFile in $snippetFiles) {
            $targetSnippetName = Get-GlobalSnippetFileName -TemplateFileName $snippetFile.Name
            $targetSnippetFile = Join-Path $targetSnippetsPath $targetSnippetName
            $mappingName = ("snippet template -> global snippet ({0} -> {1})" -f $snippetFile.Name, $targetSnippetName)
            $reports.Add((Invoke-FileContainmentCheck -Name $mappingName -SourceFilePath $snippetFile.FullName -TargetFilePath $targetSnippetFile)) | Out-Null
        }
    }
}

Write-StyledOutput 'VS Code global alignment summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Workspace .vscode: {0}" -f $resolvedWorkspaceVscodePath)
Write-StyledOutput ("  Global VS Code User: {0}" -f $resolvedGlobalVscodeUserPath)
Write-StyledOutput ("  Snippet check enabled: {0}" -f (-not $SkipSnippets))
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ''

foreach ($report in $reports) {
    Write-ContainmentReport -Report $report
}

$alignedCount = @($reports | Where-Object { $_.IsAligned }).Count
$driftCount = @($reports | Where-Object { -not $_.IsAligned }).Count

Write-StyledOutput ''
Write-StyledOutput 'VS Code global alignment totals'
Write-StyledOutput ("  Mappings checked: {0}" -f $reports.Count)
Write-StyledOutput ("  Aligned: {0}" -f $alignedCount)
Write-StyledOutput ("  Drifted: {0}" -f $driftCount)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($driftCount -eq 0 -and $script:Failures.Count -eq 0 -and $script:Warnings.Count -eq 0) {
    Write-StyledOutput 'VS Code global alignment passed.'
}
else {
    Write-StyledOutput 'VS Code global alignment completed with warnings.'
}

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

exit 0