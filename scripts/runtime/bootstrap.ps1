<#
.SYNOPSIS
    Syncs repository-managed .github and .codex assets into the local runtime folders.

.DESCRIPTION
    Detects the repository root and copies shared assets to:
    - <user-home>/.github
    - <user-home>/.github/scripts
    - <user-home>/.agents/skills
    - <user-home>/.codex/shared-mcp
    - <user-home>/.codex/shared-scripts
    - <user-home>/.codex/shared-orchestration

    Runtime .github/scripts are synchronized from:
    - scripts (repository root scripts)

    Shared-scripts are synchronized from:
    - .codex/scripts (MCP utility scripts and docs)
    - scripts/common (shared PowerShell helpers)
    - scripts/security (shared security audit gates)
    - scripts/maintenance (repository-owned maintenance helpers)

    When -ApplyMcpConfig is specified, applies MCP servers from the shared manifest
    into the local Codex config.toml file.

.PARAMETER RepoRoot
    Optional repository root. If omitted, the script detects root from the script location.

.PARAMETER TargetGithubPath
    Target path for .github runtime assets. Defaults to <user-home>/.github.

.PARAMETER TargetCodexPath
    Target path for .codex runtime assets other than picker-visible skills. Defaults to <user-home>/.codex.

.PARAMETER TargetAgentsSkillsPath
    Target path for picker-visible local skills. Defaults to <user-home>/.agents/skills.

.PARAMETER TargetCopilotSkillsPath
    Target path for the GitHub Copilot native skill root. The repository-owned
    bootstrap uses this path only to remove legacy duplicate
    starter/controller folders such as `super-agent` and `using-super-agent`.

.PARAMETER RuntimeProfile
    Runtime activation profile. Supported values are defined in
    `.github/governance/runtime-install-profiles.json`. Defaults to `all`
    when bootstrap is invoked directly.

.PARAMETER Mirror
    Mirrors target folders (removes files not present in source) when supported by the sync mode.

.PARAMETER ApplyMcpConfig
    Applies mcp_servers blocks from .codex/mcp/servers.manifest.json into target config.toml.

.PARAMETER BackupConfig
    Creates backup before applying MCP config (used with -ApplyMcpConfig).

.PARAMETER Verbose
    Shows detailed sync diagnostics.

.EXAMPLE
    pwsh -File ./scripts/runtime/bootstrap.ps1

.EXAMPLE
    pwsh -File ./scripts/runtime/bootstrap.ps1 -Mirror

.EXAMPLE
    pwsh -File ./scripts/runtime/bootstrap.ps1 -ApplyMcpConfig -BackupConfig

.NOTES
    Version: 1.4
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath,
    [string] $TargetCodexPath,
    [string] $TargetAgentsSkillsPath,
    [string] $TargetCopilotSkillsPath,
    [string] $RuntimeProfile,
    [switch] $Mirror,
    [switch] $ApplyMcpConfig,
    [switch] $BackupConfig,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'runtime-install-profiles', 'runtime-execution-context')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:RobocopyCommand = Get-Command -Name 'robocopy' -ErrorAction SilentlyContinue
$script:RobocopyBaseArgs = @(
    '/R:2',
    '/W:1',
    '/NFL',
    '/NDL',
    '/NJH',
    '/NJS',
    '/MT:8'
)

# -------------------------------
# Helpers
# -------------------------------
# Validates that a required file path exists before execution continues.
function Assert-PathPresent {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("Missing {0}: {1}" -f $Label, $Path)
    }
}

