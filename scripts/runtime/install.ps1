<#
.SYNOPSIS
    Runs the recommended local onboarding flow for repository-managed runtime assets.

.DESCRIPTION
    Orchestrates the standard setup flow for this repository:
    - bootstrap shared `.github` and `.codex` runtime assets
    - optionally apply MCP configuration
    - render versioned global VS Code settings
    - render versioned global VS Code MCP configuration
    - synchronize versioned VS Code snippets
    - configure local Git hooks
    - configure global Git aliases
    - run repository healthcheck

    The script is intentionally an orchestrator only. It reuses the versioned
    runtime scripts already maintained in this repository instead of duplicating logic.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER TargetGithubPath
    Optional runtime target path for .github assets.

.PARAMETER TargetCodexPath
    Optional runtime target path for .codex assets.

.PARAMETER TargetAgentsSkillsPath
    Optional runtime target path for picker-visible local skills.

.PARAMETER TargetCopilotSkillsPath
    Optional runtime target path for the GitHub Copilot native skill root used
    for legacy duplicate starter cleanup.

.PARAMETER TargetClaudePath
    Optional runtime target path for the Claude Code runtime used by
    `scripts/runtime/sync-claude-skills.ps1`.

.PARAMETER GlobalVscodeUserPath
    Optional VS Code global user settings folder.

.PARAMETER RuntimeProfile
    Runtime activation profile. Supported values are defined in
    `.github/governance/runtime-install-profiles.json`. Defaults to the
    catalog default, which is currently `none`.

.PARAMETER GitHookEofMode
    Local pre-commit EOF hygiene mode for this clone/worktree. Supported
    values are defined in `.github/governance/git-hook-eof-modes.json`.

.PARAMETER GitHookEofScope
    Scope for persisting the EOF hygiene mode selection. Supported values are
    defined in `.github/governance/git-hook-eof-modes.json`. When omitted and
    `-GitHookEofMode` is supplied during a non-preview run, the installer asks
    whether the selection should be global. The default remains local-repo.

.PARAMETER CodexReasoningEffort
    Optional Codex reasoning effort override applied through
    `scripts/runtime/set-codex-runtime-preferences.ps1`. When omitted, the
    repository-owned hygiene catalog default is used.

.PARAMETER CodexMultiAgentMode
    Optional Codex multi-agent mode override applied through
    `scripts/runtime/set-codex-runtime-preferences.ps1`. Supported values are
    `enabled` and `disabled`. When omitted, the repository-owned hygiene
    catalog default is used.

.PARAMETER ValidationProfile
    Validation profile used by the final healthcheck. Defaults to `dev`.

.PARAMETER Mirror
    Enables mirror mode for bootstrap runtime sync.

.PARAMETER ApplyMcpConfig
    Applies MCP configuration during bootstrap.

.PARAMETER BackupMcpConfig
    Creates backup before applying MCP configuration.

.PARAMETER CreateSettingsBackup
    Creates backups before rendering the global VS Code `settings.json` and `mcp.json` files.

.PARAMETER SkipGlobalSettings
    Skips global VS Code settings synchronization.

.PARAMETER SkipGlobalSnippets
    Skips global VS Code snippet synchronization.

.PARAMETER SkipGitHooks
    Skips local Git hook setup.

.PARAMETER SkipHealthcheck
    Skips the final healthcheck run.

.PARAMETER PreviewOnly
    Prints the planned steps and returns them without executing any changes.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/install.ps1

.EXAMPLE
    pwsh -File scripts/runtime/install.ps1 -Mirror -ApplyMcpConfig -BackupMcpConfig -CreateSettingsBackup

.EXAMPLE
    pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

.EXAMPLE
    pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RepoRoot $RepoRoot -PreviewOnly

.EXAMPLE
    pwsh -File scripts/runtime/install.ps1 -PreviewOnly

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath,
    [string] $TargetCodexPath,
    [string] $TargetAgentsSkillsPath,
    [string] $TargetCopilotSkillsPath,
    [string] $TargetClaudePath,
    [string] $GlobalVscodeUserPath,
    [string] $RuntimeProfile,
    [string] $GitHookEofMode,
    [string] $GitHookEofScope,
    [ValidateSet('low', 'medium', 'high', 'xhigh')]
    [string] $CodexReasoningEffort,
    [ValidateSet('enabled', 'disabled')]
    [string] $CodexMultiAgentMode,
    [string] $ValidationProfile = 'dev',
    [switch] $Mirror,
    [switch] $ApplyMcpConfig,
    [switch] $BackupMcpConfig,
    [switch] $CreateSettingsBackup,
    [switch] $SkipGlobalSettings,
    [switch] $SkipGlobalSnippets,
    [switch] $SkipGitHooks,
    [switch] $SkipHealthcheck,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'runtime-install-profiles', 'git-hook-eof-settings', 'runtime-execution-context')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:LogFilePath = $null

