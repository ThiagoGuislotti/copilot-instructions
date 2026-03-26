<#
.SYNOPSIS
    Runtime tests for authoritative source policy validation without external frameworks.

.DESCRIPTION
    Covers success, failure, and warning-only duplication behavior for
    `validate-authoritative-source-policy.ps1`.

.PARAMETER RepoRoot
    Optional repository root. If omitted, auto-detects a root containing .github and .codex.

.EXAMPLE
    pwsh -File scripts/tests/runtime/authoritative-source-policy.tests.ps1

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
$scriptPath = Join-Path $resolvedRepoRoot 'scripts/validation/validate-authoritative-source-policy.ps1'

try {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    try {
        & $scriptPath -RepoRoot $resolvedRepoRoot -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 0 -Message 'Repository authoritative source policy should pass.'

        $invalidMapPath = Join-Path $tempRoot 'invalid-authoritative-source-map.json'
        Write-TextFile -Path $invalidMapPath -Content @'
{
  "version": 1,
  "defaultPolicy": {
    "repositoryContextFirst": true
  },
  "stackRules": [
    {
      "id": "dotnet",
      "displayName": ".NET",
      "keywords": ["dotnet"],
      "officialDomains": ["https://learn.microsoft.com/dotnet/"]
    }
  ]
}
'@
        & $scriptPath -RepoRoot $resolvedRepoRoot -SourceMapPath $invalidMapPath -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'Invalid authoritative source map should fail.'
        Remove-Item -LiteralPath $invalidMapPath -Force

        $invalidAgentsPath = Join-Path $tempRoot 'AGENTS.md'
        Write-TextFile -Path $invalidAgentsPath -Content @'
# Temporary AGENTS

- This file intentionally omits the authoritative source instruction reference.
'@
        & $scriptPath -RepoRoot $resolvedRepoRoot -AgentsPath $invalidAgentsPath -WarningOnly:$false | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 1 -Message 'Missing AGENTS reference should fail.'
        Remove-Item -LiteralPath $invalidAgentsPath -Force

        $instructionRoot = Join-Path $tempRoot 'instructions'
        $duplicateInstructionPath = Join-Path $instructionRoot 'duplicate.instructions.md'
        Write-TextFile -Path $duplicateInstructionPath -Content @'
---
applyTo: "**/*.rs"
priority: medium
---

Use learn.microsoft.com for .NET lookups in this temporary duplicate file.
'@
        & $scriptPath `
            -RepoRoot $resolvedRepoRoot `
            -InstructionSearchRoot $instructionRoot `
            -WarningOnly:$false `
            -DetailedOutput | Out-Null
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
        Assert-ExitCode -ExitCode $exitCode -Expected 0 -Message 'Duplicate instruction domains should warn but not fail.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}
finally {
    Set-Location -Path $resolvedRepoRoot
}