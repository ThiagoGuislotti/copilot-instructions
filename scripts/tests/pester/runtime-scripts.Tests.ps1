<#
.SYNOPSIS
    Pester tests for critical runtime scripts.

.DESCRIPTION
    Validates script contracts and smoke behavior for runtime scripts used
    by bootstrap, healthcheck, self-heal, and cleanup flows.

.PARAMETER None
    This test file does not require input parameters.

.EXAMPLE
    Invoke-Pester -Path scripts/tests/pester -PassThru

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+, Pester.
#>

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$runtimeScriptRoot = Join-Path $repoRoot 'scripts/runtime'

Describe 'Runtime script contracts' {
    It 'bootstrap script exposes required parameters' {
        $scriptPath = Join-Path $runtimeScriptRoot 'bootstrap.ps1'
        $command = Get-Command -Name $scriptPath -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'RepoRoot'
        $command.Parameters.Keys | Should -Contain 'TargetGithubPath'
        $command.Parameters.Keys | Should -Contain 'TargetCodexPath'
        $command.Parameters.Keys | Should -Contain 'Mirror'
    }

    It 'healthcheck script exposes required parameters' {
        $scriptPath = Join-Path $runtimeScriptRoot 'healthcheck.ps1'
        $command = Get-Command -Name $scriptPath -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'ValidationProfile'
        $command.Parameters.Keys | Should -Contain 'WarningOnly'
        $command.Parameters.Keys | Should -Contain 'TargetGithubPath'
        $command.Parameters.Keys | Should -Contain 'TargetCodexPath'
    }

    It 'self-heal script exposes required parameters' {
        $scriptPath = Join-Path $runtimeScriptRoot 'self-heal.ps1'
        $command = Get-Command -Name $scriptPath -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'Mirror'
        $command.Parameters.Keys | Should -Contain 'ApplyMcpConfig'
        $command.Parameters.Keys | Should -Contain 'TargetGithubPath'
        $command.Parameters.Keys | Should -Contain 'TargetCodexPath'
    }

    It 'clean-codex-runtime script exposes required parameters' {
        $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'
        $command = Get-Command -Name $scriptPath -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'CodexHome'
        $command.Parameters.Keys | Should -Contain 'IncludeSessions'
        $command.Parameters.Keys | Should -Contain 'SessionRetentionDays'
        $command.Parameters.Keys | Should -Contain 'LogRetentionDays'
    }
}

Describe 'Runtime script smoke behavior' {
    It 'bootstrap syncs to explicit temp targets' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
        $targetGithub = Join-Path $tempRoot '.github'
        $targetCodex = Join-Path $tempRoot '.codex'
        $scriptPath = Join-Path $runtimeScriptRoot 'bootstrap.ps1'

        try {
            & $scriptPath -RepoRoot $repoRoot -TargetGithubPath $targetGithub -TargetCodexPath $targetCodex -Mirror | Out-Null
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            $exitCode | Should -Be 0

            (Test-Path -LiteralPath $targetGithub -PathType Container) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $targetCodex 'skills') -PathType Container) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $targetCodex 'shared-scripts') -PathType Container) | Should -BeTrue
        }
        finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'clean-codex-runtime removes expired temporary entries' {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
        $codexHome = Join-Path $tempRoot '.codex'
        $tmpDir = Join-Path $codexHome 'tmp'
        $logDir = Join-Path $codexHome 'log'
        $sessionsDir = Join-Path $codexHome 'sessions'
        $oldLog = Join-Path $logDir 'old.log'
        $oldSession = Join-Path $sessionsDir 'old-session.json'
        $tempFile = Join-Path $tmpDir 'temp.txt'
        $scriptPath = Join-Path $runtimeScriptRoot 'clean-codex-runtime.ps1'

        try {
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            New-Item -ItemType Directory -Path $sessionsDir -Force | Out-Null

            Set-Content -LiteralPath $tempFile -Value 'temp'
            Set-Content -LiteralPath $oldLog -Value 'log'
            Set-Content -LiteralPath $oldSession -Value 'session'

            $expiredDate = (Get-Date).AddDays(-10)
            (Get-Item -LiteralPath $oldLog).LastWriteTime = $expiredDate
            (Get-Item -LiteralPath $oldSession).LastWriteTime = $expiredDate

            & $scriptPath -CodexHome $codexHome -IncludeSessions -SessionRetentionDays 1 -LogRetentionDays 1 -Apply | Out-Null
            $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int] $LASTEXITCODE }
            $exitCode | Should -Be 0

            (Test-Path -LiteralPath $tempFile) | Should -BeFalse
            (Test-Path -LiteralPath $oldLog) | Should -BeFalse
            (Test-Path -LiteralPath $oldSession) | Should -BeFalse
        }
        finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}