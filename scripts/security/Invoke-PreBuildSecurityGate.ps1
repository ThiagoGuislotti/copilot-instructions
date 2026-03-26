<#
.SYNOPSIS
    Runs unified pre-build dependency vulnerability gate across .NET, frontend, and Rust.

.DESCRIPTION
    Executes stack-specific vulnerability audit scripts and consolidates results in a
    single quality gate flow before build/package operations.

    Managed audits:
    - .NET backend: scripts/security/Invoke-VulnerabilityAudit.ps1
    - Frontend: scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1
    - Rust: scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1

    Exit code:
    - 0 when all enabled audits pass (or WarningOnly is true)
    - 1 when one or more enabled audits fail and WarningOnly is false

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects from current path.

.PARAMETER DotnetSolutionPath
    Relative or absolute solution/filter path for .NET vulnerability audit.
    Default: NetToolsKit.sln

.PARAMETER SkipDotnet
    Skips .NET dependency vulnerability audit.

.PARAMETER FrontendProjectPaths
    Relative or absolute frontend project directories containing package.json.
    If omitted and AutoDetectFrontend is true, directories are discovered automatically.

.PARAMETER AutoDetectFrontend
    Enables automatic frontend project discovery when FrontendProjectPaths is empty.
    Default: true

.PARAMETER FrontendPackageManager
    Package manager mode forwarded to frontend audit script.
    Default: auto

.PARAMETER SkipFrontend
    Skips frontend dependency vulnerability audit.

.PARAMETER RustProjectPaths
    Relative or absolute Rust project/workspace directories containing Cargo.toml.
    If omitted and AutoDetectRust is true, directories are discovered automatically.

.PARAMETER AutoDetectRust
    Enables automatic Rust project discovery when RustProjectPaths is empty.
    Default: true

.PARAMETER AllowMissingCargoAudit
    Forwards to Rust audit script, allowing skip when cargo-audit is unavailable.

.PARAMETER SkipRust
    Skips Rust dependency vulnerability audit.

.PARAMETER InstallMissingPrerequisites
    Runs prerequisite installer before audits to auto-install missing commands when possible.

.PARAMETER AllowSystemPrerequisiteInstall
    Allows prerequisite installer to use system package managers (winget/choco/brew/apt/etc).

.PARAMETER FailOnSeverities
    Severity values that fail each stack quality gate.
    Default: Critical, High

.PARAMETER WarningOnly
    When true, gate failures are emitted as warnings and script exits with success.
    Default: false

.PARAMETER DetailedLogs
    Enables verbose diagnostic logs.

.EXAMPLE
    pwsh -File scripts/security/Invoke-PreBuildSecurityGate.ps1

.EXAMPLE
    pwsh -File scripts/security/Invoke-PreBuildSecurityGate.ps1 `
      -FrontendProjectPaths src/WebApp,apps/Portal `
      -RustProjectPaths crates/core `
      -FailOnSeverities Critical,High

.EXAMPLE
    pwsh -File scripts/security/Invoke-PreBuildSecurityGate.ps1 `
      -InstallMissingPrerequisites `
      -AllowSystemPrerequisiteInstall `
      -FailOnSeverities Critical,High

.NOTES
    Version: 1.1
    Requirements: PowerShell 7+.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $RepoRoot,

    [Parameter(Mandatory = $false)]
    [string] $DotnetSolutionPath = 'NetToolsKit.sln',

    [Parameter(Mandatory = $false)]
    [switch] $SkipDotnet,

    [Parameter(Mandatory = $false)]
    [string[]] $FrontendProjectPaths = @(),

    [Parameter(Mandatory = $false)]
    [bool] $AutoDetectFrontend = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet('auto', 'npm', 'pnpm', 'yarn')]
    [string] $FrontendPackageManager = 'auto',

    [Parameter(Mandatory = $false)]
    [switch] $SkipFrontend,

    [Parameter(Mandatory = $false)]
    [string[]] $RustProjectPaths = @(),

    [Parameter(Mandatory = $false)]
    [bool] $AutoDetectRust = $true,

    [Parameter(Mandatory = $false)]
    [switch] $AllowMissingCargoAudit,

    [Parameter(Mandatory = $false)]
    [switch] $SkipRust,

    [Parameter(Mandatory = $false)]
    [switch] $InstallMissingPrerequisites,

    [Parameter(Mandatory = $false)]
    [switch] $AllowSystemPrerequisiteInstall,

    [Parameter(Mandatory = $false)]
    [string[]] $FailOnSeverities = @('Critical', 'High'),

    [Parameter(Mandatory = $false)]
    [bool] $WarningOnly = $false,

    [Parameter(Mandatory = $false)]
    [switch] $DetailedLogs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:IsDetailedLogsEnabled = [bool] $DetailedLogs