# Synchronizes directories with Copy-Item when robocopy is unavailable.
function Invoke-FallbackSync {
    param(
        [string] $Source,
        [string] $Destination,
        [switch] $MirrorMode
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    if ($MirrorMode -and (Test-Path -LiteralPath $Destination)) {
        Get-ChildItem -LiteralPath $Destination -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $sourceItems = Get-ChildItem -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    foreach ($item in $sourceItems) {
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

# Invokes robocopy with the shared repository sync defaults.
function Invoke-RobocopySync {
    param(
        [string] $Source,
        [string] $Destination,
        [switch] $MirrorMode,
        [string[]] $AdditionalArgs
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $mode = if ($MirrorMode) { '/MIR' } else { '/E' }
    $robocopyArgs = @(
        $Source,
        $Destination,
        $mode
    ) + $script:RobocopyBaseArgs

    if (@($AdditionalArgs).Count -gt 0) {
        $robocopyArgs += $AdditionalArgs
    }

    & $script:RobocopyCommand.Source @robocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed for '$Source' -> '$Destination' (exit code: $LASTEXITCODE)"
    }

    Write-VerboseColor ("Synced with robocopy: {0} -> {1}" -f $Source, $Destination) 'Gray'
}

# Synchronizes source and destination directories with robocopy or fallback mode.
function Invoke-DirectorySync {
    param(
        [string] $Source,
        [string] $Destination,
        [switch] $MirrorMode
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-VerboseColor ("Skipping missing source: {0}" -f $Source) 'Yellow'
        return
    }

    if ($null -ne $script:RobocopyCommand) {
        Invoke-RobocopySync -Source $Source -Destination $Destination -MirrorMode:$MirrorMode
        return
    }

    Write-VerboseColor 'robocopy not found; using Copy-Item fallback sync.' 'Yellow'
    Invoke-FallbackSync -Source $Source -Destination $Destination -MirrorMode:$MirrorMode
    Write-VerboseColor ("Synced with fallback copy: {0} -> {1}" -f $Source, $Destination) 'Gray'
}

# Returns repository-managed skill directory names from the versioned source root.
function Get-ManagedSkillNameList {
    param(
        [string] $SourceRoot
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $SourceRoot -Directory -Force | Select-Object -ExpandProperty Name | Sort-Object -Unique)
}

# Synchronizes repository-owned skill directories into the local `.agents/skills` picker path.
function Invoke-AgentsSkillSync {
    param(
        [string] $SourceRoot,
        [string] $DestinationRoot,
        [switch] $MirrorMode
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        Write-VerboseColor ("Skipping missing agents skill source root: {0}" -f $SourceRoot) 'Yellow'
        return
    }

    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null

    if ($null -ne $script:RobocopyCommand) {
        Invoke-RobocopySync -Source $SourceRoot -Destination $DestinationRoot -MirrorMode:$MirrorMode -AdditionalArgs @('/XF', 'README.md')

        $destinationReadme = Join-Path $DestinationRoot 'README.md'
        if (Test-Path -LiteralPath $destinationReadme -PathType Leaf) {
            Remove-Item -LiteralPath $destinationReadme -Force -ErrorAction Stop
        }

        return
    }

    $sourceSkillDirectories = @(Get-ChildItem -LiteralPath $SourceRoot -Directory -Force)
    foreach ($skillDirectory in $sourceSkillDirectories) {
        $targetSkillPath = Join-Path $DestinationRoot $skillDirectory.Name
        Invoke-DirectorySync -Source $skillDirectory.FullName -Destination $targetSkillPath -MirrorMode:$MirrorMode
    }
}

# Removes repository-managed skill duplicates from the local `.codex/skills` runtime root.
function Remove-ManagedCodexSkillDuplicates {
    param(
        [string] $ManagedSourceRoot,
        [string] $CodexSkillsRoot
    )

    if (-not (Test-Path -LiteralPath $CodexSkillsRoot -PathType Container)) {
        return
    }

    foreach ($skillName in (Get-ManagedSkillNameList -SourceRoot $ManagedSourceRoot)) {
        $duplicateSkillPath = Join-Path $CodexSkillsRoot $skillName
        if (Test-Path -LiteralPath $duplicateSkillPath) {
            Remove-Item -LiteralPath $duplicateSkillPath -Recurse -Force -ErrorAction Stop
        }
    }

    $managedReadme = Join-Path $ManagedSourceRoot 'README.md'
    $duplicateReadme = Join-Path $CodexSkillsRoot 'README.md'
    if ((Test-Path -LiteralPath $managedReadme -PathType Leaf) -and (Test-Path -LiteralPath $duplicateReadme -PathType Leaf)) {
        $managedHash = (Get-FileHash -LiteralPath $managedReadme -Algorithm SHA256).Hash
        $duplicateHash = (Get-FileHash -LiteralPath $duplicateReadme -Algorithm SHA256).Hash
        if ($managedHash -eq $duplicateHash) {
            Remove-Item -LiteralPath $duplicateReadme -Force -ErrorAction Stop
        }
    }
}

# Applies MCP manifest settings to target Codex config.toml.
function Invoke-McpConfigApply {
    param(
        [string] $ResolvedRepoRoot,
        [string] $CodexPath,
        [switch] $CreateBackup
    )

    $syncScript = Join-Path (Join-Path (Join-Path $ResolvedRepoRoot '.codex') 'scripts') 'sync-mcp-to-codex-config.ps1'
    $manifest = Join-Path (Join-Path (Join-Path $ResolvedRepoRoot '.codex') 'mcp') 'servers.manifest.json'
    $targetConfig = Join-Path $CodexPath 'config.toml'

    Assert-PathPresent -Path $syncScript -Label 'MCP sync script'
    Assert-PathPresent -Path $manifest -Label 'MCP manifest'
    Assert-PathPresent -Path $targetConfig -Label 'target Codex config'

    $syncArgs = @{
        ManifestPath = $manifest
        TargetConfigPath = $targetConfig
    }

    if ($CreateBackup) {
        $syncArgs.CreateBackup = $true
    }

    & $syncScript @syncArgs
}

# -------------------------------
# Main execution
# -------------------------------
$runtimeContext = Resolve-RuntimeExecutionContext `
    -RequestedRepoRoot $RepoRoot `
    -ProfileName $RuntimeProfile `
    -FallbackProfileName 'all' `
    -RequestedTargetGithubPath $TargetGithubPath `
    -RequestedTargetCodexPath $TargetCodexPath `
    -RequestedTargetAgentsSkillsPath $TargetAgentsSkillsPath `
    -RequestedTargetCopilotSkillsPath $TargetCopilotSkillsPath

$resolvedRepoRoot = $runtimeContext.ResolvedRepoRoot
$resolvedRuntimeProfile = $runtimeContext.RuntimeProfile
$effectiveRuntimeLocations = $runtimeContext.EffectiveRuntimeLocations
$TargetGithubPath = $runtimeContext.Targets.GithubRuntimeRoot
$TargetCodexPath = $runtimeContext.Targets.CodexRuntimeRoot
$TargetAgentsSkillsPath = $runtimeContext.Targets.AgentsSkillsRoot
$TargetCopilotSkillsPath = $runtimeContext.Targets.CopilotSkillsRoot
$sourceGithub = $runtimeContext.Sources.GithubRoot
$sourceCodex = $runtimeContext.Sources.CodexRoot
$sourceScripts = $runtimeContext.Sources.ScriptsRoot
$sourceCodexScripts = $runtimeContext.Sources.CodexScriptsRoot
$sourceCommonScripts = $runtimeContext.Sources.CommonScriptsRoot
$sourceSecurityScripts = $runtimeContext.Sources.SecurityScriptsRoot
$sourceMaintenanceScripts = $runtimeContext.Sources.MaintenanceScriptsRoot

Set-Location -Path $resolvedRepoRoot
Start-ExecutionSession `
    -Name 'runtime-bootstrap' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Runtime profile' = $resolvedRuntimeProfile.Name
            'Mirror mode' = [bool] $Mirror
            'Apply MCP config' = [bool] $ApplyMcpConfig
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

Assert-PathPresent -Path $sourceGithub -Label 'source .github folder'
Assert-PathPresent -Path $sourceCodex -Label 'source .codex folder'
Assert-PathPresent -Path $sourceScripts -Label 'source scripts folder'

if ($ApplyMcpConfig -and -not $resolvedRuntimeProfile.EnableCodexRuntime) {
    throw ("Runtime profile '{0}' does not enable the Codex runtime surface required by -ApplyMcpConfig." -f $resolvedRuntimeProfile.Name)
}

# Removes legacy repository-managed starter/controller skills from runtime
# roots that should no longer surface duplicate visible Copilot starters.
function Remove-LegacyStarterSkillDuplicates {
    param(
        [string[]] $SkillRoots
    )

    foreach ($skillRoot in @($SkillRoots)) {
        if ([string]::IsNullOrWhiteSpace($skillRoot)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
            continue
        }

        foreach ($skillName in @('super-agent', 'using-super-agent')) {
            $candidatePath = Join-Path $skillRoot $skillName
            if (Test-Path -LiteralPath $candidatePath) {
                Remove-Item -LiteralPath $candidatePath -Recurse -Force -ErrorAction Stop
                Write-VerboseColor ("Removed legacy starter skill duplicate: {0}" -f $candidatePath) 'Gray'
            }
        }
    }
}

if ($resolvedRuntimeProfile.EnableGithubRuntime) {
    Invoke-DirectorySync -Source $sourceGithub -Destination $TargetGithubPath -MirrorMode:$Mirror
    Invoke-DirectorySync -Source $sourceScripts -Destination (Join-Path $TargetGithubPath 'scripts') -MirrorMode:$Mirror
    Remove-LegacyStarterSkillDuplicates -SkillRoots @(
        (Join-Path $TargetGithubPath 'skills'),
        $TargetCopilotSkillsPath
    )
}
else {
    Write-VerboseColor ("Skipping GitHub runtime projection for profile '{0}'." -f $resolvedRuntimeProfile.Name) 'Yellow'
}

if ($resolvedRuntimeProfile.EnableCodexRuntime) {
    Invoke-AgentsSkillSync -SourceRoot $runtimeContext.Sources.CodexSkillsRoot -DestinationRoot $TargetAgentsSkillsPath -MirrorMode:$Mirror
    Remove-ManagedCodexSkillDuplicates -ManagedSourceRoot $runtimeContext.Sources.CodexSkillsRoot -CodexSkillsRoot (Join-Path $TargetCodexPath 'skills')
    Invoke-DirectorySync -Source $runtimeContext.Sources.CodexMcpRoot -Destination (Join-Path $TargetCodexPath 'shared-mcp') -MirrorMode:$Mirror
    Invoke-DirectorySync -Source $sourceCodexScripts -Destination (Join-Path $TargetCodexPath 'shared-scripts') -MirrorMode:$Mirror
    Invoke-DirectorySync -Source $sourceCommonScripts -Destination (Join-Path (Join-Path $TargetCodexPath 'shared-scripts') 'common') -MirrorMode:$Mirror
    Invoke-DirectorySync -Source $sourceSecurityScripts -Destination (Join-Path (Join-Path $TargetCodexPath 'shared-scripts') 'security') -MirrorMode:$Mirror
    Invoke-DirectorySync -Source $sourceMaintenanceScripts -Destination (Join-Path (Join-Path $TargetCodexPath 'shared-scripts') 'maintenance') -MirrorMode:$Mirror
    Invoke-DirectorySync -Source $runtimeContext.Sources.CodexOrchestrationRoot -Destination (Join-Path $TargetCodexPath 'shared-orchestration') -MirrorMode:$Mirror
}
else {
    Write-VerboseColor ("Skipping Codex runtime projection for profile '{0}'." -f $resolvedRuntimeProfile.Name) 'Yellow'
}

$sharedReadme = Join-Path $runtimeContext.Sources.CodexRoot 'README.md'
if ($resolvedRuntimeProfile.EnableCodexRuntime -and (Test-Path -LiteralPath $sharedReadme)) {
    New-Item -ItemType Directory -Path $TargetCodexPath -Force | Out-Null
    Copy-Item -LiteralPath $sharedReadme -Destination (Join-Path $TargetCodexPath 'README.shared.md') -Force
}

Write-StyledOutput 'Sync complete.'
Write-StyledOutput ("  runtime profile: {0}" -f $resolvedRuntimeProfile.Name)
Write-StyledOutput ("  profile catalog: {0}" -f $resolvedRuntimeProfile.CatalogPath)
Write-StyledOutput ("  runtime location catalog: {0}" -f $effectiveRuntimeLocations.catalogPath)
Write-StyledOutput ("  runtime location overrides: {0}" -f ($(if ($effectiveRuntimeLocations.settingsExists) { $effectiveRuntimeLocations.settingsPath } else { 'none' })))
if ($resolvedRuntimeProfile.EnableGithubRuntime) {
    Write-StyledOutput ("  .github -> {0}" -f $TargetGithubPath)
    Write-StyledOutput ("  scripts -> {0}" -f (Join-Path $TargetGithubPath 'scripts'))
    Write-StyledOutput ("  runtime legacy starter cleanup -> {0}, {1}" -f (Join-Path $TargetGithubPath 'skills'), $TargetCopilotSkillsPath)
}
else {
    Write-StyledOutput '  GitHub runtime surface: skipped'
}

if ($resolvedRuntimeProfile.EnableCodexRuntime) {
    Write-StyledOutput ("  .codex/skills (source only; runtime duplicates removed from {0})" -f (Join-Path $TargetCodexPath 'skills'))
    Write-StyledOutput ("  .agents/skills (canonical picker/runtime skills) -> {0}" -f $TargetAgentsSkillsPath)
    Write-StyledOutput ("  .codex/mcp -> {0}" -f (Join-Path $TargetCodexPath 'shared-mcp'))
    Write-StyledOutput ("  .codex/scripts + scripts/common + scripts/security + scripts/maintenance -> {0}" -f (Join-Path $TargetCodexPath 'shared-scripts'))
    Write-StyledOutput ("  .codex/orchestration -> {0}" -f (Join-Path $TargetCodexPath 'shared-orchestration'))
}
else {
    Write-StyledOutput '  Codex runtime surface: skipped'
}

if ($ApplyMcpConfig) {
    Invoke-McpConfigApply -ResolvedRepoRoot $resolvedRepoRoot -CodexPath $TargetCodexPath -CreateBackup:$BackupConfig
}
Complete-ExecutionSession -Name 'runtime-bootstrap' -Status 'passed' -Summary ([ordered]@{
        'GitHub runtime enabled' = [bool] $resolvedRuntimeProfile.EnableGithubRuntime
        'Codex runtime enabled' = [bool] $resolvedRuntimeProfile.EnableCodexRuntime
        'MCP config applied' = [bool] $ApplyMcpConfig
    }) | Out-Null

exit 0