<#
.SYNOPSIS
    Runs end-to-end health checks for repository validation and runtime drift.

.DESCRIPTION
    Executes:
    - optional runtime bootstrap sync
    - validation suite (`scripts/validation/validate-all.ps1`)
    - runtime drift doctor (`scripts/runtime/doctor.ps1`)

    Produces:
    - console summary
    - structured JSON report
    - plain-text execution log

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when warning-only is disabled and failures are found

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
    Runtime activation profile passed to bootstrap and doctor. Supported
    values are defined in `.github/governance/runtime-install-profiles.json`.
    Defaults to `all` when healthcheck is invoked directly.

.PARAMETER SyncRuntime
    Runs bootstrap sync before health checks.

.PARAMETER Mirror
    Uses mirror mode when -SyncRuntime is enabled.

.PARAMETER StrictExtras
    Passes -StrictExtras to runtime doctor.

.PARAMETER ValidationProfile
    Validation profile id used by validate-all.

.PARAMETER WarningOnly
    Global warning-only mode. Default true.

.PARAMETER TreatRuntimeDriftAsWarning
    Converts runtime doctor non-zero exit to warning. Default true.

.PARAMETER OutputPath
    Path for JSON healthcheck report. Defaults to .temp/healthcheck-report.json.

.PARAMETER LogPath
    Path for text execution log. Defaults to .temp/logs/healthcheck-<timestamp>.log.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1 -SyncRuntime -Mirror -ValidationProfile release

.EXAMPLE
    pwsh -File scripts/runtime/healthcheck.ps1 -WarningOnly:$false -TreatRuntimeDriftAsWarning:$false

.NOTES
    Version: 2.1
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath,
    [string] $TargetCodexPath,
    [string] $TargetAgentsSkillsPath,
    [string] $TargetCopilotSkillsPath,
    [string] $RuntimeProfile,
    [switch] $SyncRuntime,
    [switch] $Mirror,
    [switch] $StrictExtras,
    [string] $ValidationProfile = 'dev',
    [bool] $WarningOnly = $true,
    [bool] $TreatRuntimeDriftAsWarning = $true,
    [string] $OutputPath = '.temp/healthcheck-report.json',
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

$operationArtifacts = Initialize-OperationArtifacts -ResolvedRepoRoot $resolvedRepoRoot -PrimaryOutputPath $OutputPath -LogPath $LogPath -DefaultLogFilePrefix 'healthcheck' -LogName 'healthcheck'
$resolvedOutputPath = $operationArtifacts.PrimaryOutputPath
$resolvedLogPath = $operationArtifacts.LogPath
$script:LogFilePath = $resolvedLogPath

