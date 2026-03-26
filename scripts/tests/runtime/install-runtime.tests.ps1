<#
.SYNOPSIS
    Runtime tests for the repository onboarding/install orchestrator without external frameworks.

.DESCRIPTION
    Covers preview planning behavior for `scripts/runtime/install.ps1`.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/install-runtime.tests.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('repository-paths')
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

# Fails the current test when the supplied script block does not throw.
function Assert-ThrowsLike {
    param(
        [scriptblock] $Action,
        [string] $ExpectedPattern,
        [string] $Message
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -match $ExpectedPattern) {
            return
        }

        throw ("{0} Expected pattern='{1}' Actual='{2}'" -f $Message, $ExpectedPattern, $_.Exception.Message)
    }

    throw $Message
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/runtime/install.ps1'

try {
    $previewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly

    Assert-True -Condition ($null -ne $previewResult) -Message 'Install preview must return a result object.'
    Assert-Equal -Actual $previewResult.previewOnly -Expected $true -Message 'Install preview must flag previewOnly.'
    Assert-Equal -Actual $previewResult.runtimeProfile.name -Expected 'none' -Message 'Install preview must default to the non-intrusive none profile.'
    Assert-True -Condition ($null -ne $previewResult.runtimeLocations) -Message 'Install preview must expose effective runtime locations.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string] $previewResult.runtimeLocations.catalogPath)) -Message 'Install preview must report the runtime location catalog path.'
    Assert-Equal -Actual @($previewResult.steps).Count -Expected 0 -Message 'Install preview must not plan any steps for the default none profile.'
    Assert-Equal -Actual $previewResult.summary.overallStatus -Expected 'preview' -Message 'Install preview must report preview summary status.'
    Assert-Equal -Actual $previewResult.issues.totalIssues -Expected 0 -Message 'Install preview must not report issues when only planning.'

    $allPreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -RuntimeProfile all

    Assert-Equal -Actual $allPreviewResult.runtimeProfile.name -Expected 'all' -Message 'Install preview must honor explicit all profile selection.'
    Assert-Equal -Actual @($allPreviewResult.steps).Count -Expected 10 -Message 'Install preview must plan the full onboarding steps for profile all.'
    Assert-Equal -Actual $allPreviewResult.steps[0].name -Expected 'Bootstrap shared runtime assets' -Message 'All-profile install preview must start with bootstrap.'
    Assert-Equal -Actual $allPreviewResult.steps[1].name -Expected 'Apply Codex runtime preferences' -Message 'All-profile install preview must apply safe Codex runtime preferences after bootstrap.'
    Assert-Equal -Actual $allPreviewResult.steps[2].name -Expected 'Sync Claude Code skills' -Message 'All-profile install preview must synchronize Claude runtime skills before editor integrations.'
    Assert-Equal -Actual $allPreviewResult.steps[3].name -Expected 'Sync Claude Code settings' -Message 'All-profile install preview must synchronize Claude runtime settings after skill sync.'
    Assert-Equal -Actual $allPreviewResult.steps[5].name -Expected 'Render global VS Code MCP configuration' -Message 'All-profile install preview must render the global VS Code MCP configuration after settings.'
    Assert-Equal -Actual $allPreviewResult.steps[8].name -Expected 'Configure global Git aliases' -Message 'All-profile install preview must include global Git alias setup after local hooks.'
    Assert-Equal -Actual $allPreviewResult.steps[9].name -Expected 'Run repository healthcheck' -Message 'All-profile install preview must end with healthcheck.'
    Assert-True -Condition ($allPreviewResult.steps[0].scriptPath -like '*scripts\runtime\bootstrap.ps1') -Message 'All-profile install preview must reference bootstrap.ps1.'
    Assert-Equal -Actual $allPreviewResult.summary.overallStatus -Expected 'preview' -Message 'All-profile install preview must report preview summary status.'
    Assert-Equal -Actual $allPreviewResult.issues.totalIssues -Expected 0 -Message 'All-profile install preview must not report issues when only planning.'

    $githubPreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -RuntimeProfile github

    Assert-Equal -Actual @($githubPreviewResult.steps).Count -Expected 2 -Message 'GitHub-profile install preview must plan bootstrap plus healthcheck only.'
    Assert-Equal -Actual $githubPreviewResult.steps[0].name -Expected 'Bootstrap shared runtime assets' -Message 'GitHub-profile install preview must keep bootstrap.'
    Assert-Equal -Actual $githubPreviewResult.steps[1].name -Expected 'Run repository healthcheck' -Message 'GitHub-profile install preview must keep healthcheck.'

    $codexPreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -RuntimeProfile codex

    Assert-Equal -Actual @($codexPreviewResult.steps).Count -Expected 3 -Message 'Codex-profile install preview must plan bootstrap, Codex runtime preferences, and healthcheck.'
    Assert-Equal -Actual $codexPreviewResult.steps[0].name -Expected 'Bootstrap shared runtime assets' -Message 'Codex-profile install preview must keep bootstrap.'
    Assert-Equal -Actual $codexPreviewResult.steps[1].name -Expected 'Apply Codex runtime preferences' -Message 'Codex-profile install preview must apply safe Codex runtime preferences.'
    Assert-Equal -Actual $codexPreviewResult.steps[2].name -Expected 'Run repository healthcheck' -Message 'Codex-profile install preview must keep healthcheck.'

    $claudePreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -RuntimeProfile claude

    Assert-Equal -Actual @($claudePreviewResult.steps).Count -Expected 3 -Message 'Claude-profile install preview must plan Claude skill sync, Claude settings sync, and healthcheck.'
    Assert-Equal -Actual $claudePreviewResult.steps[0].name -Expected 'Sync Claude Code skills' -Message 'Claude-profile install preview must synchronize Claude skills.'
    Assert-Equal -Actual $claudePreviewResult.steps[1].name -Expected 'Sync Claude Code settings' -Message 'Claude-profile install preview must synchronize Claude settings.'
    Assert-Equal -Actual $claudePreviewResult.steps[2].name -Expected 'Run repository healthcheck' -Message 'Claude-profile install preview must keep healthcheck.'

    Assert-ThrowsLike -Action { & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -RuntimeProfile github -ApplyMcpConfig } -ExpectedPattern 'does not enable the Codex runtime surface' -Message 'Install preview must reject MCP apply when the selected profile does not enable Codex.'
    Assert-ThrowsLike -Action { & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -GitHookEofMode autofix -SkipGitHooks } -ExpectedPattern 'GitHookEofMode or GitHookEofScope cannot be used when SkipGitHooks is set' -Message 'Install preview must reject an explicit GitHookEofMode when hook setup is skipped.'
    Assert-ThrowsLike -Action { & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -GitHookEofScope global -SkipGitHooks } -ExpectedPattern 'GitHookEofMode or GitHookEofScope cannot be used when SkipGitHooks is set' -Message 'Install preview must reject an explicit GitHookEofScope when hook setup is skipped.'

    $reducedPreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -RuntimeProfile all -SkipGlobalSettings -SkipGlobalSnippets -SkipGitHooks -SkipHealthcheck

    Assert-Equal -Actual @($reducedPreviewResult.steps).Count -Expected 4 -Message 'Install preview must honor skip switches on top of profile all while keeping runtime-specific preferences and Claude runtime sync.'
    Assert-Equal -Actual $reducedPreviewResult.steps[0].name -Expected 'Bootstrap shared runtime assets' -Message 'Reduced install preview must keep bootstrap.'
    Assert-Equal -Actual $reducedPreviewResult.steps[1].name -Expected 'Apply Codex runtime preferences' -Message 'Reduced install preview must keep Codex runtime preferences when Codex runtime is enabled.'
    Assert-Equal -Actual $reducedPreviewResult.steps[2].name -Expected 'Sync Claude Code skills' -Message 'Reduced install preview must keep Claude skill sync when Claude runtime is enabled.'
    Assert-Equal -Actual $reducedPreviewResult.steps[3].name -Expected 'Sync Claude Code settings' -Message 'Reduced install preview must keep Claude settings sync when Claude runtime is enabled.'
    Assert-Equal -Actual $reducedPreviewResult.summary.overallStatus -Expected 'preview' -Message 'Reduced install preview must report preview summary status.'
    Assert-Equal -Actual $reducedPreviewResult.issues.totalIssues -Expected 0 -Message 'Reduced install preview must not report issues when only planning.'

    $gitHookModePreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -GitHookEofMode autofix

    Assert-Equal -Actual @($gitHookModePreviewResult.steps).Count -Expected 1 -Message 'Install preview must allow GitHookEofMode to force local hook setup on top of the default none profile.'
    Assert-Equal -Actual $gitHookModePreviewResult.steps[0].name -Expected 'Configure Git hooks' -Message 'GitHookEofMode preview must plan Git hook setup.'
    Assert-Equal -Actual $gitHookModePreviewResult.steps[0].arguments.EofHygieneMode -Expected 'autofix' -Message 'GitHookEofMode preview must forward the selected EOF hygiene mode to setup-git-hooks.'
    Assert-Equal -Actual $gitHookModePreviewResult.steps[0].arguments.EofHygieneScope -Expected 'local-repo' -Message 'Install preview must assume the less-intrusive local-repo scope when prompting is skipped.'
    Assert-Equal -Actual $gitHookModePreviewResult.gitHookEofMode.name -Expected 'autofix' -Message 'Install preview must expose the explicit EOF hook mode in the output contract.'
    Assert-Equal -Actual $gitHookModePreviewResult.gitHookEofScope.name -Expected 'local-repo' -Message 'Install preview must expose the assumed local-repo hook scope in the output contract.'
    Assert-Equal -Actual $gitHookModePreviewResult.gitHookEofScope.prompted -Expected $true -Message 'Install preview must record that the hook scope would be prompted during an execution run.'
    Assert-Equal -Actual $gitHookModePreviewResult.summary.overallStatus -Expected 'preview' -Message 'GitHookEofMode preview must report preview summary status.'

    $gitHookGlobalPreviewResult = & $scriptPath -RepoRoot $resolvedRepoRoot -PreviewOnly -GitHookEofMode autofix -GitHookEofScope global

    Assert-Equal -Actual @($gitHookGlobalPreviewResult.steps).Count -Expected 1 -Message 'Install preview must still plan a single Git hook setup step for explicit global scope.'
    Assert-Equal -Actual $gitHookGlobalPreviewResult.steps[0].name -Expected 'Configure Git hooks' -Message 'Install preview must use the generic Git hook step label for global scope.'
    Assert-Equal -Actual $gitHookGlobalPreviewResult.steps[0].arguments.EofHygieneScope -Expected 'global' -Message 'Install preview must forward the explicit global hook scope to setup-git-hooks.'
    Assert-Equal -Actual $gitHookGlobalPreviewResult.gitHookEofScope.name -Expected 'global' -Message 'Install preview must expose the explicit global hook scope in the output contract.'
    Assert-Equal -Actual $gitHookGlobalPreviewResult.gitHookEofScope.prompted -Expected $false -Message 'Install preview must not mark explicit hook scope selection as prompted.'

    Write-Host '[OK] runtime install tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] runtime install tests failed: {0}" -f $_.Exception.Message)
    exit 1
}