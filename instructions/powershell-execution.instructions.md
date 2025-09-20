---
applyTo: "**/*.ps1"
---

# Working Directory Detection
MANDATORY: ALWAYS detect and navigate to solution root automatically in ALL PowerShell scripts; NEVER assume correct working directory; ALWAYS use Set-CorrectWorkingDirectory or similar.
- Check .sln files OR (src/ + .github/) combo to identify solution root
- Walk up to 5 levels
- Test common paths (../../, .., ../../../../)
- Visual feedback on navigation
```powershell
function Set-CorrectWorkingDirectory {
    $current = Get-Location
    for ($i = 0; $i -lt 5; $i++) {
        if (Test-Path "*.sln" -or (Test-Path "src" -and Test-Path ".github")) {
            Write-Host "Solution root found: $PWD" -ForegroundColor Green
            return
        }
        Set-Location ".."
    }
    throw "Could not find solution root"
}
```

# Path Safety
- ALWAYS use Test-Path before Set-Location
- Resolve-Path to validate
- Join-Path for building paths
- Avoid hardcoded absolute paths
- Use relative paths from solution root
```powershell
if (Test-Path $targetPath) {
    $resolvedPath = Resolve-Path $targetPath
    Set-Location $resolvedPath
}
```

# Error Handling
- try/catch for critical ops
- Meaningful error messages
- Appropriate exit codes (0=success, 1=failure)
- Write-Error for critical
- Write-Warning for warnings
```powershell
try {
    Set-CorrectWorkingDirectory
} catch {
    Write-Error "Failed to find solution root: $_"
    exit 1
}
```

# AI Guidance
Include directory navigation notes in responses that involve PowerShell scripts; explain root detection briefly; do not assume user is in correct directory; show navigation commands when relevant.

# Script Structure
- param block first
- Helper functions for navigation
- Validation before execution
- Cleanup in finally blocks
- Structured output with colors

# Execution Policies
Use -ExecutionPolicy Bypass when needed; document requirements; handle security restrictions; provide alternatives.

# Cross-Platform
Correct path separators; consider case sensitivity; handle different PS versions; test on Windows/Linux when applicable.

# Performance
Avoid unnecessary Get-ChildItem -Recurse; use -ErrorAction SilentlyContinue; filter early; cache expensive ops; limit search scope.

# Development
Debug output with -Verbose; structured logging; parameter validation; help comments; example usage; error scenarios.

# Security
- Do not log secrets
- Sanitize inputs
- Validate file paths
- Avoid eval/invoke-expression
- Least privilege

# Example Pattern
Set-CorrectWorkingDirectory at script start; verify .github structure; create directories if needed; relative paths from root; appropriate exit codes.