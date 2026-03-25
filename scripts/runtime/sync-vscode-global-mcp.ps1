<#
.SYNOPSIS
    Renders the repository-managed VS Code MCP template into the global user profile.

.DESCRIPTION
    Uses `.github/governance/mcp-runtime.catalog.json` as the source of truth
    for the global VS Code `mcp.json` file and the tracked
    `.vscode/mcp.tamplate.jsonc` projection.

    Behavior:
    - reads the versioned template from the repository
    - renders runtime placeholders such as `%USERPROFILE%`
    - writes the rendered result to the global VS Code user profile
    - optionally refreshes `.vscode/mcp-vscode-global.json` as a machine-local
      rendered helper mirror
    - updates targets only when content changed
    - optionally creates a timestamped backup before overwriting the global file

.PARAMETER RepoRoot
    Optional repository root. If omitted, script detects a root containing .github and .codex.

.PARAMETER WorkspaceVscodePath
    Optional path to repository `.vscode` folder. Defaults to `<RepoRoot>/.vscode`.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user folder path. Default is OS-specific:
    - Windows: `%APPDATA%\Code\User`
    - macOS: `~/Library/Application Support/Code/User`
    - Linux: `$XDG_CONFIG_HOME/Code/User` or `~/.config/Code/User`

.PARAMETER WorkspaceHelperPath
    Optional path for the machine-local helper mirror. Defaults to
    `<WorkspaceVscodePath>/mcp-vscode-global.json`.

.PARAMETER CatalogPath
    Optional override path to the canonical MCP runtime catalog.

.PARAMETER ProfilePath
    Optional path to one `.vscode/profiles/profile-*.json` file. When supplied,
    the profile `mcp.servers.<name>.enabled` map is applied on top of the MCP
    template before writing the global VS Code MCP file and the local helper mirror.

.PARAMETER SyncWorkspaceHelper
    When true (default), refreshes `.vscode/mcp-vscode-global.json` from the
    same rendered template used for the global VS Code MCP file.

.PARAMETER CreateBackup
    Creates a timestamped backup of the current global `mcp.json` before overwriting.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-mcp.ps1

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-mcp.ps1 -CreateBackup

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-mcp.ps1 -SyncWorkspaceHelper:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $WorkspaceVscodePath,
    [string] $GlobalVscodeUserPath,
    [string] $WorkspaceHelperPath,
    [string] $CatalogPath,
    [string] $ProfilePath,
    [bool] $SyncWorkspaceHelper = $true,
    [switch] $CreateBackup,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'vscode-runtime-hygiene', 'mcp-runtime-catalog')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose

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

# Resolves the local helper mirror path.
function Resolve-WorkspaceHelperPath {
    param(
        [string] $ResolvedWorkspaceVscodePath,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Join-Path $ResolvedWorkspaceVscodePath 'mcp-vscode-global.json'
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedWorkspaceVscodePath $RequestedPath))
}

# Returns true when normalized text contents match.
function Test-TextContentMatch {
    param(
        [string] $ExpectedContent,
        [string] $TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return $false
    }

    $targetContent = Get-Content -Raw -LiteralPath $TargetPath
    $normalizedExpected = $ExpectedContent.Replace("`r`n", "`n")
    $normalizedTarget = $targetContent.Replace("`r`n", "`n")
    return [string]::Equals($normalizedExpected, $normalizedTarget, [System.StringComparison]::Ordinal)
}

# Resolves an optional profile definition path.
function Resolve-ProfilePath {
    param(
        [string] $ResolvedWorkspaceVscodePath,
        [string] $RequestedPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
        return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ResolvedWorkspaceVscodePath $RequestedPath))
}

# Renders catalog placeholders into runtime-safe text.
function Get-RenderedMcpTemplate {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Catalog,
        [string] $ResolvedProfilePath
    )

    $templateDocument = Convert-McpRuntimeCatalogToVscodeDocument -Catalog $Catalog
    $effectiveDocument = Merge-McpProfileSelection -TemplateDocument $templateDocument -ResolvedProfilePath $ResolvedProfilePath
    $templateContent = $effectiveDocument | ConvertTo-Json -Depth 100
    $userHome = Resolve-VscodeRuntimeHomePath
    $escapedUserHome = $userHome.Replace('\', '\\')

    return $templateContent.Replace('%USERPROFILE%', $escapedUserHome)
}

