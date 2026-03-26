<#
.SYNOPSIS
    Fixes region spacing in C# files - ensures blank line between #endregion and #region.

.DESCRIPTION
    Scans C# files and adds a blank line between consecutive #endregion and #region markers
    that are directly adjacent (no blank line between them).

.PARAMETER Path
    The path to scan for C# files. Defaults to current directory.

.PARAMETER WhatIf
    Shows what would be changed without making changes.

.EXAMPLE
    .\fix-region-spacing.ps1 -Path ".\src"
    .\fix-region-spacing.ps1 -Path ".\tests" -WhatIf

.NOTES
    Version: 1.0
    Requirements: PowerShell 7+.
#>

param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [switch]$WhatIf
)

$script:ConsoleStylePath = Join-Path $PSScriptRoot '..\common\console-style.ps1'
if (-not (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf)) {
    $script:ConsoleStylePath = Join-Path $PSScriptRoot '..\..\common\console-style.ps1'
}
if (Test-Path -LiteralPath $script:ConsoleStylePath -PathType Leaf) {
    . $script:ConsoleStylePath
}

$ErrorActionPreference = 'Stop'

# Writes output text using ANSI color sequences when available.
function Write-ColorLine {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    if ($null -eq $PSStyle) {
        Microsoft.PowerShell.Utility\Write-Output $Message
        return
    }

    $ansiColor = switch ($Color) {
        ([ConsoleColor]::Blue) { $PSStyle.Foreground.Blue; break }
        ([ConsoleColor]::Cyan) { $PSStyle.Foreground.Cyan; break }
        ([ConsoleColor]::Green) { $PSStyle.Foreground.Green; break }
        ([ConsoleColor]::Yellow) { $PSStyle.Foreground.Yellow; break }
        ([ConsoleColor]::Red) { $PSStyle.Foreground.Red; break }
        ([ConsoleColor]::DarkGray) { $PSStyle.Foreground.BrightBlack; break }
        default { $PSStyle.Foreground.White }
    }

    Microsoft.PowerShell.Utility\Write-Output ("{0}{1}{2}" -f $ansiColor, $Message, $PSStyle.Reset)
}

$files = Get-ChildItem -Path $Path -Filter "*.cs" -Recurse

$totalFixed = 0
$filesModified = @()

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content

    # Pattern: #endregion followed by whitespace (but no blank line) then #region
    # This matches when there's only spaces/tabs and a single newline between them
    $pattern = '(#endregion[^\r\n]*)\r?\n([ \t]*#region)'
    $replacement = "`$1`r`n`r`n`$2"

    $newContent = $content -replace $pattern, $replacement

    if ($newContent -ne $originalContent) {
        $totalFixed++
        $filesModified += $file.FullName

        if ($WhatIf) {
            Write-ColorLine -Message ("Would fix: {0}" -f $file.FullName) -Color Yellow
        }
        else {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
            Write-ColorLine -Message ("Fixed: {0}" -f $file.FullName) -Color Green
        }
    }
}

Write-StyledOutput ""
Write-ColorLine -Message "========================================" -Color Cyan
if ($WhatIf) {
    Write-ColorLine -Message ("Would modify {0} file(s)" -f $totalFixed) -Color Yellow
}
else {
    Write-ColorLine -Message ("Modified {0} file(s)" -f $totalFixed) -Color Green
}

if ($filesModified.Count -gt 0) {
    Write-StyledOutput ""
    Write-ColorLine -Message 'Files:' -Color Cyan
    $filesModified | ForEach-Object { Write-StyledOutput "  $_" }
}