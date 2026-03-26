<#
.SYNOPSIS
    Handles the projected VS Code `PreToolUse` hook event.

.DESCRIPTION
    Reads the hook payload from STDIN, applies repository-owned pre-write guardrails
    such as EOF hygiene normalization, and emits the compact JSON response
    consumed by the VS Code hook runtime.

.EXAMPLE
    '{}' | pwsh -File .\scripts\runtime\hooks\pre-tool-use.ps1

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$payload = Read-HookInput
$result = New-PreToolUseResult -Payload $payload

$result | ConvertTo-Json -Depth 50 -Compress