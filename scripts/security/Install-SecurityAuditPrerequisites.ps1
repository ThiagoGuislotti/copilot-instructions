<#
.SYNOPSIS
    Validates and optionally installs prerequisites for security vulnerability audits.

.DESCRIPTION
    Checks required runtime commands for .NET, frontend package managers, and Rust
    vulnerability scripts, then performs best-effort installation for missing tools.

    Installation behavior:
    - Always attempts user-level installs when available (cargo-audit via cargo, pnpm/yarn via npm).
    - Optionally attempts system package manager installs when -AllowSystemInstall is set.
    - Fails when required prerequisites remain unavailable after installation attempts.

    Exit code:
    - 0 when all requested prerequisites are available
    - 1 when one or more prerequisites are still missing

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects from git root or current path.

.PARAMETER FrontendPackageManager
    Frontend package manager mode:
    - auto: accept npm/pnpm/yarn if any is available
    - npm
    - pnpm
    - yarn

.PARAMETER SkipDotnet
    Skips .NET prerequisite checks.

.PARAMETER SkipFrontend
    Skips frontend prerequisite checks.

.PARAMETER SkipRust
    Skips Rust prerequisite checks.

.PARAMETER AllowSystemInstall
    Enables best-effort system package manager installs for missing toolchains.

.PARAMETER DetailedLogs
    Enables verbose diagnostics.

.EXAMPLE
    pwsh -File scripts/security/Install-SecurityAuditPrerequisites.ps1