# Creates a timestamped backup for the existing MCP file.
function New-McpBackup {
    param(
        [string] $TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return $null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = '{0}.{1}.bak' -f $TargetPath, $timestamp
    Copy-Item -LiteralPath $TargetPath -Destination $backupPath -Force
    return $backupPath
}

# Writes rendered content only when target drift exists.
function Sync-RenderedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $TargetPath,
        [Parameter(Mandatory = $true)]
        [string] $RenderedContent,
        [switch] $CreateBackup
    )

    $targetDirectory = Split-Path -Path $TargetPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    }

    if (Test-TextContentMatch -ExpectedContent $RenderedContent -TargetPath $TargetPath) {
        return [pscustomobject]@{
            Updated = $false
            BackupPath = $null
        }
    }

    $backupPath = $null
    if ($CreateBackup) {
        $backupPath = New-McpBackup -TargetPath $TargetPath
    }

    Set-Content -LiteralPath $TargetPath -Value $RenderedContent -Encoding UTF8
    return [pscustomobject]@{
        Updated = $true
        BackupPath = $backupPath
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$resolvedWorkspaceVscodePath = Resolve-WorkspaceVscodePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $WorkspaceVscodePath
$resolvedGlobalVscodeUserPath = Resolve-GlobalVscodeUserPath -RequestedPath $GlobalVscodeUserPath
$resolvedWorkspaceHelperPath = Resolve-WorkspaceHelperPath -ResolvedWorkspaceVscodePath $resolvedWorkspaceVscodePath -RequestedPath $WorkspaceHelperPath
$resolvedProfilePath = Resolve-ProfilePath -ResolvedWorkspaceVscodePath $resolvedWorkspaceVscodePath -RequestedPath $ProfilePath
$catalogInfo = Read-McpRuntimeCatalog -RepoRoot $resolvedRepoRoot -CatalogPath $CatalogPath
$sourceTemplatePath = Join-Path $resolvedWorkspaceVscodePath 'mcp.tamplate.jsonc'
$targetMcpPath = Join-Path $resolvedGlobalVscodeUserPath 'mcp.json'

New-Item -ItemType Directory -Path $resolvedGlobalVscodeUserPath -Force | Out-Null

$renderedContent = Get-RenderedMcpTemplate -Catalog $catalogInfo.Catalog -ResolvedProfilePath $resolvedProfilePath
$globalResult = Sync-RenderedFile -TargetPath $targetMcpPath -RenderedContent $renderedContent -CreateBackup:$CreateBackup
$helperResult = $null

if ($SyncWorkspaceHelper) {
    $helperResult = Sync-RenderedFile -TargetPath $resolvedWorkspaceHelperPath -RenderedContent $renderedContent
}

if ($globalResult.Updated) {
    Write-StyledOutput ("[OK] Global MCP synchronized: {0}" -f $targetMcpPath)
}
else {
    Write-StyledOutput ("[SKIP] Global MCP already aligned: {0}" -f $targetMcpPath)
}

if ($SyncWorkspaceHelper) {
    if ($helperResult.Updated) {
        Write-StyledOutput ("[OK] Local MCP helper synchronized: {0}" -f $resolvedWorkspaceHelperPath)
    }
    else {
        Write-StyledOutput ("[SKIP] Local MCP helper already aligned: {0}" -f $resolvedWorkspaceHelperPath)
    }
}

Write-StyledOutput ''
Write-StyledOutput 'VS Code global MCP sync summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Source catalog: {0}" -f $catalogInfo.Path)
Write-StyledOutput ("  Tracked template: {0}" -f $sourceTemplatePath)
Write-StyledOutput ("  Profile override: {0}" -f $(if ($null -ne $resolvedProfilePath) { $resolvedProfilePath } else { 'none' }))
Write-StyledOutput ("  Target MCP: {0}" -f $targetMcpPath)
Write-StyledOutput ("  Sync workspace helper: {0}" -f $SyncWorkspaceHelper)
if ($SyncWorkspaceHelper) {
    Write-StyledOutput ("  Workspace helper: {0}" -f $resolvedWorkspaceHelperPath)
}
if ($null -ne $globalResult.BackupPath) {
    Write-StyledOutput ("  Backup: {0}" -f $globalResult.BackupPath)
}
Write-StyledOutput ("  Updated global MCP: {0}" -f ([int] $globalResult.Updated))
Write-StyledOutput ("  Updated workspace helper: {0}" -f $(if ($SyncWorkspaceHelper) { [int] $helperResult.Updated } else { 0 }))

exit 0