Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')
& (Resolve-ProjectedRuntimeHookScriptPath -ScriptName 'subagent-start.ps1') @args