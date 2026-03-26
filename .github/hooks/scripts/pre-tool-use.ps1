Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$payload = Read-HookInput
$result = New-PreToolUseResult -Payload $payload

$result | ConvertTo-Json -Depth 50 -Compress