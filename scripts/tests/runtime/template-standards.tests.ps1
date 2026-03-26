<#
.SYNOPSIS
    Runtime tests for template standards validation without external frameworks.

.DESCRIPTION
    Covers success and failure cases for baseline-driven template validation.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/template-standards.tests.ps1

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

# Creates a temporary template baseline used by the current test case.
function New-TemplateBaseline {
    param(
        [string] $TemplatePath,
        [string[]] $RequiredPatterns,
        [string[]] $ForbiddenPatterns,
        [string[]] $RequiredPathReferences
    )

    $payload = [ordered]@{
        version = 1
        requiredFiles = @($TemplatePath)
        templateRules = @(
            [ordered]@{
                path = $TemplatePath
                requiredPatterns = @($RequiredPatterns)
                forbiddenPatterns = @($ForbiddenPatterns)
                requiredPathReferences = @($RequiredPathReferences)
            }
        )
    }

    return ($payload | ConvertTo-Json -Depth 20)
}

# Writes deterministic UTF-8 test content to disk.
function Write-TextFile {
    param(
        [string] $Path,
        [string] $Content
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $Content
}

$resolvedRepoRoot = Resolve-RepositoryRoot -RequestedRoot $RepoRoot
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/validation/validate-template-standards.ps1'

try {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    try {
        $templateDirectory = Join-Path $tempRoot 'templates'
        $templatePath = Join-Path $templateDirectory 'sample-template.md'
        $supportFilePath = Join-Path $tempRoot 'existing-path.txt'
        $baselinePath = Join-Path $tempRoot 'template-standards.baseline.json'

        Write-TextFile -Path $templatePath -Content @'
# Sample Template

## Validation Checklist
- [ ] First item
'@
        Write-TextFile -Path $supportFilePath -Content 'ok'
        $baselineContent = New-TemplateBaseline `
            -TemplatePath $templatePath `
            -RequiredPatterns @('^# Sample Template', '## Validation Checklist') `
            -ForbiddenPatterns @('scripts/copilot\.ps1') `
            -RequiredPathReferences @($supportFilePath)
        Write-TextFile -Path $baselinePath -Content $baselineContent

        & $scriptPath -RepoRoot $resolvedRepoRoot -TemplateDirectory $templateDirectory -BaselinePath $baselinePath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 0 -Message 'Valid template baseline should pass.'

        Write-TextFile -Path $templatePath -Content @'
# Sample Template

## Validation Checklist
- [ ] First item

scripts/copilot.ps1
'@
        & $scriptPath -RepoRoot $resolvedRepoRoot -TemplateDirectory $templateDirectory -BaselinePath $baselinePath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'Forbidden pattern should fail template validation.'

        Write-TextFile -Path $templatePath -Content @'
# Sample Template

## Validation Checklist
- [ ] First item
'@
        $missingReferencePath = Join-Path $tempRoot 'missing-path.txt'
        $baselineContent = New-TemplateBaseline `
            -TemplatePath $templatePath `
            -RequiredPatterns @('^# Sample Template', '## Validation Checklist') `
            -ForbiddenPatterns @() `
            -RequiredPathReferences @($missingReferencePath)
        Write-TextFile -Path $baselinePath -Content $baselineContent

        & $scriptPath -RepoRoot $resolvedRepoRoot -TemplateDirectory $templateDirectory -BaselinePath $baselinePath | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'Missing template path reference should fail validation.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host '[OK] template standards tests passed.'
    exit 0
}
catch {
    Write-Host ("[FAIL] template standards tests failed: {0}" -f $_.Exception.Message)
    exit 1
}