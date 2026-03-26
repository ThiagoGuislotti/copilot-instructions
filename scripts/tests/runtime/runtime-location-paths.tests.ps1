<#
.SYNOPSIS
    Validates shared runtime location resolution and override-aware bootstrap behavior.

.DESCRIPTION
    Covers the versioned runtime location catalog and the optional user-local
    override file used by runtime bootstrap and install flows.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/runtime-location-paths.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths', 'runtime-paths')

# Fails the current runtime test when the supplied condition is false.
function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

# Fails the current test when the actual and expected values differ.
function Assert-Equal {
    param(
        [object] $Actual,
        [object] $Expected,
        [string] $Message
    )

    if ($Actual -ne $Expected) {
        throw ("{0} Expected='{1}' Actual='{2}'" -f $Message, $Expected, $Actual)
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$bootstrapScriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'

$originalRuntimeSettingsPath = $env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))

try {
    $runtimeRoot = Join-Path $tempRoot 'portable-runtime'
    $githubRuntimeRoot = Join-Path $runtimeRoot 'github-runtime'
    $codexRuntimeRoot = Join-Path $runtimeRoot 'codex-runtime'
    $agentsSkillsRoot = Join-Path (Join-Path $runtimeRoot 'agents') 'skills'
    $copilotSkillsRoot = Join-Path (Join-Path $runtimeRoot 'copilot') 'skills'
    $codexGitHooksRoot = Join-Path $runtimeRoot 'git-hooks'
    $settingsPath = Join-Path $tempRoot 'runtime-location-settings.json'

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $settingsDocument = @{
        schemaVersion = 1
        paths = @{
            githubRuntimeRoot = $githubRuntimeRoot
            codexRuntimeRoot = $codexRuntimeRoot
            agentsSkillsRoot = $agentsSkillsRoot
            copilotSkillsRoot = $copilotSkillsRoot
            codexGitHooksRoot = $codexGitHooksRoot
        }
    } | ConvertTo-Json -Depth 20

    Set-Content -LiteralPath $settingsPath -Value $settingsDocument
    $env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH = $settingsPath

    $effectiveLocations = Get-EffectiveRuntimeLocations
    Assert-Equal -Actual $effectiveLocations.githubRuntimeRoot -Expected ([System.IO.Path]::GetFullPath($githubRuntimeRoot)) -Message 'Runtime location settings must override the default GitHub runtime root.'
    Assert-Equal -Actual $effectiveLocations.codexRuntimeRoot -Expected ([System.IO.Path]::GetFullPath($codexRuntimeRoot)) -Message 'Runtime location settings must override the default Codex runtime root.'
    Assert-Equal -Actual $effectiveLocations.agentsSkillsRoot -Expected ([System.IO.Path]::GetFullPath($agentsSkillsRoot)) -Message 'Runtime location settings must override the default agents skill root.'
    Assert-Equal -Actual $effectiveLocations.copilotSkillsRoot -Expected ([System.IO.Path]::GetFullPath($copilotSkillsRoot)) -Message 'Runtime location settings must override the default Copilot skill root.'
    Assert-Equal -Actual $effectiveLocations.codexGitHooksRoot -Expected ([System.IO.Path]::GetFullPath($codexGitHooksRoot)) -Message 'Runtime location settings must override the default global Git hooks root.'
    Assert-Equal -Actual $effectiveLocations.settingsPath -Expected ([System.IO.Path]::GetFullPath($settingsPath)) -Message 'Runtime location settings summary must expose the active override file.'

    New-Item -ItemType Directory -Path (Join-Path $githubRuntimeRoot 'skills\super-agent') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $githubRuntimeRoot 'skills\super-agent\SKILL.md') -Value 'legacy'
    New-Item -ItemType Directory -Path (Join-Path $copilotSkillsRoot 'super-agent') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $copilotSkillsRoot 'super-agent\SKILL.md') -Value 'legacy'

    & $bootstrapScriptPath -RepoRoot $resolvedRepoRoot -RuntimeProfile all -Mirror | Out-Null
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    Assert-True ($exitCode -eq 0) 'bootstrap must accept runtime location override settings without explicit target arguments.'
    Assert-True (Test-Path -LiteralPath (Join-Path $githubRuntimeRoot 'hooks/super-agent.bootstrap.json') -PathType Leaf) 'bootstrap must project the GitHub runtime into the override path.'
    Assert-True (Test-Path -LiteralPath (Join-Path $codexRuntimeRoot 'shared-scripts/maintenance/trim-trailing-blank-lines.ps1') -PathType Leaf) 'bootstrap must project Codex shared scripts into the override path.'
    Assert-True (Test-Path -LiteralPath (Join-Path $agentsSkillsRoot 'super-agent/SKILL.md') -PathType Leaf) 'bootstrap must project picker-visible skills into the override agents path.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $githubRuntimeRoot 'skills\super-agent'))) 'bootstrap must keep the override GitHub runtime skill root free of legacy managed super-agent starters.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $copilotSkillsRoot 'super-agent'))) 'bootstrap must keep the override Copilot skill root free of the legacy managed super-agent starter.'

    Write-Host '[OK] runtime location path tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] runtime location path tests failed: {0}" -f $_.Exception.Message)
    exit 1
}
finally {
    if ($null -eq $originalRuntimeSettingsPath) {
        Remove-Item Env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH -ErrorAction SilentlyContinue
    }
    else {
        $env:CODEX_RUNTIME_LOCATION_SETTINGS_PATH = $originalRuntimeSettingsPath
    }

    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}