$script:IsVerboseEnabled = [bool] $DetailedLogs
$script:IsWarningOnly = [bool] $WarningOnly
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:AuditRuns = New-Object System.Collections.Generic.List[object]

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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')
# Registers a failing gate condition in the consolidated pre-build security summary.
function Add-GateFailure {
    param([string] $Message)

    if ($script:IsWarningOnly) {
        $script:Warnings.Add($Message) | Out-Null
        Write-StyledOutput ("[WARN] {0}" -f $Message)
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers non-blocking warning.
function Add-GateWarning {
    param([string] $Message)

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}
# Resolves audit script path from local script directory first, then repository candidates.
function Resolve-AuditScriptPath {
    param(
        [string] $RootPath,
        [string] $ScriptFileName
    )

    $localCandidate = Join-Path $PSScriptRoot $ScriptFileName
    if (Test-Path -LiteralPath $localCandidate -PathType Leaf) {
        return [System.IO.Path]::GetFullPath($localCandidate)
    }

    $candidateList = @(
        (Resolve-PathFromRoot -RootPath $RootPath -PathValue ("scripts/security/{0}" -f $ScriptFileName))
    )

    foreach ($candidate in $candidateList) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw "Audit script not found for '$ScriptFileName'. Checked local security folder and scripts/security."
}

# Converts absolute path to repository-relative path.
function Convert-ToRelativePath {
    param(
        [string] $RootPath,
        [string] $TargetPath
    )

    $relative = [System.IO.Path]::GetRelativePath($RootPath, $TargetPath)
    return $relative.Replace('\', '/')
}

# Converts relative path to stable folder token.
function Convert-ToPathToken {
    param([string] $Value)

    $token = $Value.Replace('\', '_').Replace('/', '_').Replace(':', '_')
    $token = [System.Text.RegularExpressions.Regex]::Replace($token, '[^A-Za-z0-9._-]', '_')
    if ([string]::IsNullOrWhiteSpace($token)) {
        return 'root'
    }

    return $token
}

# Checks whether path is under ignored discovery folders.
function Test-IsIgnoredPath {
    param(
        [string] $RootPath,
        [string] $CandidatePath
    )

    $relative = Convert-ToRelativePath -RootPath $RootPath -TargetPath $CandidatePath
    $ignoredPrefixes = @(
        '.git/',
        '.temp/',
        'node_modules/',
        'bin/',
        'obj/',
        'target/',
        '.vscode/',
        '.idea/'
    )

    foreach ($prefix in $ignoredPrefixes) {
        if ($relative.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

# Returns frontend project directories that contain package.json.
function Get-FrontendProjectPathList {
    param([string] $RootPath)

    $results = New-Object System.Collections.Generic.List[string]
    $files = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter 'package.json')
    foreach ($file in $files) {
        $directory = $file.Directory.FullName
        if (Test-IsIgnoredPath -RootPath $RootPath -CandidatePath $directory) {
            continue
        }

        $results.Add($directory) | Out-Null
    }

    return @($results | Sort-Object -Unique)
}

# Returns Rust project directories that contain Cargo.toml.
function Get-RustProjectPathList {
    param([string] $RootPath)

    $results = New-Object System.Collections.Generic.List[string]
    $files = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter 'Cargo.toml')
    foreach ($file in $files) {
        $directory = $file.Directory.FullName
        if (Test-IsIgnoredPath -RootPath $RootPath -CandidatePath $directory) {
            continue
        }

        $results.Add($directory) | Out-Null
    }

    return @($results | Sort-Object -Unique)
}

# Executes external command and captures output.
function Invoke-ExternalCommand {
    param(
        [string] $CommandName,
        [string[]] $Arguments
    )

    Write-VerboseLog ("Executing command: {0} {1}" -f $CommandName, ($Arguments -join ' '))
    $capturedOutput = & $CommandName @Arguments 2>&1
    return [pscustomobject]@{
        ExitCode = [int] $LASTEXITCODE
        OutputText = ($capturedOutput | Out-String)
    }
}

# Runs one audit script and records gate status.
function Invoke-AuditScript {
    param(
        [string] $AuditName,
        [string] $ScriptPath,
        [string[]] $ArgumentList
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        Add-GateFailure ("Missing audit script for '{0}': {1}" -f $AuditName, $ScriptPath)
        return
    }

    $commandArgs = @('-NoLogo', '-NoProfile', '-File', $ScriptPath)
    $commandArgs += $ArgumentList
    $commandResult = Invoke-ExternalCommand -CommandName 'pwsh' -Arguments $commandArgs

    if (-not [string]::IsNullOrWhiteSpace($commandResult.OutputText)) {
        $commandResult.OutputText.TrimEnd() -split "`r?`n" | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                Write-StyledOutput $_
            }
        }
    }

    $status = if ($commandResult.ExitCode -eq 0) { 'PASS' } else { 'FAIL' }
    $script:AuditRuns.Add([pscustomobject]@{
            name = $AuditName
            script = $ScriptPath
            exitCode = $commandResult.ExitCode
            status = $status
        }) | Out-Null

    if ($commandResult.ExitCode -ne 0) {
        Add-GateFailure ("Audit '{0}' failed with exit code {1}." -f $AuditName, $commandResult.ExitCode)
    }
    else {
        Write-StyledOutput ("[OK] Audit '{0}' completed with PASS." -f $AuditName)
    }
}

# Runs prerequisite setup script before security audits when enabled.
function Invoke-PrerequisiteSetup {
    param(
        [string] $RootPath,
        [bool] $DotnetEnabled,
        [bool] $FrontendEnabled,
        [bool] $RustEnabled,
        [string[]] $ResolvedFrontendPaths,
        [string[]] $ResolvedRustPaths
    )

    if (-not $InstallMissingPrerequisites) {
        return
    }

    $prerequisiteScript = Resolve-AuditScriptPath -RootPath $RootPath -ScriptFileName 'Install-SecurityAuditPrerequisites.ps1'
    $prerequisiteArgs = @(
        '-RepoRoot', $RootPath,
        '-FrontendPackageManager', $FrontendPackageManager
    )

    if (-not $DotnetEnabled) {
        $prerequisiteArgs += '-SkipDotnet'
    }

    if (-not $FrontendEnabled -or @($ResolvedFrontendPaths).Count -eq 0) {
        $prerequisiteArgs += '-SkipFrontend'
    }

    if (-not $RustEnabled -or @($ResolvedRustPaths).Count -eq 0) {
        $prerequisiteArgs += '-SkipRust'
    }

    if ($AllowSystemPrerequisiteInstall) {
        $prerequisiteArgs += '-AllowSystemInstall'
    }

    if ($DetailedLogs) {
        $prerequisiteArgs += '-DetailedLogs'
    }

    Invoke-AuditScript -AuditName 'Security audit prerequisites setup' -ScriptPath $prerequisiteScript -ArgumentList $prerequisiteArgs
}

# Writes consolidated gate summary artifacts.
function Write-GateSummaryArtifact {
    param(
        [string] $RootPath,
        [bool] $DotnetEnabled,
        [bool] $FrontendEnabled,
        [bool] $RustEnabled,
        [string] $DotnetSolution,
        [string[]] $FrontendPaths,
        [string[]] $RustPaths
    )

    $outputDirectory = Resolve-PathFromRoot -RootPath $RootPath -PathValue '.temp/vulnerability-audit'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

    $summaryPath = Join-Path $outputDirectory 'prebuild-security-gate-summary.md'
    $jsonPath = Join-Path $outputDirectory 'prebuild-security-gate-summary.json'

    $status = if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) { 'FAIL' } else { 'PASS' }
    $summaryLines = @(
        '# Pre-Build Security Gate Summary',
        '',
        "- Executed At (UTC): $((Get-Date).ToUniversalTime().ToString('o'))",
        "- Repo Root: $RootPath",
        "- Warning Only: $script:IsWarningOnly",
        "- Fail-On Severities: $($FailOnSeverities -join ', ')",
        "- Overall Status: $status",
        '',
        '## Scope',
        "- Dotnet Enabled: $DotnetEnabled",
        "- Dotnet Solution: $DotnetSolution",
        "- Frontend Enabled: $FrontendEnabled",
        "- Frontend Projects: $(@($FrontendPaths).Count)",
        "- Rust Enabled: $RustEnabled",
        "- Rust Projects: $(@($RustPaths).Count)",
        '',
        '## Audit Runs'
    )

    if ($script:AuditRuns.Count -eq 0) {
        $summaryLines += '- none'
    }
    else {
        foreach ($audit in $script:AuditRuns) {
            $summaryLines += ("- {0}: {1} (exit={2})" -f $audit.name, $audit.status, $audit.exitCode)
        }
    }

    $summaryLines += ''
    $summaryLines += '## Gate Findings'
    if ($script:Failures.Count -eq 0 -and $script:Warnings.Count -eq 0) {
        $summaryLines += '- none'
    }
    else {
        foreach ($failure in $script:Failures) {
            $summaryLines += ("- FAIL: {0}" -f $failure)
        }

        foreach ($warning in $script:Warnings) {
            $summaryLines += ("- WARN: {0}" -f $warning)
        }
    }

    $summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    $jsonReport = [ordered]@{
        executedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        repoRoot = $RootPath
        warningOnly = $script:IsWarningOnly
        failOnSeverities = @($FailOnSeverities)
        scope = @{
            dotnet = @{
                enabled = $DotnetEnabled
                solutionPath = $DotnetSolution
            }
            frontend = @{
                enabled = $FrontendEnabled
                packageManager = $FrontendPackageManager
                projectPaths = @($FrontendPaths)
            }
            rust = @{
                enabled = $RustEnabled
                projectPaths = @($RustPaths)
                allowMissingCargoAudit = [bool] $AllowMissingCargoAudit
            }
        }
        auditRuns = @($script:AuditRuns.ToArray())
        failures = @($script:Failures.ToArray())
        warnings = @($script:Warnings.ToArray())
        overallStatus = $status
    }

    $jsonReport | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    Write-StyledOutput ("[INFO] Consolidated summary written to '{0}'." -f $summaryPath)
    Write-StyledOutput ("[INFO] Consolidated json written to '{0}'." -f $jsonPath)
}

try {
    $resolvedRepoRoot = Resolve-GitRootOrCurrentPath -RequestedRoot $RepoRoot
    Set-Location -LiteralPath $resolvedRepoRoot
    Write-StyledOutput ("[INFO] Repo root: {0}" -f $resolvedRepoRoot)
    Write-VerboseLog ("InstallMissingPrerequisites: {0}" -f [bool] $InstallMissingPrerequisites)
    Write-VerboseLog ("AllowSystemPrerequisiteInstall: {0}" -f [bool] $AllowSystemPrerequisiteInstall)

    $dotnetAuditScript = Resolve-AuditScriptPath -RootPath $resolvedRepoRoot -ScriptFileName 'Invoke-VulnerabilityAudit.ps1'
    $frontendAuditScript = Resolve-AuditScriptPath -RootPath $resolvedRepoRoot -ScriptFileName 'Invoke-FrontendPackageVulnerabilityAudit.ps1'
    $rustAuditScript = Resolve-AuditScriptPath -RootPath $resolvedRepoRoot -ScriptFileName 'Invoke-RustPackageVulnerabilityAudit.ps1'

    $dotnetEnabled = -not $SkipDotnet
    $frontendEnabled = -not $SkipFrontend
    $rustEnabled = -not $SkipRust

    $resolvedDotnetSolution = Resolve-PathFromRoot -RootPath $resolvedRepoRoot -PathValue $DotnetSolutionPath

    $resolvedFrontendPaths = @()
    if ($frontendEnabled) {
        if (@($FrontendProjectPaths).Count -gt 0) {
            $resolvedFrontendPaths = @($FrontendProjectPaths | ForEach-Object {
                    Resolve-PathFromRoot -RootPath $resolvedRepoRoot -PathValue $_
                })
        }
        elseif ($AutoDetectFrontend) {
            $resolvedFrontendPaths = @(Get-FrontendProjectPathList -RootPath $resolvedRepoRoot)
        }
    }

    $resolvedRustPaths = @()
    if ($rustEnabled) {
        if (@($RustProjectPaths).Count -gt 0) {
            $resolvedRustPaths = @($RustProjectPaths | ForEach-Object {
                    Resolve-PathFromRoot -RootPath $resolvedRepoRoot -PathValue $_
                })
        }
        elseif ($AutoDetectRust) {
            $resolvedRustPaths = @(Get-RustProjectPathList -RootPath $resolvedRepoRoot)
        }
    }

    Invoke-PrerequisiteSetup `
        -RootPath $resolvedRepoRoot `
        -DotnetEnabled $dotnetEnabled `
        -FrontendEnabled $frontendEnabled `
        -RustEnabled $rustEnabled `
        -ResolvedFrontendPaths $resolvedFrontendPaths `
        -ResolvedRustPaths $resolvedRustPaths

    if ($dotnetEnabled) {
        if (-not (Test-Path -LiteralPath $resolvedDotnetSolution -PathType Leaf)) {
            Add-GateFailure ("Dotnet solution not found: {0}" -f $resolvedDotnetSolution)
        }
        else {
            $dotnetOutput = '.temp/vulnerability-audit/dotnet'
            $dotnetArgs = @(
                '-RepoRoot', $resolvedRepoRoot,
                '-SolutionPath', $resolvedDotnetSolution,
                '-OutputDir', $dotnetOutput,
                '-FailOnSeverities'
            )
            $dotnetArgs += $FailOnSeverities
            if ($DetailedLogs) {
                $dotnetArgs += '-DetailedLogs'
            }

            Invoke-AuditScript -AuditName '.NET dependency audit' -ScriptPath $dotnetAuditScript -ArgumentList $dotnetArgs
        }
    }

    if ($frontendEnabled) {
        if ($resolvedFrontendPaths.Count -eq 0) {
            Add-GateWarning 'No frontend projects found for vulnerability audit.'
        }
        else {
            foreach ($frontendPath in $resolvedFrontendPaths) {
                if (-not (Test-Path -LiteralPath (Join-Path $frontendPath 'package.json') -PathType Leaf)) {
                    Add-GateFailure ("Frontend project missing package.json: {0}" -f $frontendPath)
                    continue
                }

                $relativePath = Convert-ToRelativePath -RootPath $resolvedRepoRoot -TargetPath $frontendPath
                $pathToken = Convert-ToPathToken -Value $relativePath
                $frontendOutput = ".temp/vulnerability-audit/frontend/$pathToken"

                $frontendArgs = @(
                    '-RepoRoot', $resolvedRepoRoot,
                    '-ProjectPath', $frontendPath,
                    '-PackageManager', $FrontendPackageManager,
                    '-OutputDir', $frontendOutput,
                    '-FailOnSeverities'
                )
                $frontendArgs += $FailOnSeverities
                if ($DetailedLogs) {
                    $frontendArgs += '-DetailedLogs'
                }

                Invoke-AuditScript -AuditName ("Frontend dependency audit ({0})" -f $relativePath) -ScriptPath $frontendAuditScript -ArgumentList $frontendArgs
            }
        }
    }

    if ($rustEnabled) {
        if ($resolvedRustPaths.Count -eq 0) {
            Add-GateWarning 'No Rust projects found for vulnerability audit.'
        }
        else {
            foreach ($rustPath in $resolvedRustPaths) {
                if (-not (Test-Path -LiteralPath (Join-Path $rustPath 'Cargo.toml') -PathType Leaf)) {
                    Add-GateFailure ("Rust project missing Cargo.toml: {0}" -f $rustPath)
                    continue
                }

                $relativePath = Convert-ToRelativePath -RootPath $resolvedRepoRoot -TargetPath $rustPath
                $pathToken = Convert-ToPathToken -Value $relativePath
                $rustOutput = ".temp/vulnerability-audit/rust/$pathToken"

                $rustArgs = @(
                    '-RepoRoot', $resolvedRepoRoot,
                    '-ProjectPath', $rustPath,
                    '-OutputDir', $rustOutput,
                    '-FailOnSeverities'
                )
                $rustArgs += $FailOnSeverities
                if ($AllowMissingCargoAudit) {
                    $rustArgs += '-AllowMissingCargoAudit'
                }
                if ($DetailedLogs) {
                    $rustArgs += '-DetailedLogs'
                }

                Invoke-AuditScript -AuditName ("Rust dependency audit ({0})" -f $relativePath) -ScriptPath $rustAuditScript -ArgumentList $rustArgs
            }
        }
    }

    Write-GateSummaryArtifact `
        -RootPath $resolvedRepoRoot `
        -DotnetEnabled $dotnetEnabled `
        -FrontendEnabled $frontendEnabled `
        -RustEnabled $rustEnabled `
        -DotnetSolution $resolvedDotnetSolution `
        -FrontendPaths $resolvedFrontendPaths `
        -RustPaths $resolvedRustPaths

    Write-StyledOutput ''
    Write-StyledOutput '[INFO] Pre-build security gate summary'
    Write-StyledOutput ("  Audit runs: {0}" -f $script:AuditRuns.Count)
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

    if ($script:Failures.Count -gt 0 -and -not $script:IsWarningOnly) {
        Write-StyledOutput '[FAIL] Pre-build security gate failed.'
        exit 1
    }

    if ($script:Failures.Count -gt 0 -and $script:IsWarningOnly) {
        Write-StyledOutput '[WARN] Pre-build security gate has failures, but WarningOnly mode is enabled.'
    }
    else {
        Write-StyledOutput '[OK] Pre-build security gate passed.'
    }

    exit 0
}
catch {
    Write-StyledOutput ("[FAIL] {0}" -f $_.Exception.Message)
    exit 1
}