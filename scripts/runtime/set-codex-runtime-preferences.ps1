<#
.SYNOPSIS
    Applies safe local Codex runtime preferences to config.toml.

.DESCRIPTION
    Updates only the repository-managed Codex runtime preference keys that are
    safe and directly related to runaway session growth:
    - `model_reasoning_effort`
    - `[features].multi_agent`

    The script preserves unrelated config content, supports preview mode, and
    resolves default values from the versioned
    `.github/governance/codex-runtime-hygiene.catalog.json` contract.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing
    `.github` and `.codex`.

.PARAMETER TargetConfigPath
    Optional target config path. Defaults to `<codexRuntimeRoot>/config.toml`.

.PARAMETER ReasoningEffort
    Optional reasoning effort override. Supported values: `low`, `medium`,
    `high`, `xhigh`. When omitted, the catalog default is used.

.PARAMETER MultiAgentMode
    Optional multi-agent mode override. Supported values are `enabled` and
    `disabled`. When omitted, the catalog default is used.

.PARAMETER CreateBackup
    Creates a timestamped backup before writing the target config.

.PARAMETER PreviewOnly
    Prints the resolved preference plan without writing changes.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/set-codex-runtime-preferences.ps1

.EXAMPLE
    pwsh -File scripts/runtime/set-codex-runtime-preferences.ps1 -CreateBackup

.EXAMPLE
    pwsh -File scripts/runtime/set-codex-runtime-preferences.ps1 -ReasoningEffort medium -MultiAgentMode disabled -PreviewOnly

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetConfigPath,
    [ValidateSet('low', 'medium', 'high', 'xhigh')]
    [string] $ReasoningEffort,
    [ValidateSet('enabled', 'disabled')]
    [string] $MultiAgentMode,
    [switch] $CreateBackup,
    [switch] $PreviewOnly,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'codex-runtime-hygiene')
$script:IsVerboseEnabled = [bool] $Verbose

# Writes verbose diagnostics when enabled.
function Write-PreferenceVerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[DETAIL] {0}" -f $Message)
    }
}

# Returns an optional property value from a parsed line descriptor.
function Get-LineDescriptorValue {
    param(
        [object] $Descriptor,
        [string] $PropertyName
    )

    if ($null -eq $Descriptor) {
        return $null
    }

    $property = $Descriptor.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

# Parses config lines into section-aware descriptors.
function Get-ConfigLineDescriptors {
    param(
        [string[]] $Lines
    )

    $descriptors = New-Object System.Collections.Generic.List[object]
    $currentSection = ''

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = [string] $Lines[$index]
        $trimmed = $line.Trim()

        if ($trimmed -match '^\[(.+)\]\s*$') {
            $currentSection = [string] $Matches[1]
            $descriptors.Add([pscustomobject]@{
                    Index   = $index
                    Section = $currentSection
                    Type    = 'section'
                    Key     = $null
                    Value   = $null
                }) | Out-Null
            continue
        }

        if ($trimmed -match '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
            $descriptors.Add([pscustomobject]@{
                    Index   = $index
                    Section = $currentSection
                    Type    = 'key'
                    Key     = [string] $Matches[1]
                    Value   = [string] $Matches[2]
                }) | Out-Null
            continue
        }

        $descriptors.Add([pscustomobject]@{
                Index   = $index
                Section = $currentSection
                Type    = 'other'
                Key     = $null
                Value   = $null
            }) | Out-Null
    }

    return @($descriptors.ToArray())
}

# Ensures a top-level TOML key exists with the desired value.
function Set-TopLevelTomlKey {
    param(
        [System.Collections.Generic.List[string]] $Lines,
        [string] $Key,
        [string] $RenderedValue
    )

    $descriptors = @(Get-ConfigLineDescriptors -Lines @($Lines.ToArray()))
    foreach ($descriptor in $descriptors) {
        if (($descriptor.Type -eq 'key') -and ([string] $descriptor.Section -eq '') -and ([string] $descriptor.Key -eq $Key)) {
            $existingLine = $Lines[[int] $descriptor.Index]
            $newLine = ('{0} = {1}' -f $Key, $RenderedValue)
            if ($existingLine -cne $newLine) {
                $Lines[[int] $descriptor.Index] = $newLine
                return $true
            }

            return $false
        }
    }

    $insertIndex = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -match '^\[') {
            $insertIndex = $i
            break
        }

        $insertIndex = $i + 1
    }

    if (($insertIndex -gt 0) -and (-not [string]::IsNullOrWhiteSpace($Lines[$insertIndex - 1]))) {
        $Lines.Insert($insertIndex, '')
        $insertIndex++
    }

    $Lines.Insert($insertIndex, ('{0} = {1}' -f $Key, $RenderedValue))
    return $true
}

