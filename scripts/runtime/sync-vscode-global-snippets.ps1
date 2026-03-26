<#
.SYNOPSIS
    Synchronizes repository-managed VS Code snippet files into the global user profile.

.DESCRIPTION
    Copies repository snippet templates from `.vscode/snippets/*.tamplate.code-snippets`
    into the global VS Code user snippet folder.

    Repository snippet files follow the same template convention used by `settings` and
    `mcp`. During synchronization, the script removes the `.tamplate` segment from the
    source file name and writes the final `.code-snippets` file into the global profile.

    Behavior:
    - creates the global `snippets` folder when missing
    - updates snippet files only when content changed
    - preserves unrelated global snippet files
    - maps `*.tamplate.code-snippets` -> `*.code-snippets`

.PARAMETER RepoRoot
    Optional repository root. If omitted, script detects a root containing .github and .codex.

.PARAMETER WorkspaceVscodePath
    Optional path to repository `.vscode` folder. Defaults to `<RepoRoot>/.vscode`.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user folder path. Default is OS-specific:
    - Windows: `%APPDATA%\Code\User`
    - macOS: `~/Library/Application Support/Code/User`
    - Linux: `$XDG_CONFIG_HOME/Code/User` or `~/.config/Code/User`

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-snippets.ps1

.EXAMPLE
    pwsh -File scripts/runtime/sync-vscode-global-snippets.ps1 -GlobalVscodeUserPath "C:\Users\me\AppData\Roaming\Code\User"

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $WorkspaceVscodePath,
    [string] $GlobalVscodeUserPath,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths')
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

# Compares two text files using normalized line endings.
function Test-FileContentMatch {
    param(
        [string] $SourcePath,
        [string] $TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return $false
    }

    $sourceContent = Get-Content -Raw -LiteralPath $SourcePath
    $targetContent = Get-Content -Raw -LiteralPath $TargetPath
    $normalizedSource = $sourceContent.Replace("`r`n", "`n")
    $normalizedTarget = $targetContent.Replace("`r`n", "`n")
    return [string]::Equals($normalizedSource, $normalizedTarget, [System.StringComparison]::Ordinal)
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

# Copies one snippet file when target is missing or outdated.
function Sync-SnippetFile {
    param(
        [System.IO.FileInfo] $SourceFile,
        [string] $TargetDirectory
    )

    $targetFileName = Get-GlobalSnippetFileName -TemplateFileName $SourceFile.Name
    $targetPath = Join-Path $TargetDirectory $targetFileName
    if (Test-FileContentMatch -SourcePath $SourceFile.FullName -TargetPath $targetPath) {
        Write-StyledOutput ("[SKIP] Global snippet already aligned: {0} -> {1}" -f $SourceFile.Name, $targetFileName) | Out-Null
        return 'skipped'
    }

    Copy-Item -LiteralPath $SourceFile.FullName -Destination $targetPath -Force
    Write-StyledOutput ("[OK] Global snippet synchronized: {0} -> {1}" -f $SourceFile.Name, $targetFileName) | Out-Null
    return 'updated'
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$renderScriptPath = Join-Path $resolvedRepoRoot 'scripts\runtime\render-vscode-workspace-surfaces.ps1'
if (-not (Test-Path -LiteralPath $renderScriptPath -PathType Leaf)) {
    throw "Missing VS Code workspace renderer: $renderScriptPath"
}
& $renderScriptPath -RepoRoot $resolvedRepoRoot -Verbose:$script:IsVerboseEnabled | Out-Null
$renderExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
if ($renderExitCode -ne 0) {
    throw ("VS Code workspace render failed before snippet sync. ExitCode={0}" -f $renderExitCode)
}

$resolvedWorkspaceVscodePath = Resolve-WorkspaceVscodePath -ResolvedRepoRoot $resolvedRepoRoot -RequestedPath $WorkspaceVscodePath
$resolvedGlobalVscodeUserPath = Resolve-GlobalVscodeUserPath -RequestedPath $GlobalVscodeUserPath
$sourceSnippetsPath = Join-Path $resolvedWorkspaceVscodePath 'snippets'
$targetSnippetsPath = Join-Path $resolvedGlobalVscodeUserPath 'snippets'

if (-not (Test-Path -LiteralPath $sourceSnippetsPath -PathType Container)) {
    throw "Workspace snippet folder not found: $sourceSnippetsPath"
}

New-Item -ItemType Directory -Path $targetSnippetsPath -Force | Out-Null

$sourceFiles = @(Get-ChildItem -LiteralPath $sourceSnippetsPath -Filter '*.tamplate.code-snippets' -File | Sort-Object Name)
if ($sourceFiles.Count -eq 0) {
    throw "No snippet template files found in: $sourceSnippetsPath"
}

$updatedCount = 0
$skippedCount = 0

foreach ($sourceFile in $sourceFiles) {
    $result = Sync-SnippetFile -SourceFile $sourceFile -TargetDirectory $targetSnippetsPath
    switch ($result) {
        'updated' { $updatedCount++ }
        'skipped' { $skippedCount++ }
        default { throw "Failed to synchronize snippet: $($sourceFile.Name)" }
    }
}

Write-StyledOutput ''
Write-StyledOutput 'VS Code global snippet sync summary'
Write-StyledOutput ("  Repo root: {0}" -f $resolvedRepoRoot)
Write-StyledOutput ("  Source snippets: {0}" -f $sourceSnippetsPath)
Write-StyledOutput ("  Global snippets: {0}" -f $targetSnippetsPath)
Write-StyledOutput ("  Updated: {0}" -f $updatedCount)
Write-StyledOutput ("  Skipped: {0}" -f $skippedCount)

exit 0