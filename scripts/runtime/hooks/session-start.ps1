<#
.SYNOPSIS
    Handles the projected VS Code `SessionStart` hook event.

.DESCRIPTION
    Reads the hook payload from STDIN, builds the repository-owned Super Agent
    startup context, and emits the compact JSON response consumed by the VS Code
    hook runtime.

.EXAMPLE
    '{}' | pwsh -File .\scripts\runtime\hooks\session-start.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$payload = Read-HookInput
$additionalContext = New-SessionContextString -Payload $payload

$result = [ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName = 'SessionStart'
        additionalContext = $additionalContext
    }
}

$result | ConvertTo-Json -Depth 20 -Compress