Initialize-ExecutionIssueTracking
# Builds a deterministic install step contract.
function New-InstallStep {
    param(
        [string] $Name,
        [string] $ScriptPath,
        [hashtable] $Arguments
    )

    return [pscustomobject]@{
        name = $Name
        scriptPath = $ScriptPath
        arguments = $Arguments
    }
}

# Executes or previews a planned install step.
function Invoke-InstallStep {
    param(
        [pscustomobject] $Step,
        [bool] $Preview
    )

    $startedAt = Get-Date
    $status = 'preview'
    $errorMessage = $null

    if ($Preview) {
        Write-StyledOutput ("[PLAN] {0}" -f $Step.name) | Out-Host
    }
    else {
        Write-StyledOutput ("[STEP] {0}" -f $Step.name) | Out-Host
        Write-ExecutionLog -Level 'INFO' -Message ("Starting install step: {0}" -f $Step.name)
        try {
            $stepArguments = @{}
            foreach ($property in $Step.arguments.GetEnumerator()) {
                $stepArguments[$property.Key] = $property.Value
            }

            & $Step.scriptPath @stepArguments | Out-Null
            $stepExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            if ($stepExitCode -eq 0) {
                $status = 'passed'
                Write-StyledOutput ("[OK] {0}" -f $Step.name) | Out-Host
                Write-ExecutionLog -Level 'OK' -Message ("Install step passed: {0}" -f $Step.name)
            }
            else {
                $status = 'failed'
                $errorMessage = "non-zero exit code: $stepExitCode"
                Write-StyledOutput ("[FAIL] {0}: {1}" -f $Step.name, $errorMessage) | Out-Host
                Write-ExecutionLog -Level 'ERROR' -Code 'INSTALL_STEP_FAILED' -Message ("{0}: {1}" -f $Step.name, $errorMessage)
            }
        }
        catch {
            $status = 'failed'
            $errorMessage = $_.Exception.Message
            Write-StyledOutput ("[FAIL] {0}: {1}" -f $Step.name, $errorMessage) | Out-Host
            Write-ExecutionLog -Level 'ERROR' -Code 'INSTALL_STEP_EXCEPTION' -Message ("{0}: {1}" -f $Step.name, $errorMessage)
        }
    }

    return [pscustomobject]@{
        name = $Step.name
        scriptPath = $Step.scriptPath
        status = $status
        startedAt = $startedAt.ToString('o')
        completedAt = (Get-Date).ToString('o')
        error = $errorMessage
    }
}

# Prompts the operator for the desired EOF hook scope when needed.
function Resolve-InstallGitHookEofScope {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResolvedRepoRoot,
        [bool] $PreviewOnly,
        [string] $RequestedScopeName,
        [bool] $PromptRequested
    )

    if (-not $PromptRequested) {
        if ([string]::IsNullOrWhiteSpace($RequestedScopeName)) {
            return $null
        }

        return (Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName $RequestedScopeName)
    }

    if ($PreviewOnly) {
        return (Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName 'local-repo')
    }

    try {
        $response = Read-Host 'Apply Git hook EOF mode globally for all repositories using this hook runtime? [y/N]'
    }
    catch {
        return (Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName 'local-repo')
    }

    if (-not [string]::IsNullOrWhiteSpace($response)) {
        $normalizedResponse = $response.Trim().ToLowerInvariant()
        if ($normalizedResponse -in @('y', 'yes', 's', 'sim')) {
            return (Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName 'global')
        }
    }

    return (Resolve-GitHookEofScope -ResolvedRepoRoot $ResolvedRepoRoot -ScopeName 'local-repo')
}

