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

$script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\common\common-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    $script:CommonBootstrapPath = Join-Path $PSScriptRoot '..\..\shared-scripts\common\common-bootstrap.ps1'
}
if (-not (Test-Path -LiteralPath $script:CommonBootstrapPath -PathType Leaf)) {
    throw "Missing shared common bootstrap helper: $script:CommonBootstrapPath"
}
. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style')
$ErrorActionPreference = 'Stop'

Write-StyledOutput "=== Applying AAA Pattern to Frontend Tests ==="
Write-StyledOutput "This script will add AAA comments to pending tests"
Write-StyledOutput ""

# Function to process a file
# Adds Arrange/Act/Assert section comments to test methods when missing.
function Add-AAAComment {
    param (
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-StyledOutput "❌ File not found: $FilePath"
        return
    }

    Write-StyledOutput "📝 Processing: $FilePath"

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
        Write-StyledOutput "   ✅ AAA comments added successfully"
    } else {
        Write-StyledOutput "   ℹ️  No modifications needed (AAA already applied or different structure)"
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
        Add-AAAComment -FilePath $file
        Write-StyledOutput ""
    } else {
        Write-StyledOutput "⚠️  File not found: $file"
    }
}

Write-StyledOutput "=== Processing Complete ==="
Write-StyledOutput ""
Write-StyledOutput "⚠️  WARNING: This script applied generic AAA comments."
Write-StyledOutput "Manual review is required to:"
Write-StyledOutput "  1. Adjust comments to reflect specific context"
Write-StyledOutput "  2. Ensure Arrange/Act/Assert are correctly positioned"
Write-StyledOutput "  3. Add explanatory notes for critical/complex logic"