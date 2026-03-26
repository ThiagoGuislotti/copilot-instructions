Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$payload = Read-HookInput
$additionalContext = New-SubagentContextString -Payload $payload

$result = [ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName = 'SubagentStart'
        additionalContext = $additionalContext
    }
}

$result | ConvertTo-Json -Depth 20 -Compress