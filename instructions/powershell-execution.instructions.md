---
applyTo: "**/*.ps1"
---
MANDATORY: ALWAYS detect and navigate to solution root automatically in ALL PowerShell scripts; NEVER assume correct working directory; ALWAYS use Set-CorrectWorkingDirectory or similar.
Working directory detection: check .sln files OR (src/ + .github/) combo to identify solution root; walk up to 5 levels; test common paths (../../, .., ../../../../); visual feedback on navigation.
Path safety: ALWAYS use Test-Path before Set-Location; Resolve-Path to validate; Join-Path for building paths; avoid hardcoded absolute paths; use relative paths from solution root.
Error handling: try/catch for critical ops; meaningful error messages; appropriate exit codes (0=success, 1=failure); Write-Error for critical; Write-Warning for warnings.
AI guidance: include directory navigation notes in responses that involve PowerShell scripts; explain root detection briefly; do not assume user is in correct directory; show navigation commands when relevant.
Script structure: param block first; helper functions for navigation; validation before execution; cleanup in finally blocks; structured output with colors.
Execution policies: use -ExecutionPolicy Bypass when needed; document requirements; handle security restrictions; provide alternatives.
Cross-platform: correct path separators; consider case sensitivity; handle different PS versions; test on Windows/Linux when applicable.
Performance: avoid unnecessary Get-ChildItem -Recurse; use -ErrorAction SilentlyContinue; filter early; cache expensive ops; limit search scope.
Development: debug output with -Verbose; structured logging; parameter validation; help comments; example usage; error scenarios.
Security: do not log secrets; sanitize inputs; validate file paths; avoid eval/invoke-expression; least privilege.
Example pattern: Set-CorrectWorkingDirectory at script start; verify .github structure; create directories if needed; relative paths from root; appropriate exit codes.