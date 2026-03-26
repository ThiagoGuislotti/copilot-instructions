<#
.SYNOPSIS
    Exports a consolidated audit report for the agent instruction/runtime system.

.DESCRIPTION
    Runs runtime healthcheck, collects repository metadata, and writes a
    structured JSON audit report that can be archived locally or in CI.

    The report includes:
    - healthcheck result and checks
    - git metadata (branch, commit, dirty state)
    - policy file inventory
    - execution log path

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

.PARAMETER SyncRuntime
    Runs bootstrap sync before health checks.

.PARAMETER Mirror
    Uses mirror mode when -SyncRuntime is enabled.

.PARAMETER StrictExtras
    Fails runtime doctor when extra files exist in runtime targets.

.PARAMETER ValidationProfile
    Validation profile id used by runtime healthcheck.

.PARAMETER WarningOnly
    Global warning-only mode for healthcheck execution. Default true.

.PARAMETER TreatRuntimeDriftAsWarning
    Converts runtime doctor non-zero exit to warning. Default true.

.PARAMETER OutputPath
    Path for JSON audit report. Defaults to .temp/audit-report.json.

.PARAMETER HealthcheckOutputPath
    Path for intermediate healthcheck JSON report.

.PARAMETER LogPath
    Path for text execution log. Defaults to .temp/logs/audit-report-<timestamp>.log.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/export-audit-report.ps1

.EXAMPLE
    pwsh -File scripts/validation/export-audit-report.ps1 -SyncRuntime -Mirror -StrictExtras

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
    [switch] $SyncRuntime,
    [switch] $Mirror,
    [switch] $StrictExtras,
    [string] $ValidationProfile = 'release',
    [bool] $WarningOnly = $true,
    [bool] $TreatRuntimeDriftAsWarning = $true,
    [string] $OutputPath = '.temp/audit-report.json',
    [string] $HealthcheckOutputPath = '.temp/healthcheck-report.json',
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

# -------------------------------
# Helpers
# -------------------------------
# Collects git branch, commit, and dirty-state metadata for reports.
function Get-GitState {
    param(
        [string] $Root
    )

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        return [ordered]@{
            available = $false
            branch = $null
            commit = $null
            isDirty = $null
        }
    }

    $branch = (& git -C $Root rev-parse --abbrev-ref HEAD 2>$null)
    $commit = (& git -C $Root rev-parse HEAD 2>$null)
    $statusLines = (& git -C $Root status --porcelain 2>$null)
    $isDirty = -not [string]::IsNullOrWhiteSpace(($statusLines -join ''))

    return [ordered]@{
        available = $true
        branch = if ([string]::IsNullOrWhiteSpace($branch)) { $null } else { $branch }
        commit = if ([string]::IsNullOrWhiteSpace($commit)) { $null } else { $commit }
        isDirty = $isDirty
    }
}

# -------------------------------
# Main execution
# -------------------------------
$runtimeContext = Resolve-RuntimeExecutionContext `
    -RequestedRepoRoot $RepoRoot `
    -FallbackProfileName 'all' `
    -RequestedTargetGithubPath $TargetGithubPath `
    -RequestedTargetCodexPath $TargetCodexPath `
    -RequestedTargetAgentsSkillsPath $TargetAgentsSkillsPath `
    -RequestedTargetCopilotSkillsPath $TargetCopilotSkillsPath

$resolvedRepoRoot = $runtimeContext.ResolvedRepoRoot
$resolvedRuntimeTargets = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot
$TargetGithubPath = $resolvedRuntimeTargets.TargetGithubPath
$TargetCodexPath = $resolvedRuntimeTargets.TargetCodexPath
$TargetAgentsSkillsPath = $resolvedRuntimeTargets.TargetAgentsSkillsPath
$TargetCopilotSkillsPath = $resolvedRuntimeTargets.TargetCopilotSkillsPath

Set-Location -Path $resolvedRepoRoot

$operationArtifacts = Initialize-OperationArtifacts -ResolvedRepoRoot $resolvedRepoRoot -PrimaryOutputPath $OutputPath -AdditionalOutputPaths @($HealthcheckOutputPath) -LogPath $LogPath -DefaultLogFilePrefix 'audit-report' -LogName 'audit-report'
$resolvedOutputPath = $operationArtifacts.PrimaryOutputPath
$resolvedHealthcheckOutputPath = $operationArtifacts.AdditionalOutputPaths[0]
$resolvedLogPath = $operationArtifacts.LogPath
$script:LogFilePath = $resolvedLogPath

Start-RuntimeOperationSession `
    -Name 'export-audit-report' `
    -ResolvedRepoRoot $resolvedRepoRoot `
    -PrimaryOutputPath $resolvedOutputPath `
    -LogPath $resolvedLogPath `
    -AdditionalMetadata ([ordered]@{
            'Validation profile' = $ValidationProfile
            'Warning-only mode' = [bool] $WarningOnly
        }) `
    -IncludeMetadataInDefaultOutput | Out-Null

