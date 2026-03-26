<#
.SYNOPSIS
    Performs controlled self-healing for runtime and workspace agent assets.

.DESCRIPTION
    Executes a repair flow and validates final health:
    1) runtime bootstrap sync
    2) apply VS Code active files from templates
    3) run healthcheck and export status

    Produces:
    - console summary
    - structured JSON report
    - text log file

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER TargetGithubPath
    Runtime target path for .github assets. Defaults to <user-home>/.github.

.PARAMETER TargetCodexPath
    Runtime target path for .codex assets. Defaults to <user-home>/.codex.

.PARAMETER TargetAgentsSkillsPath
    Runtime target path for picker-visible local skills. Defaults to <user-home>/.agents/skills.

.PARAMETER TargetCopilotSkillsPath
    Runtime target path for the GitHub Copilot native skill root used for
    legacy duplicate starter cleanup. Defaults to <user-home>/.copilot/skills.

.PARAMETER RuntimeProfile
    Runtime activation profile passed to bootstrap and healthcheck. Supported
    values are defined in `.github/governance/runtime-install-profiles.json`.
    Defaults to `all` when self-heal is invoked directly.

.PARAMETER Mirror
    Uses mirror mode for bootstrap sync.

.PARAMETER ApplyMcpConfig
    Applies MCP server settings into target Codex config.toml during bootstrap.

.PARAMETER BackupConfig
    Creates MCP config backup when -ApplyMcpConfig is used.

.PARAMETER ApplyVscodeTemplates
    Applies `.vscode` active files from templates.

.PARAMETER StrictExtras
    Fails healthcheck when runtime doctor detects extra files.

.PARAMETER OutputPath
    Path for JSON self-heal report. Defaults to .temp/self-heal-report.json.

.PARAMETER LogPath
    Path for text execution log. Defaults to .temp/logs/self-heal-<timestamp>.log.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/self-heal.ps1

.EXAMPLE
    pwsh -File scripts/runtime/self-heal.ps1 -Mirror -StrictExtras

.EXAMPLE
    pwsh -File scripts/runtime/self-heal.ps1 -ApplyMcpConfig -BackupConfig

.EXAMPLE
    pwsh -File scripts/runtime/self-heal.ps1 -ApplyVscodeTemplates

.NOTES
    Version: 1.1
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
    [switch] $ApplyVscodeTemplates,
    [switch] $StrictExtras,
    [string] $OutputPath = '.temp/self-heal-report.json',
    [string] $LogPath,
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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'runtime-paths', 'runtime-install-profiles', 'runtime-execution-context', 'runtime-operation-support')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:LogFilePath = $null
$script:IsVerboseEnabled = [bool] $Verbose
Initialize-ExecutionIssueTracking

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
$resolvedRuntimeTargets = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot
$TargetGithubPath = $resolvedRuntimeTargets.TargetGithubPath
$TargetCodexPath = $resolvedRuntimeTargets.TargetCodexPath
$TargetAgentsSkillsPath = $resolvedRuntimeTargets.TargetAgentsSkillsPath
$TargetCopilotSkillsPath = $resolvedRuntimeTargets.TargetCopilotSkillsPath

Set-Location -Path $resolvedRepoRoot

$operationArtifacts = Initialize-OperationArtifacts -ResolvedRepoRoot $resolvedRepoRoot -PrimaryOutputPath $OutputPath -LogPath $LogPath -DefaultLogFilePrefix 'self-heal' -LogName 'self-heal'
$resolvedOutputPath = $operationArtifacts.PrimaryOutputPath
$resolvedLogPath = $operationArtifacts.LogPath
$script:LogFilePath = $resolvedLogPath

