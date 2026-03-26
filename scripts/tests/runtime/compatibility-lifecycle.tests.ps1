<#
.SYNOPSIS
    Runtime tests for COMPATIBILITY lifecycle validation without external frameworks.

.DESCRIPTION
    Covers success and failure cases for lifecycle/EOL table validation.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/compatibility-lifecycle.tests.ps1

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
# Fails the current runtime test when the exit code differs from the expected value.
function Assert-ExitCode {
    param(
        [int] $ExitCode,
        [int] $Expected,
        [string] $Message
    )

    if ($ExitCode -ne $Expected) {
        throw $Message
    }
}

# Builds compatibility matrix test content for lifecycle validation scenarios.
function New-CompatibilityContent {
    param(
        [string] $ReferenceDate,
        [string[]] $Rows
    )

    $header = @(
        '# Compatibility',
        '',
        '## Support Lifecycle and EOL',
        ("Reference date for status labels in this table: **{0}**." -f $ReferenceDate),
        '',
        '| Minor | GA date | Active support until | Maintenance support until | EOL date | Status |',
        '| --- | --- | --- | --- | --- | --- |'
    )

    return ($header + $Rows) -join "`r`n"
}

# Persists generated compatibility test content to a temporary file.
function Write-CompatibilityFile {
    param(
        [string] $ReferenceDate,
        [string[]] $Rows
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $filePath = Join-Path $tempRoot ('compatibility-{0}.md' -f ([System.Guid]::NewGuid().ToString('N')))
    $content = New-CompatibilityContent -ReferenceDate $ReferenceDate -Rows $Rows
    Set-Content -LiteralPath $filePath -Value $content
    return $filePath
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/validation/validate-compatibility-lifecycle-policy.ps1'

try {
    $filePaths = New-Object System.Collections.Generic.List[string]
    try {
        $rows = @(
            '| 1.2 | January 1, 2024 | February 1, 2025 | March 1, 2025 | March 2, 2025 | Active |'
        )
        $filePath = Write-CompatibilityFile -ReferenceDate 'January 15, 2025' -Rows $rows
        $filePaths.Add($filePath) | Out-Null
        & $scriptPath -RepoRoot $resolvedRepoRoot -CompatibilityPath $filePath -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 0 -Message 'Valid lifecycle row should pass.'

        $rows = @(
            '| 1.2 | January 1, 2024 | February 1, 2025 | March 1, 2025 | March 3, 2025 | Active |'
        )
        $filePath = Write-CompatibilityFile -ReferenceDate 'January 15, 2025' -Rows $rows
        $filePaths.Add($filePath) | Out-Null
        & $scriptPath -RepoRoot $resolvedRepoRoot -CompatibilityPath $filePath -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'Invalid EOL date should fail.'

        $rows = @(
            '| 1.2 | January 1, 2024 | February 1, 2025 | March 1, 2025 | March 2, 2025 | Active |'
        )
        $filePath = Write-CompatibilityFile -ReferenceDate 'April 10, 2025' -Rows $rows
        $filePaths.Add($filePath) | Out-Null
        & $scriptPath -RepoRoot $resolvedRepoRoot -CompatibilityPath $filePath -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'Status mismatch should fail.'

        $rows = @(
            '| 0.9 | N/A | N/A | N/A | N/A | Maintenance |'
        )
        $filePath = Write-CompatibilityFile -ReferenceDate 'January 15, 2025' -Rows $rows
        $filePaths.Add($filePath) | Out-Null
        & $scriptPath -RepoRoot $resolvedRepoRoot -CompatibilityPath $filePath -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'N/A row with non-Unsupported status should fail.'
    }
    finally {
        foreach ($path in $filePaths) {
            $parent = Split-Path -Path $path -Parent
            if (Test-Path -LiteralPath $parent) {
                Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host '[OK] compatibility lifecycle tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] compatibility lifecycle tests failed: {0}" -f $_.Exception.Message)
    exit 1
}