Start-RuntimeOperationSession `
    -Name 'runtime-healthcheck' `
    -ResolvedRepoRoot $resolvedRepoRoot `
    -RuntimeProfileName $resolvedRuntimeProfile.Name `
    -PrimaryOutputPath $resolvedOutputPath `
    -LogPath $resolvedLogPath `
    -AdditionalMetadata ([ordered]@{
            'Validation profile' = $ValidationProfile
            'Warning-only mode' = [bool] $WarningOnly
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

Write-ExecutionLog -Level 'INFO' -Message ("Repo root: {0}" -f $resolvedRepoRoot)
Write-ExecutionLog -Level 'INFO' -Message ("Validation profile: {0}" -f $ValidationProfile)
Write-ExecutionLog -Level 'INFO' -Message ("Runtime profile: {0}" -f $resolvedRuntimeProfile.Name)
Write-ExecutionLog -Level 'INFO' -Message ("Warning-only mode: {0}" -f $WarningOnly)
Write-ExecutionLog -Level 'INFO' -Message ("Output report: {0}" -f $resolvedOutputPath)
Write-ExecutionLog -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$checks = New-Object System.Collections.Generic.List[object]

$bootstrapScript = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'
$validateAllScript = Join-Path $resolvedRepoRoot 'scripts/validation/validate-all.ps1'
$doctorScript = Join-Path $resolvedRepoRoot 'scripts/runtime/doctor.ps1'

if ($SyncRuntime) {
    $bootstrapArgs = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot -IncludeRepoRoot -IncludeRuntimeProfile
    if ($Mirror) {
        $bootstrapArgs.Mirror = $true
    }

    $bootstrapCheck = @(Invoke-ManagedRuntimeCheck -Name 'runtime-bootstrap' -ScriptPath $bootstrapScript -Arguments $bootstrapArgs -TreatFailureAsWarning:$WarningOnly) | Select-Object -Last 1
    if ($null -ne $bootstrapCheck) {
        $checks.Add($bootstrapCheck) | Out-Null
    }
}

$validateAllArgs = @{
    RepoRoot = $resolvedRepoRoot
    ValidationProfile = $ValidationProfile
    WarningOnly = $WarningOnly
}
$validateAllCheck = @(Invoke-ManagedRuntimeCheck -Name 'validate-all' -ScriptPath $validateAllScript -Arguments $validateAllArgs -TreatFailureAsWarning:$WarningOnly) | Select-Object -Last 1
if ($null -ne $validateAllCheck) {
    $checks.Add($validateAllCheck) | Out-Null
}

$doctorArgs = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot -IncludeRepoRoot -IncludeRuntimeProfile
if ($StrictExtras) {
    $doctorArgs.StrictExtras = $true
}

$doctorAsWarning = [bool] ($WarningOnly -or $TreatRuntimeDriftAsWarning)
$doctorCheck = @(Invoke-ManagedRuntimeCheck -Name 'runtime-doctor' -ScriptPath $doctorScript -Arguments $doctorArgs -TreatFailureAsWarning:$doctorAsWarning) | Select-Object -Last 1
if ($null -ne $doctorCheck) {
    $checks.Add($doctorCheck) | Out-Null
}

$passedChecks = @($checks | Where-Object { $_.status -eq 'passed' }).Count
$warningChecks = @($checks | Where-Object { $_.status -eq 'warning' }).Count
$failedChecks = @($checks | Where-Object { $_.status -eq 'failed' }).Count

$overallStatus = if ($failedChecks -gt 0) {
    'failed'
}
elseif ($warningChecks -gt 0) {
    'warning'
}
else {
    'passed'
}

$report = [ordered]@{
    schemaVersion = 2
    generatedAt = (Get-Date).ToString('o')
    repoRoot = $resolvedRepoRoot
    targets = [ordered]@{
        github = $TargetGithubPath
        codex = $TargetCodexPath
        agentsSkills = $TargetAgentsSkillsPath
        copilotSkills = $TargetCopilotSkillsPath
    }
    options = [ordered]@{
        syncRuntime = [bool] $SyncRuntime
        mirror = [bool] $Mirror
        strictExtras = [bool] $StrictExtras
        runtimeProfile = $resolvedRuntimeProfile.Name
        validationProfile = $ValidationProfile
        warningOnly = [bool] $WarningOnly
        treatRuntimeDriftAsWarning = [bool] $TreatRuntimeDriftAsWarning
    }
    summary = [ordered]@{
        totalChecks = $checks.Count
        passedChecks = $passedChecks
        warningChecks = $warningChecks
        failedChecks = $failedChecks
        overallStatus = $overallStatus
    }
    issues = $null
    checks = $checks.ToArray()
    logPath = $resolvedLogPath
}

Write-ExecutionLog -Level 'INFO' -Message ("Healthcheck summary: total={0} passed={1} warning={2} failed={3}" -f $checks.Count, $passedChecks, $warningChecks, $failedChecks)
$issueSummary = Write-ExecutionIssueSummary -Title 'Healthcheck issue summary'
$report.issues = $issueSummary

Set-Content -LiteralPath $resolvedOutputPath -Value ($report | ConvertTo-Json -Depth 100)
Write-ExecutionLog -Level 'INFO' -Message ("Healthcheck report generated: {0}" -f $resolvedOutputPath)
Complete-RuntimeOperationSession -Name 'runtime-healthcheck' -Status $overallStatus -Summary ([ordered]@{
        'Total checks' = $checks.Count
        'Passed checks' = $passedChecks
        'Warning checks' = $warningChecks
        'Failed checks' = $failedChecks
    }) | Out-Null

if ($failedChecks -gt 0 -and -not $WarningOnly) {
    exit 1
}

exit 0