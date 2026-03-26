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
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths', 'validation-logging')
$script:ScriptRoot = Split-Path -Path $PSCommandPath -Parent
$script:IsVerboseEnabled = [bool] $Verbose
$script:IsWarningOnly = [bool] $WarningOnly
Initialize-ValidationState -WarningOnly $script:IsWarningOnly -VerboseEnabled $script:IsVerboseEnabled

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

# Validates repository shell hook parameter conventions that shell syntax checks cannot catch.
function Test-HookSemanticGuards {
    param(
        [string] $HookPath
    )

    $content = Get-Content -Raw -LiteralPath $HookPath
    $invalidWarningOnlyPattern = '(?im)-WarningOnly\s+(true|false)\b'
    if ($content -match $invalidWarningOnlyPattern) {
        Add-ValidationFailure ("Hook uses unsupported boolean argument form for PowerShell bool parameters: {0}. Use the single-quoted literal form '-WarningOnly:`$true' or '-WarningOnly:`$false' in shell hooks." -f $HookPath)
    }

    $invalidShellExpansionPattern = "(?im)(^|[ \t])-WarningOnly:\\\$(true|false)\b"
    if ($content -match $invalidShellExpansionPattern) {
        Add-ValidationFailure ("Hook passes a PowerShell boolean literal without shell-safe quoting: {0}. Use the single-quoted literal form '-WarningOnly:`$true' or '-WarningOnly:`$false' so POSIX shell does not expand `$true/`$false." -f $HookPath)
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

    Test-HookSemanticGuards -HookPath $hookPath

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