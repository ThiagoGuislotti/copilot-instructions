Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')
& (Resolve-ProjectedRuntimeHookScriptPath -ScriptName 'pre-tool-use.ps1') @args