# Ensures a section-scoped TOML key exists with the desired value.
function Set-SectionTomlKey {
    param(
        [System.Collections.Generic.List[string]] $Lines,
        [string] $SectionName,
        [string] $Key,
        [string] $RenderedValue
    )

    $descriptors = @(Get-ConfigLineDescriptors -Lines @($Lines.ToArray()))
    $sectionDescriptor = $descriptors | Where-Object { ($_.Type -eq 'section') -and ([string] $_.Section -eq $SectionName) } | Select-Object -First 1

    if ($null -eq $sectionDescriptor) {
        if (($Lines.Count -gt 0) -and (-not [string]::IsNullOrWhiteSpace($Lines[$Lines.Count - 1]))) {
            $Lines.Add('') | Out-Null
        }

        $Lines.Add(('[{0}]' -f $SectionName)) | Out-Null
        $Lines.Add(('{0} = {1}' -f $Key, $RenderedValue)) | Out-Null
        return $true
    }

    $sectionIndex = [int] $sectionDescriptor.Index
    $nextSectionIndex = $Lines.Count
    foreach ($descriptor in $descriptors) {
        if (($descriptor.Type -eq 'section') -and ([int] $descriptor.Index -gt $sectionIndex)) {
            $nextSectionIndex = [int] $descriptor.Index
            break
        }
    }

    foreach ($descriptor in $descriptors) {
        if (($descriptor.Type -eq 'key') -and ([string] $descriptor.Section -eq $SectionName) -and ([string] $descriptor.Key -eq $Key)) {
            $existingLine = $Lines[[int] $descriptor.Index]
            $newLine = ('{0} = {1}' -f $Key, $RenderedValue)
            if ($existingLine -cne $newLine) {
                $Lines[[int] $descriptor.Index] = $newLine
                return $true
            }

            return $false
        }
    }

    $insertIndex = $nextSectionIndex
    if (($insertIndex -gt ($sectionIndex + 1)) -and (-not [string]::IsNullOrWhiteSpace($Lines[$insertIndex - 1]))) {
        $Lines.Insert($insertIndex, '')
        $insertIndex++
    }

    $Lines.Insert($insertIndex, ('{0} = {1}' -f $Key, $RenderedValue))
    return $true
}

$resolvedRepoRoot = $null
try {
    $resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
}
catch {
    Write-PreferenceVerboseLog ("Repository root could not be resolved from the current location. Falling back to mirrored runtime governance. {0}" -f $_.Exception.Message)
}
$hygieneSettings = Get-CodexRuntimeHygieneSettings -ResolvedRepoRoot $resolvedRepoRoot

if ([string]::IsNullOrWhiteSpace($TargetConfigPath)) {
    $TargetConfigPath = Join-Path (Resolve-CodexRuntimePath) 'config.toml'
}

$resolvedTargetConfigPath = if (Test-Path -LiteralPath $TargetConfigPath -PathType Leaf) {
    (Resolve-Path -LiteralPath $TargetConfigPath).Path
}
else {
    [System.IO.Path]::GetFullPath($TargetConfigPath)
}

if (-not (Test-Path -LiteralPath $resolvedTargetConfigPath -PathType Leaf)) {
    throw ("Target Codex config not found: {0}" -f $resolvedTargetConfigPath)
}

$effectiveReasoningEffort = if ([string]::IsNullOrWhiteSpace($ReasoningEffort)) { [string] $hygieneSettings.ReasoningEffort } else { $ReasoningEffort }
$effectiveMultiAgentMode = if ([string]::IsNullOrWhiteSpace($MultiAgentMode)) { [string] $hygieneSettings.MultiAgentMode } else { $MultiAgentMode }
$renderedReasoningEffort = ('"{0}"' -f $effectiveReasoningEffort)
$renderedMultiAgentValue = if ($effectiveMultiAgentMode -eq 'enabled') { 'true' } else { 'false' }

$lines = New-Object System.Collections.Generic.List[string]
foreach ($line in (Get-Content -LiteralPath $resolvedTargetConfigPath)) {
    $lines.Add([string] $line) | Out-Null
}

$reasoningChanged = Set-TopLevelTomlKey -Lines $lines -Key 'model_reasoning_effort' -RenderedValue $renderedReasoningEffort
$multiAgentChanged = Set-SectionTomlKey -Lines $lines -SectionName 'features' -Key 'multi_agent' -RenderedValue $renderedMultiAgentValue
$requiresWrite = $reasoningChanged -or $multiAgentChanged

Write-StyledOutput 'Codex runtime preference plan'
Write-StyledOutput ("  TargetConfigPath: {0}" -f $resolvedTargetConfigPath)
Write-StyledOutput ("  CatalogPath: {0}" -f $hygieneSettings.CatalogPath)
Write-StyledOutput ("  ReasoningEffort: {0}" -f $effectiveReasoningEffort)
Write-StyledOutput ("  MultiAgentMode: {0}" -f $effectiveMultiAgentMode)
Write-StyledOutput ("  Mode: {0}" -f ($(if ($PreviewOnly) { 'preview' } else { 'apply' })))
Write-PreferenceVerboseLog ("Reasoning key changed: {0}" -f $reasoningChanged)
Write-PreferenceVerboseLog ("Multi-agent key changed: {0}" -f $multiAgentChanged)

if ($PreviewOnly) {
    Write-StyledOutput ''
    Write-StyledOutput ("  WouldWriteChanges: {0}" -f $requiresWrite)
    exit 0
}

if (-not $requiresWrite) {
    Write-StyledOutput ''
    Write-StyledOutput 'Codex runtime preferences already match the desired safe defaults.'
    exit 0
}

if ($CreateBackup) {
    $backupPath = '{0}.bak.{1}' -f $resolvedTargetConfigPath, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -LiteralPath $resolvedTargetConfigPath -Destination $backupPath -Force
    Write-StyledOutput ("Backup: {0}" -f $backupPath)
}

[System.IO.File]::WriteAllLines($resolvedTargetConfigPath, @($lines.ToArray()))
Write-StyledOutput ("Updated: {0}" -f $resolvedTargetConfigPath)
Write-StyledOutput 'Applied safe Codex runtime preferences.'
exit 0