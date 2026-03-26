<#
.SYNOPSIS
    Refactors Rust test files to follow AAA (Arrange-Act-Assert) pattern.

.DESCRIPTION
    This script processes Rust test files and automatically:
    - Removes decorative separator comments (// ===...)
    - Inserts AAA pattern comments where missing
    - Adds blank lines between AAA sections for readability

    The script uses regex patterns to identify:
    - Setup code with environment locks (Arrange section)
    - Test execution code (Act section)
    - Assertion code (Assert section)

    The refactored file maintains the original logic while improving readability
    and adherence to testing best practices.

.PARAMETER TestFile
    Path to the Rust test file to refactor. Can be absolute or relative to the script location.

.EXAMPLE
    .\refactor_tests_to_aaa.ps1 -TestFile "tests\unit\config_tests.rs"
    Refactors the specified Rust test file with AAA pattern.

.EXAMPLE
    .\refactor_tests_to_aaa.ps1 -TestFile "C:\Projects\MyProject\tests\integration_tests.rs"
    Refactors the test file using an absolute path.

.NOTES
    File: refactor_tests_to_aaa.ps1
    Author: NetToolsKit
    Requires: PowerShell 7+
    Target: Rust test files
    Pattern: AAA (Arrange-Act-Assert)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TestFile
)

if (-not (Test-Path $TestFile)) {
    Write-Host "❌ Error: Test file not found: $TestFile" -ForegroundColor Red
    exit 1
}

Write-Host "Refactoring $TestFile to AAA pattern..." -ForegroundColor Cyan
Write-Host ""

# Read file content
$content = Get-Content $TestFile -Raw

# Remove decorative separators (// ===...)
$content = $content -replace '(?m)^\s*//\s*={3,}.*$\r?\n', ''

# Process each test function
$pattern = '(?ms)(#\[test\].*?fn\s+\w+\s*\([^)]*\)\s*\{)(.*?)(\n\})'
$content = [regex]::Replace($content, $pattern, {
    param($match)

    $header = $match.Groups[1].Value
    $body = $match.Groups[2].Value
    $footer = $match.Groups[3].Value

    # Check if AAA comments already exist
    if ($body -match '//\s*Arrange' -and $body -match '//\s*Act' -and $body -match '//\s*Assert') {
        # Already has AAA pattern, return as-is
        return $match.Value
    }

    # Split body into lines
    $lines = $body -split '\r?\n'
    $newBody = @()

    # Add Arrange comment if not present
    $hasArrange = $false
    $hasAct = $false
    $hasAssert = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if (-not $hasArrange -and $trimmed -ne '' -and $trimmed -notmatch '^//') {
            $newBody += "    // Arrange"
            if ($trimmed -match '^let\s+_lock') {
                $newBody += "    // (using env lock for thread safety)"
            }
            $hasArrange = $true
        }

        if (-not $hasAct -and $trimmed -match '^let\s+\w+\s*=\s*(Features::|Config::|[A-Z])' -and -not ($trimmed -match '_lock')) {
            $newBody += ""
            $newBody += "    // Act"
            $hasAct = $true
        }

        if (-not $hasAssert -and ($trimmed -match '^assert' -or $trimmed -match '^#\[cfg')) {
            $newBody += ""
            $newBody += "    // Assert"
            $hasAssert = $true
        }

        $newBody += $line
    }

    return $header + ($newBody -join "`n") + $footer
})

# Save refactored content
Set-Content -Path $TestFile -Value $content -NoNewline

Write-Host "✅ Refactored $TestFile successfully" -ForegroundColor Green
Write-Host "Changes applied:" -ForegroundColor Yellow
Write-Host "  - Removed decorative separators (// ===...)" -ForegroundColor Gray
Write-Host "  - Added AAA comments where missing" -ForegroundColor Gray
Write-Host "  - Added blank lines between AAA sections" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  Manual review recommended to ensure AAA sections are correctly positioned." -ForegroundColor Yellow