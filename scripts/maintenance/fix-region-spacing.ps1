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
#>

param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [switch]$WhatIf
)

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
            Write-Host "Would fix: $($file.FullName)" -ForegroundColor Yellow
        }
        else {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
            Write-Host "Fixed: $($file.FullName)" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "Would modify $totalFixed file(s)" -ForegroundColor Yellow
}
else {
    Write-Host "Modified $totalFixed file(s)" -ForegroundColor Green
}

if ($filesModified.Count -gt 0) {
    Write-Host ""
    Write-Host "Files:" -ForegroundColor Cyan
    $filesModified | ForEach-Object { Write-Host "  $_" }
}