Write-ExecutionLog -Level 'INFO' -Message ("Repo root: {0}" -f $resolvedRepoRoot)
Write-ExecutionLog -Level 'INFO' -Message ("Audit report output: {0}" -f $resolvedOutputPath)
Write-ExecutionLog -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$healthcheckScript = Join-Path $resolvedRepoRoot 'scripts/runtime/healthcheck.ps1'
$healthcheckLogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/logs/healthcheck-from-audit.log'
$healthcheckArgs = New-ResolvedRuntimeTargetArgumentMap -Context $runtimeContext -ResolvedRepoRoot $resolvedRepoRoot -IncludeRepoRoot -IncludeRuntimeProfile
$healthcheckArgs.OutputPath = $resolvedHealthcheckOutputPath
$healthcheckArgs.LogPath = $healthcheckLogPath
$healthcheckArgs.ValidationProfile = $ValidationProfile
$healthcheckArgs.WarningOnly = $WarningOnly
$healthcheckArgs.TreatRuntimeDriftAsWarning = $TreatRuntimeDriftAsWarning
if ($SyncRuntime) {
    $healthcheckArgs.SyncRuntime = $true
}
if ($Mirror) {
    $healthcheckArgs.Mirror = $true
}
if ($StrictExtras) {
    $healthcheckArgs.StrictExtras = $true
}

Write-ExecutionLog -Level 'INFO' -Message 'Executing runtime healthcheck for audit baseline.'
$healthcheckExecution = @(Invoke-ManagedRuntimeCheck -Name 'runtime-healthcheck' -ScriptPath $healthcheckScript -Arguments $healthcheckArgs -TreatFailureAsWarning:$WarningOnly) | Select-Object -Last 1
$healthcheckExitCode = if ($null -eq $healthcheckExecution) { 1 } else { [int] $healthcheckExecution.exitCode }

$healthcheckReport = $null
if (Test-Path -LiteralPath $resolvedHealthcheckOutputPath -PathType Leaf) {
    try {
        $healthcheckReport = Get-Content -Raw -LiteralPath $resolvedHealthcheckOutputPath | ConvertFrom-Json -Depth 100
        Write-ExecutionLog -Level 'OK' -Message 'Loaded healthcheck report.'
    }
    catch {
        Write-ExecutionLog -Level 'ERROR' -Message ("Could not parse healthcheck report JSON: {0}" -f $_.Exception.Message)
    }
}
else {
    Write-ExecutionLog -Level 'ERROR' -Message ("Healthcheck report not found: {0}" -f $resolvedHealthcheckOutputPath)
}

$policyDirectory = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.github/policies'
$policyFiles = @()
if (Test-Path -LiteralPath $policyDirectory -PathType Container) {
    $policyFiles = @(Get-ChildItem -LiteralPath $policyDirectory -File -Filter '*.json' | ForEach-Object {
        [System.IO.Path]::GetRelativePath($resolvedRepoRoot, $_.FullName)
    })
}

$gitMetadata = Get-GitState -Root $resolvedRepoRoot
$overallStatus = if ($null -ne $healthcheckReport -and $null -ne $healthcheckReport.summary -and -not [string]::IsNullOrWhiteSpace([string] $healthcheckReport.summary.overallStatus)) {
    [string] $healthcheckReport.summary.overallStatus
}
elseif ($healthcheckExitCode -eq 0) {
    'passed'
}
else {
    'failed'
}

$auditReport = [ordered]@{
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
        syncRuntime = [bool] $SyncRuntime
        mirror = [bool] $Mirror
        strictExtras = [bool] $StrictExtras
        validationProfile = $ValidationProfile
        warningOnly = [bool] $WarningOnly
        treatRuntimeDriftAsWarning = [bool] $TreatRuntimeDriftAsWarning
    }
    git = $gitMetadata
    policyFiles = $policyFiles
    healthcheck = $healthcheckReport
    summary = [ordered]@{
        overallStatus = $overallStatus
        healthcheckExitCode = $healthcheckExitCode
    }
    artifacts = [ordered]@{
        auditReportPath = $resolvedOutputPath
        healthcheckReportPath = $resolvedHealthcheckOutputPath
        auditLogPath = $resolvedLogPath
        healthcheckLogPath = $healthcheckLogPath
    }
}

$auditJson = $auditReport | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $resolvedOutputPath -Value $auditJson
Write-ExecutionLog -Level 'INFO' -Message ("Audit report generated: {0}" -f $resolvedOutputPath)
Complete-RuntimeOperationSession -Name 'export-audit-report' -Status $overallStatus -Summary ([ordered]@{
        'Healthcheck exit code' = $healthcheckExitCode
        'Policy files' = $policyFiles.Count
    }) | Out-Null

if ($overallStatus -ne 'passed') {
    if (-not $WarningOnly) {
        exit 1
    }
}

exit 0