Start-RuntimeOperationSession `
    -Name 'runtime-self-heal' `
    -ResolvedRepoRoot $resolvedRepoRoot `
    -RuntimeProfileName $resolvedRuntimeProfile.Name `
    -PrimaryOutputPath $resolvedOutputPath `
    -LogPath $resolvedLogPath `
    -AdditionalMetadata ([ordered]@{
            'Apply VS Code templates' = [bool] $ApplyVscodeTemplates
            'Strict extras' = [bool] $StrictExtras
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

Write-ExecutionLog -Level 'INFO' -Message ("Repo root: {0}" -f $resolvedRepoRoot)
Write-ExecutionLog -Level 'INFO' -Message ("Runtime profile: {0}" -f $resolvedRuntimeProfile.Name)
Write-ExecutionLog -Level 'INFO' -Message ("Output report: {0}" -f $resolvedOutputPath)
Write-ExecutionLog -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$steps = New-Object System.Collections.Generic.List[object]

$bootstrapScript = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'
$applyVscodeTemplatesScript = Join-Path $resolvedRepoRoot 'scripts/runtime/apply-vscode-templates.ps1'
$healthcheckScript = Join-Path $resolvedRepoRoot 'scripts/runtime/healthcheck.ps1'

$bootstrapArgs = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot -IncludeRepoRoot -IncludeRuntimeProfile
if ($Mirror) {
    $bootstrapArgs.Mirror = $true
}
if ($ApplyMcpConfig) {
    $bootstrapArgs.ApplyMcpConfig = $true
}
if ($BackupConfig) {
    $bootstrapArgs.BackupConfig = $true
}

$bootstrapStep = @(Invoke-ManagedRuntimeStep -Name 'runtime-bootstrap' -ScriptPath $bootstrapScript -Arguments $bootstrapArgs) | Select-Object -Last 1
if ($null -ne $bootstrapStep) {
    $steps.Add($bootstrapStep) | Out-Null
}

if ($ApplyVscodeTemplates) {
    $vscodeStep = @(Invoke-ManagedRuntimeStep -Name 'apply-vscode-templates' -ScriptPath $applyVscodeTemplatesScript -Arguments @{ RepoRoot = $resolvedRepoRoot; Force = $true }) | Select-Object -Last 1
    if ($null -ne $vscodeStep) {
        $steps.Add($vscodeStep) | Out-Null
    }
}
else {
    Write-ExecutionLog -Level 'INFO' -Message 'Skipping VS Code templates apply (enable with -ApplyVscodeTemplates).'
}

$healthcheckReportPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/healthcheck-report.json'
$healthcheckLogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/logs/healthcheck-from-self-heal.log'
$healthcheckArgs = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot -IncludeRepoRoot -IncludeRuntimeProfile
$healthcheckArgs.OutputPath = $healthcheckReportPath
$healthcheckArgs.LogPath = $healthcheckLogPath
if ($StrictExtras) {
    $healthcheckArgs.StrictExtras = $true
}

$healthcheckStep = @(Invoke-ManagedRuntimeStep -Name 'healthcheck' -ScriptPath $healthcheckScript -Arguments $healthcheckArgs) | Select-Object -Last 1
if ($null -ne $healthcheckStep) {
    $steps.Add($healthcheckStep) | Out-Null
}

$passedSteps = @($steps | Where-Object { $_.status -eq 'passed' }).Count
$failedSteps = @($steps | Where-Object { $_.status -ne 'passed' }).Count
$overallStatus = if ($failedSteps -eq 0) { 'passed' } else { 'failed' }

$healthcheckSummary = $null
if (Test-Path -LiteralPath $healthcheckReportPath -PathType Leaf) {
    try {
        $healthcheckSummary = Get-Content -Raw -LiteralPath $healthcheckReportPath | ConvertFrom-Json -Depth 100
    }
    catch {
        Write-ExecutionLog -Level 'WARN' -Code 'SELF_HEAL_HEALTHCHECK_REPORT_PARSE_WARNING' -Message ("Could not parse healthcheck report: {0}" -f $healthcheckReportPath)
    }
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    repoRoot = $resolvedRepoRoot
    targets = [ordered]@{
        github = $TargetGithubPath
        codex = $TargetCodexPath
        agentsSkills = $TargetAgentsSkillsPath
        copilotSkills = $TargetCopilotSkillsPath
    }
    options = [ordered]@{
        mirror = [bool] $Mirror
        applyMcpConfig = [bool] $ApplyMcpConfig
        backupConfig = [bool] $BackupConfig
        applyVscodeTemplates = [bool] $ApplyVscodeTemplates
        strictExtras = [bool] $StrictExtras
        runtimeProfile = $resolvedRuntimeProfile.Name
    }
    summary = [ordered]@{
        totalSteps = $steps.Count
        passedSteps = $passedSteps
        failedSteps = $failedSteps
        overallStatus = $overallStatus
    }
    issues = $null
    steps = $steps.ToArray()
    healthcheck = $healthcheckSummary
    logPath = $resolvedLogPath
}

$issueSummary = Write-ExecutionIssueSummary -Title 'Self-heal issue summary'
$report.issues = $issueSummary

$reportJson = $report | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $resolvedOutputPath -Value $reportJson

Write-ExecutionLog -Level 'INFO' -Message ("Self-heal summary: total={0} passed={1} failed={2}" -f $steps.Count, $passedSteps, $failedSteps)
Write-ExecutionLog -Level 'INFO' -Message ("Self-heal report generated: {0}" -f $resolvedOutputPath)
Complete-RuntimeOperationSession -Name 'runtime-self-heal' -Status $overallStatus -Summary ([ordered]@{
        'Total steps' = $steps.Count
        'Passed steps' = $passedSteps
        'Failed steps' = $failedSteps
    }) | Out-Null

if ($overallStatus -ne 'passed') {
    exit 1
}

exit 0