<#
.SYNOPSIS
    Imports shared helper scripts for repository and mirrored runtime callers.

.DESCRIPTION
    Resolves shared helper scripts from the repository `scripts/common` layout
    and the mirrored runtime layouts under `.github/scripts/common` and
    `.codex/shared-scripts/common`.

    Callers dot-source this script and declare the helper set they need.

.PARAMETER Helpers
    Helper names or helper file names to import.

.PARAMETER CallerScriptRoot
    Script root used to resolve the shared helper layout. Defaults to the
    current script root when omitted.

.EXAMPLE
    . $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [string[]] $Helpers = @(),
    [string] $CallerScriptRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

# Normalizes helper aliases into concrete helper file names.
function Resolve-CommonHelperFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Helper
    )

    switch ($Helper) {
        'console-style' { return 'console-style.ps1' }
        'repository-paths' { return 'repository-paths.ps1' }
        'git-hook-eof-settings' { return 'git-hook-eof-settings.ps1' }
        'runtime-paths' { return 'runtime-paths.ps1' }
        'codex-runtime-hygiene' { return 'codex-runtime-hygiene.ps1' }
        'vscode-runtime-hygiene' { return 'vscode-runtime-hygiene.ps1' }
        'runtime-execution-context' { return 'runtime-execution-context.ps1' }
        'agent-runtime-hardening' { return 'agent-runtime-hardening.ps1' }
        'mcp-runtime-catalog' { return 'mcp-runtime-catalog.ps1' }
        'provider-surface-catalog' { return 'provider-surface-catalog.ps1' }
        'runtime-operation-support' { return 'runtime-operation-support.ps1' }
        'runtime-install-profiles' { return 'runtime-install-profiles.ps1' }
        'validation-logging' { return 'validation-logging.ps1' }
        default {
            if ($Helper.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
                return $Helper
            }

            return ("{0}.ps1" -f $Helper)
        }
    }
}

# Returns candidate shared-helper roots for the caller script location.
function Get-CommonHelperRootCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptRoot
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    $relativeCandidates = @(
        @('.', 'common'),
        @('..', 'common'),
        @('..', '..', 'common'),
        @('..', '..', 'scripts', 'common'),
        @('..', 'shared-scripts', 'common'),
        @('..', '..', 'shared-scripts', 'common')
    )

    foreach ($relativeCandidate in $relativeCandidates) {
        $candidatePath = [System.IO.Path]::GetFullPath($ScriptRoot)
        foreach ($segment in $relativeCandidate) {
            $candidatePath = Join-Path $candidatePath $segment
        }
        $candidatePath = [System.IO.Path]::GetFullPath($candidatePath)
        if ((Test-Path -LiteralPath $candidatePath -PathType Container) -and -not $candidates.Contains($candidatePath)) {
            $candidates.Add($candidatePath) | Out-Null
        }
    }

    return @($candidates)
}

# Resolves a shared helper path for the caller script location.
function Resolve-CommonHelperPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptRoot,
        [Parameter(Mandatory = $true)]
        [string] $Helper
    )

    $helperFileName = Resolve-CommonHelperFileName -Helper $Helper
    $searchedPaths = New-Object System.Collections.Generic.List[string]

    foreach ($rootCandidate in (Get-CommonHelperRootCandidates -ScriptRoot $ScriptRoot)) {
        $candidatePath = Join-Path $rootCandidate $helperFileName
        $searchedPaths.Add($candidatePath) | Out-Null
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidatePath).Path
        }
    }

    $searchedText = if ($searchedPaths.Count -gt 0) {
        ($searchedPaths | ForEach-Object { "'$_'" }) -join ', '
    }
    else {
        'no candidate shared helper roots were detected'
    }

    throw ("Missing shared helper '{0}'. Searched: {1}" -f $helperFileName, $searchedText)
}

# Imports one or more shared helpers for the caller script root.
function Import-SharedHelpers {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Helpers,
        [Alias('CallerScriptRoot')]
        [string] $ScriptRoot = $PSScriptRoot
    )

    $uniqueHelpers = @($Helpers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    foreach ($helper in $uniqueHelpers) {
        $resolvedHelperPath = Resolve-CommonHelperPath -ScriptRoot $ScriptRoot -Helper $helper
        . $resolvedHelperPath
    }
}

if (@($Helpers).Count -gt 0) {
    $uniqueHelpers = @($Helpers | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    foreach ($helper in $uniqueHelpers) {
        $resolvedHelperPath = Resolve-CommonHelperPath -ScriptRoot $CallerScriptRoot -Helper $helper
        . $resolvedHelperPath
    }
}