[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $CatalogPath,
    [string] $ManifestPath,
    [string] $TargetConfigPath,
    [switch] $CreateBackup,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

function Resolve-CanonicalRuntimeScriptPath {
    param([Parameter(Mandatory = $true)][string] $ScriptName)

    $candidatePaths = @(
        (Join-Path $PSScriptRoot (Join-Path '..\..\scripts\runtime' $ScriptName)),
        (Join-Path $PSScriptRoot (Join-Path '..\..\.github\scripts\runtime' $ScriptName))
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }
    }

    throw ("Unable to locate canonical runtime script '{0}' from '{1}'." -f $ScriptName, $PSScriptRoot)
}

& (Resolve-CanonicalRuntimeScriptPath -ScriptName 'sync-codex-mcp-config.ps1') @PSBoundParameters
exit $LASTEXITCODE