$runtimeContext = Resolve-RuntimeExecutionContext `
    -RequestedRepoRoot $RepoRoot `
    -ProfileName $RuntimeProfile `
    -RequestedTargetGithubPath $TargetGithubPath `
    -RequestedTargetCodexPath $TargetCodexPath `
    -RequestedTargetAgentsSkillsPath $TargetAgentsSkillsPath `
    -RequestedTargetCopilotSkillsPath $TargetCopilotSkillsPath `
    -RequestedTargetClaudePath $TargetClaudePath

$resolvedRepoRoot = $runtimeContext.ResolvedRepoRoot
$resolvedRuntimeProfile = $runtimeContext.RuntimeProfile
$effectiveRuntimeLocations = $runtimeContext.EffectiveRuntimeLocations
$TargetGithubPath = $runtimeContext.Targets.GithubRuntimeRoot
$TargetCodexPath = $runtimeContext.Targets.CodexRuntimeRoot
$TargetAgentsSkillsPath = $runtimeContext.Targets.AgentsSkillsRoot
$TargetCopilotSkillsPath = $runtimeContext.Targets.CopilotSkillsRoot
$TargetClaudePath = $runtimeContext.Targets.ClaudeRuntimeRoot
$requestedGitHookEofSelection = (-not [string]::IsNullOrWhiteSpace($GitHookEofMode)) -or (-not [string]::IsNullOrWhiteSpace($GitHookEofScope))
$currentEffectiveGitHookEofMode = if ($requestedGitHookEofSelection) {
    Get-EffectiveGitHookEofMode -ResolvedRepoRoot $resolvedRepoRoot
}
else {
    $null
}
$shouldPromptForGitHookEofScope = (-not [string]::IsNullOrWhiteSpace($GitHookEofMode)) -and [string]::IsNullOrWhiteSpace($GitHookEofScope)
$resolvedGitHookEofMode = if (-not [string]::IsNullOrWhiteSpace($GitHookEofMode)) {
    Resolve-GitHookEofMode -ResolvedRepoRoot $resolvedRepoRoot -ModeName $GitHookEofMode
}
elseif ($requestedGitHookEofSelection) {
    Resolve-GitHookEofMode -ResolvedRepoRoot $resolvedRepoRoot -ModeName $currentEffectiveGitHookEofMode.Name
}
else {
    $null
}
$resolvedGitHookEofScope = Resolve-InstallGitHookEofScope -ResolvedRepoRoot $resolvedRepoRoot -PreviewOnly ([bool] $PreviewOnly) -RequestedScopeName $GitHookEofScope -PromptRequested $shouldPromptForGitHookEofScope
$steps = New-Object System.Collections.Generic.List[object]

if ($ApplyMcpConfig -and -not $resolvedRuntimeProfile.EnableCodexRuntime) {
    throw ("Runtime profile '{0}' does not enable the Codex runtime surface required by -ApplyMcpConfig." -f $resolvedRuntimeProfile.Name)
}

if ($SkipGitHooks -and ($null -ne $resolvedGitHookEofMode -or $null -ne $resolvedGitHookEofScope)) {
    throw 'GitHookEofMode or GitHookEofScope cannot be used when SkipGitHooks is set.'
}

if ($resolvedRuntimeProfile.InstallBootstrap) {
    $bootstrapArguments = New-RuntimeTargetArgumentMap -Context $runtimeContext -IncludeRepoRoot -IncludeRuntimeProfile
    if ($Mirror) {
        $bootstrapArguments.Mirror = $true
    }
    if ($ApplyMcpConfig) {
        $bootstrapArguments.ApplyMcpConfig = $true
    }
    if ($BackupMcpConfig) {
        $bootstrapArguments.BackupConfig = $true
    }

    $steps.Add((New-InstallStep -Name 'Bootstrap shared runtime assets' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/bootstrap.ps1') -Arguments $bootstrapArguments)) | Out-Null
}

if ($resolvedRuntimeProfile.EnableCodexRuntime) {
    $codexPreferenceArguments = @{
        RepoRoot = $resolvedRepoRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($TargetCodexPath)) {
        $codexPreferenceArguments.TargetConfigPath = (Join-Path $TargetCodexPath 'config.toml')
    }
    if (-not [string]::IsNullOrWhiteSpace($CodexReasoningEffort)) {
        $codexPreferenceArguments.ReasoningEffort = $CodexReasoningEffort
    }
    if (-not [string]::IsNullOrWhiteSpace($CodexMultiAgentMode)) {
        $codexPreferenceArguments.MultiAgentMode = $CodexMultiAgentMode
    }
    if ($BackupMcpConfig) {
        $codexPreferenceArguments.CreateBackup = $true
    }

    $steps.Add((New-InstallStep -Name 'Apply Codex runtime preferences' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/set-codex-runtime-preferences.ps1') -Arguments $codexPreferenceArguments)) | Out-Null
}

if ($resolvedRuntimeProfile.EnableClaudeRuntime) {
    $claudeSyncArguments = @{
        RepoRoot = $resolvedRepoRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($TargetClaudePath)) {
        $claudeSyncArguments.TargetClaudePath = $TargetClaudePath
    }

    $steps.Add((New-InstallStep -Name 'Sync Claude Code skills' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/sync-claude-skills.ps1') -Arguments $claudeSyncArguments)) | Out-Null
    $steps.Add((New-InstallStep -Name 'Sync Claude Code settings' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/sync-claude-settings.ps1') -Arguments $claudeSyncArguments)) | Out-Null
}

if ($resolvedRuntimeProfile.InstallGlobalVscodeSettings -and -not $SkipGlobalSettings) {
    $settingsArguments = @{
        RepoRoot = $resolvedRepoRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($GlobalVscodeUserPath)) {
        $settingsArguments.GlobalVscodeUserPath = $GlobalVscodeUserPath
    }
    if ($CreateSettingsBackup) {
        $settingsArguments.CreateBackup = $true
    }

    $steps.Add((New-InstallStep -Name 'Render global VS Code settings' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/sync-vscode-global-settings.ps1') -Arguments $settingsArguments)) | Out-Null
    $steps.Add((New-InstallStep -Name 'Render global VS Code MCP configuration' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/sync-vscode-global-mcp.ps1') -Arguments $settingsArguments)) | Out-Null
}

if ($resolvedRuntimeProfile.InstallGlobalVscodeSnippets -and -not $SkipGlobalSnippets) {
    $snippetArguments = @{
        RepoRoot = $resolvedRepoRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($GlobalVscodeUserPath)) {
        $snippetArguments.GlobalVscodeUserPath = $GlobalVscodeUserPath
    }

    $steps.Add((New-InstallStep -Name 'Synchronize global VS Code snippets' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/sync-vscode-global-snippets.ps1') -Arguments $snippetArguments)) | Out-Null
}

$shouldConfigureLocalGitHooks = (-not $SkipGitHooks) -and ($resolvedRuntimeProfile.InstallLocalGitHooks -or $null -ne $resolvedGitHookEofMode -or $null -ne $resolvedGitHookEofScope)
if ($shouldConfigureLocalGitHooks) {
    $gitHookArguments = @{}
    if ($null -ne $resolvedGitHookEofMode) {
        $gitHookArguments.EofHygieneMode = $resolvedGitHookEofMode.Name
    }
    if ($null -ne $resolvedGitHookEofScope) {
        $gitHookArguments.EofHygieneScope = $resolvedGitHookEofScope.Name
    }
    $steps.Add((New-InstallStep -Name 'Configure Git hooks' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/git-hooks/setup-git-hooks.ps1') -Arguments $gitHookArguments)) | Out-Null
}

if ($resolvedRuntimeProfile.InstallGlobalGitAliases -and -not $SkipGitHooks) {
    $globalAliasArguments = @{
        RepoRoot = $resolvedRepoRoot
        TargetCodexPath = $TargetCodexPath
    }
    $steps.Add((New-InstallStep -Name 'Configure global Git aliases' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/git-hooks/setup-global-git-aliases.ps1') -Arguments $globalAliasArguments)) | Out-Null
}

if ($resolvedRuntimeProfile.InstallHealthcheck -and -not $SkipHealthcheck) {
    $healthcheckArguments = New-RuntimeTargetArgumentMap -Context $runtimeContext -IncludeRepoRoot -IncludeRuntimeProfile
    $healthcheckArguments.ValidationProfile = $ValidationProfile
    $healthcheckArguments.WarningOnly = $true

    $steps.Add((New-InstallStep -Name 'Run repository healthcheck' -ScriptPath (Resolve-RepoPath -Root $resolvedRepoRoot -Path 'scripts/runtime/healthcheck.ps1') -Arguments $healthcheckArguments)) | Out-Null
}

Start-ExecutionSession `
    -Name 'runtime-install' `
    -RootPath $resolvedRepoRoot `
    -Metadata ([ordered]@{
            'Runtime profile' = $resolvedRuntimeProfile.Name
            'Preview-only' = [bool] $PreviewOnly
            'Planned steps' = $steps.Count
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

$results = New-Object System.Collections.Generic.List[object]
foreach ($step in $steps) {
    $stepResult = Invoke-InstallStep -Step $step -Preview ([bool] $PreviewOnly)
    $results.Add($stepResult) | Out-Null

    if ((-not $PreviewOnly) -and $stepResult.status -eq 'failed') {
        break
    }
}

$resultItems = @($results.ToArray())
$stepItems = @($steps.ToArray())
$passedSteps = @($resultItems | Where-Object { $_.status -eq 'passed' }).Count
$failedSteps = @($resultItems | Where-Object { $_.status -eq 'failed' }).Count
$issueSummary = Write-ExecutionIssueSummary -Title 'Runtime install issue summary'
$overallStatus = if ($failedSteps -gt 0) { 'failed' } elseif ($PreviewOnly) { 'preview' } else { 'passed' }

Write-StyledOutput '' | Out-Host
Write-StyledOutput 'Runtime install summary' | Out-Host
Write-StyledOutput ("  Runtime profile: {0}" -f $resolvedRuntimeProfile.Name) | Out-Host
Write-StyledOutput ("  Profile catalog: {0}" -f $resolvedRuntimeProfile.CatalogPath) | Out-Host
Write-StyledOutput ("  Runtime location catalog: {0}" -f $effectiveRuntimeLocations.catalogPath) | Out-Host
Write-StyledOutput ("  Runtime location overrides: {0}" -f ($(if ($effectiveRuntimeLocations.settingsExists) { $effectiveRuntimeLocations.settingsPath } else { 'none' }))) | Out-Host
Write-StyledOutput ("  Preview-only: {0}" -f ([bool] $PreviewOnly)) | Out-Host
Write-StyledOutput ("  Planned steps: {0}" -f $steps.Count) | Out-Host
Write-StyledOutput ("  Executed steps: {0}" -f $resultItems.Count) | Out-Host
Write-StyledOutput ("  Passed steps: {0}" -f $passedSteps) | Out-Host
Write-StyledOutput ("  Failed steps: {0}" -f $failedSteps) | Out-Host
Write-StyledOutput ("  Overall status: {0}" -f $overallStatus) | Out-Host
Complete-ExecutionSession -Name 'runtime-install' -Status $overallStatus -Summary ([ordered]@{
        'Planned steps' = $steps.Count
        'Executed steps' = $resultItems.Count
        'Passed steps' = $passedSteps
        'Failed steps' = $failedSteps
    }) | Out-Null

$output = [pscustomobject]@{
    previewOnly = [bool] $PreviewOnly
    repoRoot = $resolvedRepoRoot
    runtimeProfile = [pscustomobject]@{
        name = $resolvedRuntimeProfile.Name
        description = $resolvedRuntimeProfile.Description
        defaultProfile = $resolvedRuntimeProfile.DefaultProfile
        catalogPath = $resolvedRuntimeProfile.CatalogPath
    }
    runtimeLocations = [pscustomobject]@{
        catalogPath = $effectiveRuntimeLocations.catalogPath
        settingsPath = $effectiveRuntimeLocations.settingsPath
        settingsExists = [bool] $effectiveRuntimeLocations.settingsExists
        githubRuntimeRoot = $effectiveRuntimeLocations.githubRuntimeRoot
        codexRuntimeRoot = $effectiveRuntimeLocations.codexRuntimeRoot
        agentsSkillsRoot = $effectiveRuntimeLocations.agentsSkillsRoot
        copilotSkillsRoot = $effectiveRuntimeLocations.copilotSkillsRoot
        codexGitHooksRoot = $effectiveRuntimeLocations.codexGitHooksRoot
    }
    gitHookEofMode = if ($null -ne $resolvedGitHookEofMode) {
        [pscustomobject]@{
            name = $resolvedGitHookEofMode.Name
            description = $resolvedGitHookEofMode.Description
            defaultMode = $resolvedGitHookEofMode.DefaultMode
            catalogPath = $resolvedGitHookEofMode.CatalogPath
        }
    } else { $null }
    gitHookEofScope = if ($null -ne $resolvedGitHookEofScope) {
        [pscustomobject]@{
            name = $resolvedGitHookEofScope.Name
            description = $resolvedGitHookEofScope.Description
            defaultScope = $resolvedGitHookEofScope.DefaultScope
            catalogPath = $resolvedGitHookEofScope.CatalogPath
            prompted = [bool] $shouldPromptForGitHookEofScope
        }
    } else { $null }
    steps = $stepItems
    results = $resultItems
    summary = [pscustomobject]@{
        overallStatus = $overallStatus
        runtimeProfile = $resolvedRuntimeProfile.Name
        plannedSteps = $steps.Count
        executedSteps = $resultItems.Count
        passedSteps = $passedSteps
        failedSteps = $failedSteps
    }
    issues = $issueSummary
}

$output

if ($failedSteps -gt 0 -and -not $PreviewOnly) {
    exit 1
}