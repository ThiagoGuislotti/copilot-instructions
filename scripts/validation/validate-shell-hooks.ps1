<#
.SYNOPSIS
    Validates shell hook syntax for `.githooks` scripts.

.DESCRIPTION
    Performs syntax checks for required Git hook shell scripts using `sh -n`.
    When available and enabled, can also run `shellcheck` in warning mode.

    Required hooks:
    - .githooks/pre-commit
    - .githooks/post-commit
    - .githooks/post-merge
    - .githooks/post-checkout

    Exit code:
    - 0 in warning-only mode (default)
    - 1 when warning-only is disabled and failures are found

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.PARAMETER WarningOnly
    When true (default), findings are emitted as warnings and do not fail execution.

.PARAMETER EnableShellcheck
    Runs `shellcheck` when available. Missing shellcheck becomes a warning.

.PARAMETER Verbose
    Shows detailed diagnostics.

.EXAMPLE
    pwsh -File scripts/validation/validate-shell-hooks.ps1

.EXAMPLE
    pwsh -File scripts/validation/validate-shell-hooks.ps1 -EnableShellcheck

.EXAMPLE
    pwsh -File scripts/validation/validate-shell-hooks.ps1 -WarningOnly:$false

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string] $RepoRoot,
    [bool] $WarningOnly = $true,
    [switch] $EnableShellcheck,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

# Writes verbose diagnostics.
function Write-VerboseLog {
    param(
        [string] $Message
    )

    if ($script:IsVerboseEnabled) {
        Write-StyledOutput ("[VERBOSE] {0}" -f $Message)
    }
}

# Registers a validation failure.
function Add-ValidationFailure {
    param(
        [string] $Message
    )

    if ($script:IsWarningOnly) {
        $script:Warnings.Add($Message) | Out-Null
        Write-StyledOutput ("[WARN] {0}" -f $Message)
        return
    }

    $script:Failures.Add($Message) | Out-Null
    Write-StyledOutput ("[FAIL] {0}" -f $Message)
}

# Registers a validation warning.
function Add-ValidationWarning {
    param(
        [string] $Message
    )

    $script:Warnings.Add($Message) | Out-Null
    Write-StyledOutput ("[WARN] {0}" -f $Message)
}

# Resolves repository root from input and fallback candidates.
function Resolve-RepositoryRoot {
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
        for ($index = 0; $index -lt 6 -and -not [string]::IsNullOrWhiteSpace($current); $index++) {
            $hasLayout = (Test-Path -LiteralPath (Join-Path $current '.github')) -and (Test-Path -LiteralPath (Join-Path $current '.codex'))
            if ($hasLayout) {
                Write-VerboseLog ("Repository root detected: {0}" -f $current)
                return $current
            }

            $current = Split-Path -Path $current -Parent
        }
    }

    throw 'Could not detect repository root containing both .github and .codex.'
}

# Resolves a shell executable path for syntax checks.
function Resolve-ShellPath {
    $shellCommand = Get-Command -Name 'sh' -ErrorAction SilentlyContinue
    if ($null -ne $shellCommand) {
        return $shellCommand.Source
    }

    if ($IsWindows) {
        $windowsCandidates = @(
            'C:\Program Files\Git\usr\bin\sh.exe',
            'C:\Program Files\Git\bin\sh.exe'
        )
        foreach ($candidate in $windowsCandidates) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }

    return $null
}

# Executes shell syntax check for one hook file.
function Invoke-HookSyntaxCheck {
    param(
        [string] $ShellPath,
        [string] $HookPath
    )

    $output = @(& $ShellPath -n $HookPath 2>&1)
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    if ($exitCode -ne 0) {
        $details = ($output -join ' ').Trim()
        if ([string]::IsNullOrWhiteSpace($details)) {
            $details = 'no diagnostic output'
        }

        Add-ValidationFailure ("Shell syntax check failed: {0} :: {1}" -f $HookPath, $details)
        return
    }

    Write-VerboseLog ("Shell syntax OK: {0}" -f $HookPath)
}

# Executes optional shellcheck for one hook file.
function Invoke-HookShellcheck {
    param(
        [string] $HookPath
    )

    $shellcheckCommand = Get-Command -Name 'shellcheck' -ErrorAction SilentlyContinue
    if ($null -eq $shellcheckCommand) {
        Add-ValidationWarning 'shellcheck not found; optional shellcheck pass skipped.'
        return
    }

    $output = @(& $shellcheckCommand.Source -S warning $HookPath 2>&1)
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
    if ($exitCode -ne 0) {
        foreach ($line in $output) {
            $text = [string] $line
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                Add-ValidationWarning ("shellcheck: {0}" -f $text.Trim())
            }
        }
    }
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
Set-Location -Path $resolvedRepoRoot

$requiredHooks = @(
    '.githooks/pre-commit',
    '.githooks/post-commit',
    '.githooks/post-merge',
    '.githooks/post-checkout'
)

$shellPath = Resolve-ShellPath
if ([string]::IsNullOrWhiteSpace($shellPath)) {
    Add-ValidationFailure 'Shell runtime not found (`sh`). Install Git Bash (Windows) or POSIX shell.'
}
else {
    Write-VerboseLog ("Using shell runtime: {0}" -f $shellPath)
}

foreach ($relativeHook in $requiredHooks) {
    $hookPath = Join-Path $resolvedRepoRoot $relativeHook
    if (-not (Test-Path -LiteralPath $hookPath -PathType Leaf)) {
        Add-ValidationFailure ("Hook file not found: {0}" -f $relativeHook)
        continue
    }

    if (-not [string]::IsNullOrWhiteSpace($shellPath)) {
        Invoke-HookSyntaxCheck -ShellPath $shellPath -HookPath $hookPath
    }

    if ($EnableShellcheck) {
        Invoke-HookShellcheck -HookPath $hookPath
    }
}

Write-StyledOutput ''
Write-StyledOutput 'Shell hooks validation summary'
Write-StyledOutput ("  Hook files checked: {0}" -f $requiredHooks.Count)
Write-StyledOutput ("  Warning-only mode: {0}" -f $script:IsWarningOnly)
Write-StyledOutput ("  Warnings: {0}" -f $script:Warnings.Count)
Write-StyledOutput ("  Failures: {0}" -f $script:Failures.Count)

if ($script:Failures.Count -gt 0 -and (-not $script:IsWarningOnly)) {
    exit 1
}

if ($script:Failures.Count -gt 0 -or $script:Warnings.Count -gt 0) {
    Write-StyledOutput 'Shell hooks validation completed with warnings.'
}
else {
    Write-StyledOutput 'Shell hooks validation passed.'
}

exit 0