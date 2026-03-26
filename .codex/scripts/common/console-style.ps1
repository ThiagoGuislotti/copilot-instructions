<#
.SYNOPSIS
    Shared ANSI console styling helpers for repository scripts.

.DESCRIPTION
    Provides message-level color rendering while preserving plain output
    behavior for non-string pipeline objects.

.PARAMETER None
    This helper script does not define script-level parameters.

.EXAMPLE
    . "$PSScriptRoot/../common/console-style.ps1"
    Write-StyledOutput "[WARN] Example warning line"

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Returns ANSI prefix for the requested semantic color.
function Get-StyleColorCode {
    param(
        [ValidateSet('Default', 'Blue', 'Yellow', 'Green', 'Red', 'Cyan', 'Gray')]
        [string] $Color = 'Default'
    )

    if ('Default' -eq $Color -or $null -eq $PSStyle) {
        return ''
    }

    switch ($Color) {
        'Blue' { return $PSStyle.Foreground.BrightBlue }
        'Yellow' { return $PSStyle.Foreground.BrightYellow }
        'Green' { return $PSStyle.Foreground.BrightGreen }
        'Red' { return $PSStyle.Foreground.BrightRed }
        'Cyan' { return $PSStyle.Foreground.BrightCyan }
        'Gray' { return $PSStyle.Foreground.BrightBlack }
        default { return '' }
    }
}

# Writes one output line, applying ANSI color when requested.
function Write-ColorLine {
    param(
        [AllowNull()]
        [string] $Message,
        [ValidateSet('Default', 'Blue', 'Yellow', 'Green', 'Red', 'Cyan', 'Gray')]
        [string] $Color = 'Default'
    )

    if ([string]::IsNullOrEmpty($Message)) {
        Microsoft.PowerShell.Utility\Write-Host ''
        return
    }

    $prefix = Get-StyleColorCode -Color $Color
    if ([string]::IsNullOrWhiteSpace($prefix) -or $null -eq $PSStyle) {
        Microsoft.PowerShell.Utility\Write-Host $Message
        return
    }

    Microsoft.PowerShell.Utility\Write-Host ("{0}{1}{2}" -f $prefix, $Message, $PSStyle.Reset)
}

# Returns semantic color based on message patterns.
function Get-MessageColor {
    param(
        [AllowNull()]
        [string] $Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return 'Default'
    }

    if ($Message -match '^\[(FAIL|ERROR)\]') { return 'Red' }
    if ($Message -match '^\[(WARN|WARNING)\]') { return 'Yellow' }
    if ($Message -match '^\[(OK|PASS|SUCCESS)\]') { return 'Green' }
    if ($Message -match '^\[(INFO|RUN|VERBOSE)\]') { return 'Blue' }

    if ($Message -match '^\[[0-9]+/[0-9]+\]') { return 'Cyan' }
    if ($Message -match '^\s*[=]{6,}|^\s*[━]{6,}|^\s*[╔║╚].*') { return 'Cyan' }

    if ($Message -match '^(Root|Solution root found|Scanning from|Repository root|Repo root|Settings|Access URLs|Useful SSH commands):') {
        return 'Blue'
    }

    if ($Message -match '^Changed files:') {
        return 'Green'
    }

    if ($Message -match '^(Files found|Directories found|Warnings|Failures|Total|Passed|Failed|Coverage|Documentation coverage):') {
        return 'Yellow'
    }

    if ($Message -match '^\s*(✅|✔)') { return 'Green' }
    if ($Message -match '^\s*(⚠|WARNING)') { return 'Yellow' }
    if ($Message -match '^\s*(❌|ERROR|Error)') { return 'Red' }

    return 'Default'
}

# Writes output while automatically styling known log patterns.
function Write-StyledOutput {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        [object] $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            Microsoft.PowerShell.Utility\Write-Host ''
            return
        }

        if ($InputObject -isnot [string]) {
            Microsoft.PowerShell.Utility\Write-Output $InputObject
            return
        }

        $message = [string] $InputObject
        $color = Get-MessageColor -Message $message
        if ('Default' -eq $color) {
            Microsoft.PowerShell.Utility\Write-Output $message
            return
        }

        Write-ColorLine -Message $message -Color $color
    }
}