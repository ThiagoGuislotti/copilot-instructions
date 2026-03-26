<#
.SYNOPSIS
    Synchronizes repository-owned Claude Code skills to the global Claude runtime.

.DESCRIPTION
    Renders versioned Claude skill definitions from the authoritative
    `definitions/providers/claude/skills/` tree into `.claude/skills/` and then
    copies the rendered surface to the global Claude Code runtime under
    `~/.claude/skills/` so the skills are available across all workspaces on
    this machine.

    Each skill is a subdirectory containing a SKILL.md file. The sync is
    additive: existing skill directories at the target that are not present
    in the source are not removed.

.PARAMETER RepoRoot
    Optional repository root. Auto-detected from script location when omitted.

.PARAMETER TargetClaudePath
    Optional target path for the global Claude runtime. Defaults to the
    catalog-resolved value from scripts/common/runtime-paths.ps1
    (~/.claude on most systems).

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/sync-claude-skills.ps1

.EXAMPLE
    pwsh -File scripts/runtime/sync-claude-skills.ps1 -TargetClaudePath D:/ai-runtime/.claude

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

$renderScriptPath = Join-Path $resolvedRepoRoot 'scripts\runtime\render-provider-skill-surfaces.ps1'
if (-not (Test-Path -LiteralPath $renderScriptPath -PathType Leaf)) {
    throw "Missing provider skill renderer: $renderScriptPath"
}

& $renderScriptPath -RepoRoot $resolvedRepoRoot -Provider 'claude' -Verbose:$script:IsVerboseEnabled | Out-Null
$renderExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
if ($renderExitCode -ne 0) {
    throw ("Claude skill render failed before sync. ExitCode={0}" -f $renderExitCode)
}

$sourceSkillsRoot = Join-Path $resolvedRepoRoot '.claude' 'skills'
$targetSkillsRoot = Join-Path $resolvedTargetClaudePath 'skills'

Write-StyledOutput "[INFO] Source: $sourceSkillsRoot" | Out-Host
Write-StyledOutput "[INFO] Target: $targetSkillsRoot" | Out-Host

if (-not (Test-Path -LiteralPath $sourceSkillsRoot -PathType Container)) {
    Write-StyledOutput '[SKIP] No .claude/skills/ directory found in repository. Nothing to sync.' | Out-Host
    exit 0
}

if (-not (Test-Path -LiteralPath $targetSkillsRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $targetSkillsRoot -Force | Out-Null
    Write-StyledOutput "[OK] Created target directory: $targetSkillsRoot" | Out-Host
}

$skillDirs = @(Get-ChildItem -LiteralPath $sourceSkillsRoot -Directory -ErrorAction SilentlyContinue)
$synced = 0
$skipped = 0

foreach ($skillDir in $skillDirs) {
    $skillFile = Join-Path $skillDir.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        if ($script:IsVerboseEnabled) {
            Write-StyledOutput "[SKIP] $($skillDir.Name): no SKILL.md found" | Out-Host
        }
        $skipped++
        continue
    }

    $targetSkillDir = Join-Path $targetSkillsRoot $skillDir.Name
    if (-not (Test-Path -LiteralPath $targetSkillDir -PathType Container)) {
        New-Item -ItemType Directory -Path $targetSkillDir -Force | Out-Null
    }

    $targetSkillFile = Join-Path $targetSkillDir 'SKILL.md'
    Copy-Item -LiteralPath $skillFile -Destination $targetSkillFile -Force
    Write-StyledOutput "[OK] Synced skill: $($skillDir.Name)" | Out-Host
    $synced++
}

Write-StyledOutput "[DONE] Claude skills sync complete. Synced: $synced, Skipped: $skipped" | Out-Host
Write-ExecutionLog -Level 'OK' -Message "Claude skills sync complete. Synced: $synced, Skipped: $skipped"