.EXAMPLE
    pwsh -File scripts/security/Install-SecurityAuditPrerequisites.ps1 `
      -FrontendPackageManager pnpm `
      -AllowSystemInstall `
      -DetailedLogs

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet('auto', 'npm', 'pnpm', 'yarn')]
    [string] $FrontendPackageManager = 'auto',

    [Parameter(Mandatory = $false)]
    [switch] $SkipDotnet,

    [Parameter(Mandatory = $false)]
    [switch] $SkipFrontend,

    [Parameter(Mandatory = $false)]
    [switch] $SkipRust,

    [Parameter(Mandatory = $false)]
    [switch] $AllowSystemInstall,

    [Parameter(Mandatory = $false)]
    [switch] $DetailedLogs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:IsDetailedLogsEnabled = [bool] $DetailedLogs
$script:IsVerboseEnabled = [bool] $DetailedLogs
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

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
# Registers a prerequisite setup warning in the in-memory result summary.
function Add-SetupWarning {
    param([string] $Message)

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Registers blocking failure.
function Add-SetupFailure {
    param([string] $Message)

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}
# Checks whether command is available in current PATH.
function Test-CommandAvailability {
    param([string] $CommandName)

    return $null -ne (Get-Command -Name $CommandName -ErrorAction SilentlyContinue)
}

# Executes external command and captures output + exit code.
function Invoke-ExternalCommand {
    param(
        [string] $CommandName,
        [string[]] $Arguments
    )

    $capturedOutput = @()
    $exitCode = 0
    try {
        $capturedOutput = & $CommandName @Arguments 2>&1
        $exitCode = [int] $LASTEXITCODE
    }
    catch {
        $capturedOutput = @($_.Exception.Message)
        $exitCode = 1
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        OutputText = [string] ($capturedOutput | Out-String)
    }
}

# Returns normalized platform identifier.
function Get-PlatformName {
    if ($IsWindows) { return 'windows' }
    if ($IsMacOS) { return 'macos' }
    if ($IsLinux) { return 'linux' }
    return 'unknown'
}

# Returns preferred system package manager available in current environment.
function Get-PackageManagerName {
    param([string] $PlatformName)

    if ($PlatformName -eq 'windows') {
        foreach ($manager in @('winget', 'choco', 'scoop')) {
            if (Test-CommandAvailability -CommandName $manager) {
                return $manager
            }
        }

        return $null
    }

    if ($PlatformName -eq 'macos') {
        if (Test-CommandAvailability -CommandName 'brew') {
            return 'brew'
        }

        return $null
    }

    if ($PlatformName -eq 'linux') {
        foreach ($manager in @('apt-get', 'dnf', 'yum', 'zypper', 'pacman')) {
            if (Test-CommandAvailability -CommandName $manager) {
                return $manager
            }
        }
    }

    return $null
}

# Returns command + arguments for one system install action.
function Get-SystemInstallCommand {
    param(
        [ValidateSet('dotnet', 'rust', 'node')]
        [string] $ToolId,
        [string] $PackageManager
    )

    switch ($PackageManager) {
        'winget' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'winget'; args = @('install', '--id', 'Microsoft.DotNet.SDK.8', '--exact', '--accept-source-agreements', '--accept-package-agreements') } }
                'rust' { return @{ command = 'winget'; args = @('install', '--id', 'Rustlang.Rustup', '--exact', '--accept-source-agreements', '--accept-package-agreements') } }
                'node' { return @{ command = 'winget'; args = @('install', '--id', 'OpenJS.NodeJS.LTS', '--exact', '--accept-source-agreements', '--accept-package-agreements') } }
            }
        }
        'choco' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'choco'; args = @('install', 'dotnet-8.0-sdk', '-y') } }
                'rust' { return @{ command = 'choco'; args = @('install', 'rustup.install', '-y') } }
                'node' { return @{ command = 'choco'; args = @('install', 'nodejs-lts', '-y') } }
            }
        }
        'scoop' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'scoop'; args = @('install', 'dotnet-sdk') } }
                'rust' { return @{ command = 'scoop'; args = @('install', 'rustup') } }
                'node' { return @{ command = 'scoop'; args = @('install', 'nodejs-lts') } }
            }
        }
        'brew' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'brew'; args = @('install', '--cask', 'dotnet-sdk') } }
                'rust' { return @{ command = 'brew'; args = @('install', 'rustup-init') } }
                'node' { return @{ command = 'brew'; args = @('install', 'node') } }
            }
        }
        'apt-get' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'apt-get'; args = @('install', '-y', 'dotnet-sdk-8.0') } }
                'rust' { return @{ command = 'apt-get'; args = @('install', '-y', 'cargo', 'rustc') } }
                'node' { return @{ command = 'apt-get'; args = @('install', '-y', 'nodejs', 'npm') } }
            }
        }
        'dnf' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'dnf'; args = @('install', '-y', 'dotnet-sdk-8.0') } }
                'rust' { return @{ command = 'dnf'; args = @('install', '-y', 'cargo', 'rust') } }
                'node' { return @{ command = 'dnf'; args = @('install', '-y', 'nodejs', 'npm') } }
            }
        }
        'yum' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'yum'; args = @('install', '-y', 'dotnet-sdk-8.0') } }
                'rust' { return @{ command = 'yum'; args = @('install', '-y', 'cargo', 'rust') } }
                'node' { return @{ command = 'yum'; args = @('install', '-y', 'nodejs', 'npm') } }
            }
        }
        'zypper' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'zypper'; args = @('--non-interactive', 'install', 'dotnet-sdk-8.0') } }
                'rust' { return @{ command = 'zypper'; args = @('--non-interactive', 'install', 'cargo', 'rust') } }
                'node' { return @{ command = 'zypper'; args = @('--non-interactive', 'install', 'nodejs', 'npm') } }
            }
        }
        'pacman' {
            switch ($ToolId) {
                'dotnet' { return @{ command = 'pacman'; args = @('-S', '--noconfirm', 'dotnet-sdk') } }
                'rust' { return @{ command = 'pacman'; args = @('-S', '--noconfirm', 'rustup') } }
                'node' { return @{ command = 'pacman'; args = @('-S', '--noconfirm', 'nodejs', 'npm') } }
            }
        }
    }

    return $null
}

# Installs missing tool through detected system package manager.
function Install-SystemTool {
    param(
        [ValidateSet('dotnet', 'rust', 'node')]
        [string] $ToolId,
        [string] $PlatformName
    )

    if (-not $AllowSystemInstall) {
        return $false
    }

    $packageManager = Get-PackageManagerName -PlatformName $PlatformName
    if ([string]::IsNullOrWhiteSpace($packageManager)) {
        Add-SetupWarning ("No supported system package manager found to install '{0}'." -f $ToolId)
        return $false
    }

    $installCommand = Get-SystemInstallCommand -ToolId $ToolId -PackageManager $packageManager
    if ($null -eq $installCommand) {
        Add-SetupWarning ("No install mapping available for tool '{0}' with manager '{1}'." -f $ToolId, $packageManager)
        return $false
    }

    $commandName = [string] $installCommand.command
    $commandArgs = @($installCommand.args)
    $isLinuxRoot = $false
    if ($PlatformName -eq 'linux' -and (Test-CommandAvailability -CommandName 'id')) {
        $idResult = Invoke-ExternalCommand -CommandName 'id' -Arguments @('-u')
        $isLinuxRoot = $idResult.ExitCode -eq 0 -and [string]::Equals($idResult.OutputText.Trim(), '0', [System.StringComparison]::Ordinal)
    }

    $hasSudo = Test-CommandAvailability -CommandName 'sudo'
    $requiresSudo = $PlatformName -eq 'linux' -and -not $isLinuxRoot -and $hasSudo

    if ($requiresSudo) {
        $commandArgs = @($commandName) + $commandArgs
        $commandName = 'sudo'
    }
    elseif ($PlatformName -eq 'linux' -and -not $isLinuxRoot -and -not $hasSudo) {
        Add-SetupWarning ("Running linux system install for '{0}' without sudo; this may fail due permissions." -f $ToolId)
    }

    Write-StyledOutput ("[INFO] Attempting system install for '{0}' using '{1}'." -f $ToolId, $packageManager)
    $installResult = Invoke-ExternalCommand -CommandName $commandName -Arguments $commandArgs
    if ($installResult.ExitCode -eq 0) {
        Write-StyledOutput ("[OK] System install completed for '{0}'." -f $ToolId)
        return $true
    }

    Add-SetupWarning ("System install failed for '{0}' with '{1}' (exit={2})." -f $ToolId, $packageManager, $installResult.ExitCode)
    Write-VerboseLog ("Install output for '{0}': {1}" -f $ToolId, $installResult.OutputText)
    return $false
}

# Ensures command exists, optionally attempting system install.
function Test-CommandWithInstall {
    param(
        [string] $CommandName,
        [ValidateSet('dotnet', 'rust', 'node')]
        [string] $ToolId,
        [string] $PlatformName
    )

    if (Test-CommandAvailability -CommandName $CommandName) {
        Write-StyledOutput ("[OK] Command available: {0}" -f $CommandName)
        return $true
    }

    Add-SetupWarning ("Command not found in PATH: {0}" -f $CommandName)
    $installed = Install-SystemTool -ToolId $ToolId -PlatformName $PlatformName
    if ($installed -and (Test-CommandAvailability -CommandName $CommandName)) {
        Write-StyledOutput ("[OK] Command installed and available: {0}" -f $CommandName)
        return $true
    }

    return $false
}

# Ensures cargo-audit command is available through cargo.
function Install-CargoAuditTool {
    if (-not (Test-CommandAvailability -CommandName 'cargo')) {
        Add-SetupFailure "Cannot install cargo-audit because 'cargo' is unavailable."
        return
    }

    $versionCheck = Invoke-ExternalCommand -CommandName 'cargo' -Arguments @('audit', '--version')
    if ($versionCheck.ExitCode -eq 0) {
        Write-StyledOutput '[OK] cargo-audit already installed.'
        return
    }

    Write-StyledOutput '[INFO] Installing cargo-audit with cargo.'
    $installResult = Invoke-ExternalCommand -CommandName 'cargo' -Arguments @('install', 'cargo-audit', '--locked')
    if ($installResult.ExitCode -ne 0) {
        Add-SetupFailure ("Failed to install cargo-audit (exit={0})." -f $installResult.ExitCode)
        Write-VerboseLog ("cargo-audit install output: {0}" -f $installResult.OutputText)
        return
    }

    $postCheck = Invoke-ExternalCommand -CommandName 'cargo' -Arguments @('audit', '--version')
    if ($postCheck.ExitCode -eq 0) {
        Write-StyledOutput '[OK] cargo-audit installed successfully.'
        return
    }

    Add-SetupFailure 'cargo-audit install completed but command is still unavailable.'
}

# Ensures pnpm/yarn is available, using npm global install when needed.
function Install-NodePackageManager {
    param(
        [ValidateSet('pnpm', 'yarn')]
        [string] $ManagerName
    )

    if (Test-CommandAvailability -CommandName $ManagerName) {
        Write-StyledOutput ("[OK] Command available: {0}" -f $ManagerName)
        return
    }

    if (-not (Test-CommandAvailability -CommandName 'npm')) {
        Add-SetupFailure ("Cannot install '{0}' because 'npm' is unavailable." -f $ManagerName)
        return
    }

    Write-StyledOutput ("[INFO] Installing '{0}' globally with npm." -f $ManagerName)
    $installResult = Invoke-ExternalCommand -CommandName 'npm' -Arguments @('install', '--global', $ManagerName)
    if ($installResult.ExitCode -ne 0) {
        Add-SetupFailure ("Failed to install '{0}' via npm (exit={1})." -f $ManagerName, $installResult.ExitCode)
        Write-VerboseLog ("npm install output for '{0}': {1}" -f $ManagerName, $installResult.OutputText)
        return
    }

    if (Test-CommandAvailability -CommandName $ManagerName) {
        Write-StyledOutput ("[OK] Installed package manager: {0}" -f $ManagerName)
        return
    }

    Add-SetupFailure ("'{0}' install command completed but executable is still unavailable in PATH." -f $ManagerName)
}

# Checks and repairs prerequisites based on selected stack scope.
function Invoke-PrerequisiteSetup {
    param([string] $PlatformName)

    if (-not $SkipDotnet) {
        $hasDotnet = Test-CommandWithInstall -CommandName 'dotnet' -ToolId 'dotnet' -PlatformName $PlatformName
        if (-not $hasDotnet) {
            Add-SetupFailure "Missing prerequisite for .NET audit: 'dotnet'."
        }
    }

    if (-not $SkipRust) {
        $hasCargo = Test-CommandWithInstall -CommandName 'cargo' -ToolId 'rust' -PlatformName $PlatformName
        if ($hasCargo) {
            Install-CargoAuditTool
        }
        else {
            Add-SetupFailure "Missing prerequisite for Rust audit: 'cargo'."
        }
    }

    if (-not $SkipFrontend) {
        $resolvedManager = $FrontendPackageManager
        if ($resolvedManager -eq 'auto') {
            if (Test-CommandAvailability -CommandName 'pnpm') {
                $resolvedManager = 'pnpm'
            }
            elseif (Test-CommandAvailability -CommandName 'yarn') {
                $resolvedManager = 'yarn'
            }
            else {
                $resolvedManager = 'npm'
            }
        }

        if ($resolvedManager -eq 'npm') {
            $hasNpm = Test-CommandWithInstall -CommandName 'npm' -ToolId 'node' -PlatformName $PlatformName
            if (-not $hasNpm) {
                Add-SetupFailure "Missing prerequisite for frontend audit: 'npm'."
            }
            return
        }

        $hasNpmBase = Test-CommandWithInstall -CommandName 'npm' -ToolId 'node' -PlatformName $PlatformName
        if (-not $hasNpmBase) {
            Add-SetupFailure ("Missing prerequisite for frontend audit manager '{0}': npm/node." -f $resolvedManager)
            return
        }

        Install-NodePackageManager -ManagerName $resolvedManager
    }
}

try {
    $resolvedRepoRoot = Resolve-GitRootOrCurrentPath -RequestedRoot $RepoRoot
    Set-Location -LiteralPath $resolvedRepoRoot

    $platformName = Get-PlatformName
    Write-StyledOutput ("[INFO] Repo root: {0}" -f $resolvedRepoRoot)
    Write-StyledOutput ("[INFO] Platform: {0}" -f $platformName)
    Write-StyledOutput ("[INFO] Frontend manager mode: {0}" -f $FrontendPackageManager)
    Write-StyledOutput ("[INFO] System installs enabled: {0}" -f [bool] $AllowSystemInstall)
    Write-VerboseLog ("Skip scopes => Dotnet:{0} Frontend:{1} Rust:{2}" -f [bool] $SkipDotnet, [bool] $SkipFrontend, [bool] $SkipRust)

    Invoke-PrerequisiteSetup -PlatformName $platformName

    Write-StyledOutput ''
    Write-StyledOutput '[INFO] Prerequisite setup summary'
    Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
    Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

    if ($script:Failures.Count -gt 0) {
        Write-StyledOutput '[FAIL] Security audit prerequisites are incomplete.'
        exit 1
    }

    Write-StyledOutput '[OK] Security audit prerequisites are ready.'
    exit 0
}
catch {
    Write-StyledOutput ("[FAIL] {0}" -f $_.Exception.Message)
    exit 1
}