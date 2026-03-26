<#
.SYNOPSIS
    Merges repository-owned Claude Code settings into the global Claude runtime settings.

.DESCRIPTION
    Reads .claude/settings.json from the repository, resolves %USERPROFILE% placeholders
    in all string values, computes the project memory path from the repository root, and
    merges permissions.allow and permissions.additionalDirectories into the global
    ~/.claude/settings.json — without overwriting unrelated global settings.

    The project memory path is computed by converting the resolved repo root to the Claude
    project slug format (lowercase drive, replace : and \ with -) so the correct machine-
    specific absolute path is always written, regardless of who cloned the repository.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected from script location when omitted.

.PARAMETER TargetClaudePath
    Optional target path for the global Claude runtime. Defaults to the
    catalog-resolved value from scripts/common/runtime-paths.ps1 (~/.claude).

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/sync-claude-settings.ps1

.EXAMPLE
    pwsh -File scripts/runtime/sync-claude-settings.ps1 -TargetClaudePath D:/ai-runtime/.claude

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetClaudePath,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '../common/common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '../../common/common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'runtime-execution-context', 'validation-logging')

$script:IsVerboseEnabled = [bool] $Verbose

Initialize-ExecutionIssueTracking

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$resolvedTargetClaudePath = if ([string]::IsNullOrWhiteSpace($TargetClaudePath)) {
    Resolve-ClaudeRuntimePath
}
else {
    $TargetClaudePath
}

$sourceSettingsPath = Join-Path $resolvedRepoRoot '.claude' 'settings.json'
$targetSettingsPath = Join-Path $resolvedTargetClaudePath 'settings.json'

Write-StyledOutput "[INFO] Source: $sourceSettingsPath" | Out-Host
Write-StyledOutput "[INFO] Target: $targetSettingsPath" | Out-Host

if (-not (Test-Path -LiteralPath $sourceSettingsPath -PathType Leaf)) {
    Write-StyledOutput '[SKIP] No .claude/settings.json found in repository. Nothing to merge.' | Out-Host
    exit 0
}

# Compute Claude project slug from repo root.
# Formula: lowercase drive letter, replace ':' with '-', replace '\' with '-'.
# Example: C:\Users\foo\my-repo -> c--Users-foo-my-repo
function Get-ClaudeProjectSlug {
    param([string] $Path)
    $normalized = $Path.TrimEnd('\', '/')
    # Lowercase drive letter only (first char), keep rest as-is
    if ($normalized.Length -ge 2 -and $normalized[1] -eq ':') {
        $normalized = $normalized[0].ToString().ToLowerInvariant() + $normalized.Substring(1)
    }
    return ($normalized -replace ':', '-') -replace '\\', '-'
}

$projectSlug = Get-ClaudeProjectSlug -Path $resolvedRepoRoot
$memoryPath = Join-Path $resolvedTargetClaudePath 'projects' $projectSlug 'memory'

if ($script:IsVerboseEnabled) {
    Write-StyledOutput "[INFO] Project slug: $projectSlug" | Out-Host
    Write-StyledOutput "[INFO] Memory path: $memoryPath" | Out-Host
}

# Resolve %USERPROFILE% and $env:USERPROFILE placeholders in a string value.
function Resolve-EnvPlaceholders {
    param([string] $Value)
    $userProfile = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($userProfile)) { $userProfile = $env:HOME }
    return $Value `
        -replace '%USERPROFILE%', $userProfile `
        -replace '\$env:USERPROFILE', $userProfile `
        -replace '\$HOME', $userProfile
}

# Read project settings
$sourceJson = Get-Content -LiteralPath $sourceSettingsPath -Raw -ErrorAction Stop
$sourceSettings = $sourceJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop

# Resolve %USERPROFILE% in all string values (recursive)
function Resolve-SettingValues {
    param([object] $Node)
    if ($Node -is [System.Collections.Generic.Dictionary[string, object]]) {
        $resolved = [System.Collections.Generic.Dictionary[string, object]]::new()
        foreach ($kv in $Node.GetEnumerator()) {
            $resolved[$kv.Key] = Resolve-SettingValues -Node $kv.Value
        }
        return $resolved
    }
    elseif ($Node -is [object[]]) {
        return @($Node | ForEach-Object { Resolve-SettingValues -Node $_ })
    }
    elseif ($Node -is [string]) {
        return Resolve-EnvPlaceholders -Value $Node
    }
    return $Node
}

$resolvedSettings = Resolve-SettingValues -Node $sourceSettings

# Read or initialize global settings
$globalSettings = [System.Collections.Generic.Dictionary[string, object]]::new()
if (Test-Path -LiteralPath $targetSettingsPath -PathType Leaf) {
    $existingJson = Get-Content -LiteralPath $targetSettingsPath -Raw -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($existingJson)) {
        $globalSettings = $existingJson | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
        if ($null -eq $globalSettings) {
            $globalSettings = [System.Collections.Generic.Dictionary[string, object]]::new()
        }
    }
}

# Ensure permissions block exists
if (-not $globalSettings.ContainsKey('permissions')) {
    $globalSettings['permissions'] = [System.Collections.Generic.Dictionary[string, object]]::new()
}
$globalPerms = $globalSettings['permissions']

# Merge permissions.allow (union, no duplicates)
$sourceAllow = @()
if ($resolvedSettings.ContainsKey('permissions') -and $resolvedSettings['permissions'].ContainsKey('allow')) {
    $sourceAllow = @($resolvedSettings['permissions']['allow'])
}
$existingAllow = @()
if ($globalPerms.ContainsKey('allow')) {
    $existingAllow = @($globalPerms['allow'])
}
$mergedAllow = @($existingAllow) + @($sourceAllow | Where-Object { $_ -notin $existingAllow })
if ($mergedAllow.Count -gt 0) {
    $globalPerms['allow'] = $mergedAllow
}

# Merge additionalDirectories — add computed memory path if not already present
$existingDirs = @()
if ($globalPerms.ContainsKey('additionalDirectories')) {
    $existingDirs = @($globalPerms['additionalDirectories'])
}
if ($memoryPath -notin $existingDirs) {
    $existingDirs = @($existingDirs) + @($memoryPath)
    Write-StyledOutput "[OK] Added memory directory: $memoryPath" | Out-Host
}
else {
    if ($script:IsVerboseEnabled) {
        Write-StyledOutput "[SKIP] Memory directory already present in global settings." | Out-Host
    }
}
$globalPerms['additionalDirectories'] = $existingDirs

# Write merged global settings
if (-not (Test-Path -LiteralPath $resolvedTargetClaudePath -PathType Container)) {
    New-Item -ItemType Directory -Path $resolvedTargetClaudePath -Force | Out-Null
}
$globalSettings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $targetSettingsPath -Encoding UTF8 -NoNewline
Write-StyledOutput "[DONE] Claude settings merged into: $targetSettingsPath" | Out-Host
Write-ExecutionLog -Level 'OK' -Message "Claude settings merged. Memory path: $memoryPath"