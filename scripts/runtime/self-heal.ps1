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
    Runtime target path for .github assets. Defaults to $env:USERPROFILE\.github.

.PARAMETER TargetCodexPath
    Runtime target path for .codex assets. Defaults to $env:USERPROFILE\.codex.

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
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [string] $TargetGithubPath = "$env:USERPROFILE\.github",
    [string] $TargetCodexPath = "$env:USERPROFILE\.codex",
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
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:LogFilePath = $null

# -------------------------------
# Helpers
# -------------------------------
function Write-VerboseColor {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($Verbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Resolve-RepoPath {
    param(
        [string] $Root,
        [string] $Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Set-CorrectWorkingDirectory {
    param(
        [string] $RequestedRoot
    )

    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        try {
            $candidates += (Resolve-Path -LiteralPath $RequestedRoot).Path
        }
        catch {
            throw "Invalid RepoRoot path: $RequestedRoot"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($script:ScriptRoot)) {
        $candidates += (Resolve-Path -LiteralPath (Join-Path $script:ScriptRoot '..\..')).Path
    }

    $candidates += (Get-Location).Path

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $current = $candidate
        for ($i = 0; $i -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $i++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Set-Location -Path $current
                Write-VerboseColor ("Repository root detected: {0}" -f $current) 'Green'
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

function Ensure-ParentDirectory {
    param(
        [string] $Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) {
        return
    }

    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

function Write-Log {
    param(
        [string] $Level,
        [string] $Message
    )

    $timestamp = (Get-Date).ToString('o')
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    if ($null -ne $script:LogFilePath) {
        Add-Content -LiteralPath $script:LogFilePath -Value $line
    }

    $color = 'Gray'
    if ($Level -eq 'ERROR') { $color = 'Red' }
    elseif ($Level -eq 'WARN') { $color = 'Yellow' }
    elseif ($Level -eq 'OK') { $color = 'Green' }
    elseif ($Level -eq 'INFO') { $color = 'Cyan' }

    Write-Host $line -ForegroundColor $color
}

function Invoke-ScriptStep {
    param(
        [string] $Name,
        [string] $ScriptPath,
        [hashtable] $Arguments
    )

    $startedAt = Get-Date
    $status = 'failed'
    $exitCode = 1
    $errorMessage = $null

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        $errorMessage = "Script not found: $ScriptPath"
        Write-Log -Level 'ERROR' -Message ("{0}: {1}" -f $Name, $errorMessage)
    }
    else {
        Write-Log -Level 'INFO' -Message ("Starting step: {0}" -f $Name)

        try {
            & $ScriptPath @Arguments
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            if ($exitCode -eq 0) {
                $status = 'passed'
                Write-Log -Level 'OK' -Message ("Step passed: {0}" -f $Name)
            }
            else {
                Write-Log -Level 'ERROR' -Message ("Step failed: {0} (exit code {1})" -f $Name, $exitCode)
            }
        }
        catch {
            $exitCode = 1
            $errorMessage = $_.Exception.Message
            Write-Log -Level 'ERROR' -Message ("Step exception: {0} :: {1}" -f $Name, $errorMessage)
        }
    }

    $finishedAt = Get-Date
    $durationMs = [int] ($finishedAt - $startedAt).TotalMilliseconds
    $relativeScriptPath = [System.IO.Path]::GetRelativePath((Get-Location).Path, $ScriptPath)
    $argumentList = @()
    foreach ($entry in ($Arguments.GetEnumerator() | Sort-Object Name)) {
        $argumentList += ("-{0}={1}" -f $entry.Key, $entry.Value)
    }

    return [pscustomobject]@{
        name = $Name
        script = $relativeScriptPath
        arguments = $argumentList
        status = $status
        exitCode = $exitCode
        durationMs = $durationMs
        startedAt = $startedAt.ToString('o')
        finishedAt = $finishedAt.ToString('o')
        error = $errorMessage
    }
}

# -------------------------------
# Main execution
# -------------------------------
$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot
$resolvedOutputPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path $OutputPath

$resolvedLogPath = if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $timestampToken = Get-Date -Format 'yyyyMMdd-HHmmss'
    Resolve-RepoPath -Root $resolvedRepoRoot -Path (".temp/logs/self-heal-{0}.log" -f $timestampToken)
}
else {
    Resolve-RepoPath -Root $resolvedRepoRoot -Path $LogPath
}

Ensure-ParentDirectory -Path $resolvedOutputPath
Ensure-ParentDirectory -Path $resolvedLogPath
Set-Content -LiteralPath $resolvedLogPath -Value ("# self-heal log`n# generatedAt={0}" -f (Get-Date).ToString('o'))
$script:LogFilePath = $resolvedLogPath

Write-Log -Level 'INFO' -Message ("Repo root: {0}" -f $resolvedRepoRoot)
Write-Log -Level 'INFO' -Message ("Output report: {0}" -f $resolvedOutputPath)
Write-Log -Level 'INFO' -Message ("Log file: {0}" -f $resolvedLogPath)

$steps = New-Object System.Collections.Generic.List[object]

$bootstrapScript = Join-Path $resolvedRepoRoot 'scripts/runtime/bootstrap.ps1'
$applyVscodeTemplatesScript = Join-Path $resolvedRepoRoot 'scripts/runtime/apply-vscode-templates.ps1'
$healthcheckScript = Join-Path $resolvedRepoRoot 'scripts/runtime/healthcheck.ps1'

$bootstrapArgs = @{
    RepoRoot = $resolvedRepoRoot
    TargetGithubPath = $TargetGithubPath
    TargetCodexPath = $TargetCodexPath
}
if ($Mirror) {
    $bootstrapArgs.Mirror = $true
}
if ($ApplyMcpConfig) {
    $bootstrapArgs.ApplyMcpConfig = $true
}
if ($BackupConfig) {
    $bootstrapArgs.BackupConfig = $true
}

$steps.Add((Invoke-ScriptStep -Name 'runtime-bootstrap' -ScriptPath $bootstrapScript -Arguments $bootstrapArgs)) | Out-Null

if ($ApplyVscodeTemplates) {
    $steps.Add((Invoke-ScriptStep -Name 'apply-vscode-templates' -ScriptPath $applyVscodeTemplatesScript -Arguments @{ RepoRoot = $resolvedRepoRoot; Force = $true })) | Out-Null
}
else {
    Write-Log -Level 'WARN' -Message 'Skipping VS Code templates apply (enable with -ApplyVscodeTemplates).'
}

$healthcheckReportPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/healthcheck-report.json'
$healthcheckLogPath = Resolve-RepoPath -Root $resolvedRepoRoot -Path '.temp/logs/healthcheck-from-self-heal.log'
$healthcheckArgs = @{
    RepoRoot = $resolvedRepoRoot
    TargetGithubPath = $TargetGithubPath
    TargetCodexPath = $TargetCodexPath
    OutputPath = $healthcheckReportPath
    LogPath = $healthcheckLogPath
}
if ($StrictExtras) {
    $healthcheckArgs.StrictExtras = $true
}

$steps.Add((Invoke-ScriptStep -Name 'healthcheck' -ScriptPath $healthcheckScript -Arguments $healthcheckArgs)) | Out-Null

$passedSteps = @($steps | Where-Object { $_.status -eq 'passed' }).Count
$failedSteps = @($steps | Where-Object { $_.status -ne 'passed' }).Count
$overallStatus = if ($failedSteps -eq 0) { 'passed' } else { 'failed' }

$healthcheckSummary = $null
if (Test-Path -LiteralPath $healthcheckReportPath -PathType Leaf) {
    try {
        $healthcheckSummary = Get-Content -Raw -LiteralPath $healthcheckReportPath | ConvertFrom-Json -Depth 100
    }
    catch {
        Write-Log -Level 'WARN' -Message ("Could not parse healthcheck report: {0}" -f $healthcheckReportPath)
    }
}

$report = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    repoRoot = $resolvedRepoRoot
    targets = [ordered]@{
        github = $TargetGithubPath
        codex = $TargetCodexPath
    }
    options = [ordered]@{
        mirror = [bool] $Mirror
        applyMcpConfig = [bool] $ApplyMcpConfig
        backupConfig = [bool] $BackupConfig
        applyVscodeTemplates = [bool] $ApplyVscodeTemplates
        strictExtras = [bool] $StrictExtras
    }
    summary = [ordered]@{
        totalSteps = $steps.Count
        passedSteps = $passedSteps
        failedSteps = $failedSteps
        overallStatus = $overallStatus
    }
    steps = $steps.ToArray()
    healthcheck = $healthcheckSummary
    logPath = $resolvedLogPath
}

$reportJson = $report | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $resolvedOutputPath -Value $reportJson

Write-Log -Level 'INFO' -Message ("Self-heal summary: total={0} passed={1} failed={2}" -f $steps.Count, $passedSteps, $failedSteps)
Write-Log -Level 'INFO' -Message ("Self-heal report generated: {0}" -f $resolvedOutputPath)

if ($overallStatus -ne 'passed') {
    exit 1
}

exit 0