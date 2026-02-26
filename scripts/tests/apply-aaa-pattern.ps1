<#
.SYNOPSIS
    Applies AAA (Arrange-Act-Assert) pattern comments to frontend TypeScript/Vue test files.

.DESCRIPTION
    This script processes frontend test files in the __tests__ directory and automatically
    inserts AAA pattern comments where they are missing. It respects existing code structure
    and only adds comments to tests that don't already follow the AAA pattern.

    The script uses regex patterns to identify:
    - Test setup code (Arrange section)
    - Test execution code (Act section)
    - Assertion code (Assert section)

    After execution, manual review is recommended to ensure comments are contextually accurate
    and properly positioned.

.PARAMETER TestFiles
    Array of relative paths to test files to process. If not specified, processes a default
    set of frontend test files.

.EXAMPLE
    .\apply-aaa-pattern.ps1
    Processes default frontend test files with AAA pattern comments.

.EXAMPLE
    .\apply-aaa-pattern.ps1 -TestFiles @("samples/tests/unit/MyComponent.spec.ts")
    Processes only the specified test file.

.NOTES
    File: apply-aaa-pattern.ps1
    Author: NetToolsKit
    Requires: PowerShell 7+
    Target: Frontend TypeScript/Vue test files
    Pattern: AAA (Arrange-Act-Assert)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$TestFiles = @(
        "frontend/src/shared/tests/unit/adapters/QuasarNotificationAdapter.spec.ts",
        "frontend/src/shared/tests/unit/composables/data/useFilters.spec.ts",
        "frontend/src/shared/tests/unit/composables/services/useNotification.spec.ts",
        "frontend/src/shared/tests/unit/composables/utils/useAsync.spec.ts",
        "frontend/src/shared/tests/unit/services/FilterService.spec.ts",
        "frontend/src/shared/tests/unit/services/NotificationService.spec.ts",
        "frontend/src/shared/tests/unit/utils/async.spec.ts",
        "frontend/src/shared/tests/unit/utils/validators.spec.ts"
    )
)

Write-Host "=== Applying AAA Pattern to Frontend Tests ===" -ForegroundColor Cyan
Write-Host "This script will add AAA comments to pending tests" -ForegroundColor Yellow
Write-Host ""

# Function to process a file
# Adds Arrange/Act/Assert section comments to test methods when missing.
function Add-AAAComments {
    param (
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ File not found: $FilePath" -ForegroundColor Red
        return
    }

    Write-Host "📝 Processing: $FilePath" -ForegroundColor Green

    $content = Get-Content $FilePath -Raw
    $modified = $false

    # Regex pattern to identify tests without AAA
    # Looks for it('...', () => { without AAA comments immediately after
    $pattern = "(?m)(    it\('.*?', \(\) => \{)\s*\n(?!      \/\/ Arrange)"

    if ($content -match $pattern) {
        $modified = $true

        # For each test found, add AAA comments
        $content = $content -replace $pattern, "`$1`n      // Arrange`n      // Setup: prepare test data and preconditions`n`n      // Act`n      // Execute: operation being tested`n`n      // Assert`n      // Verify: expected outcome`n"
    }

    if ($modified) {
        Set-Content -Path $FilePath -Value $content -NoNewline
        Write-Host "   ✅ AAA comments added successfully" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️  No modifications needed (AAA already applied or different structure)" -ForegroundColor Yellow
    }
}

# Resolve file paths relative to script location
$resolvedFiles = $TestFiles | ForEach-Object {
    if ([System.IO.Path]::IsPathRooted($_)) {
        $_
    } else {
        Join-Path $PSScriptRoot ".." ".." $_
    }
}

# Process each file
foreach ($file in $resolvedFiles) {
    if (Test-Path $file) {
        Add-AAAComments -FilePath $file
        Write-Host ""
    } else {
        Write-Host "⚠️  File not found: $file" -ForegroundColor Yellow
    }
}

Write-Host "=== Processing Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  WARNING: This script applied generic AAA comments." -ForegroundColor Yellow
Write-Host "Manual review is required to:" -ForegroundColor Yellow
Write-Host "  1. Adjust comments to reflect specific context" -ForegroundColor White
Write-Host "  2. Ensure Arrange/Act/Assert are correctly positioned" -ForegroundColor White
Write-Host "  3. Add explanatory notes for critical/complex logic" -ForegroundColor White