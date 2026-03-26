Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ProjectedRuntimeHookScriptPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptName
    )

    $candidatePaths = @(
        (Join-Path $PSScriptRoot (Join-Path '..\..\..\scripts\runtime\hooks' $ScriptName)),
        (Join-Path $PSScriptRoot (Join-Path '..\..\scripts\runtime\hooks' $ScriptName)),
        (Join-Path $PSScriptRoot (Join-Path '..\..\..\..\..\scripts\runtime\hooks' $ScriptName))
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }
    }

    throw ("Unable to locate canonical runtime hook script '{0}' from '{1}'." -f $ScriptName, $PSScriptRoot)
}