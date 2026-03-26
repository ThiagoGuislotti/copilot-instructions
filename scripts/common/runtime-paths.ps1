<#
.SYNOPSIS
    Shared runtime path helpers for cross-platform scripts.

.DESCRIPTION
    Provides helper functions to resolve local runtime paths in a
    cross-platform way for Windows, Linux, and macOS.

.PARAMETER None
    This helper script does not require input parameters.

.EXAMPLE
    . ./scripts/common/runtime-paths.ps1
    $homePath = Resolve-UserHomePath

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param()

$ErrorActionPreference = 'Stop'

# Resolves the current user home directory with cross-platform fallbacks.
function Resolve-UserHomePath {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }

    if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        return $HOME
    }

    $profileFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($profileFolder)) {
        return $profileFolder
    }

    throw 'Could not resolve user home path. Set USERPROFILE or HOME.'
}