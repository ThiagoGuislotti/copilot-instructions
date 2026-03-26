---
applyTo: "scripts/**/*.ps1"
priority: high
---

# Purpose
Standardize PowerShell scripts in scripts/ with the same structure and safety model used by maintenance scripts.

# Required Template
- Start from .github/templates/powershell-script-template.ps1 for every new script under scripts/.
- For AI-assisted generation prefer .github/prompts/create-powershell-script.prompt.md first, then adapt as needed.
- Start with comment-based help using SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE, and NOTES.
- Keep param block at the top of the executable body.
- Set ErrorActionPreference to Stop.
- Organize code in three sections: Helpers, Main execution, Summary/exit.
- Use descriptive function names with approved verbs.

# Template Placeholder Mapping
- Replace [SHORT_SCRIPT_SUMMARY] with one-line script intent.
- Replace [DETAILED_SCRIPT_DESCRIPTION] with operational behavior and scope.
- Replace [AREA] and [SCRIPT_NAME] examples with concrete script path.
- Replace [RELATIVE_TARGET_PATH] with the primary resource path used by script logic.
- Keep helper function names unless there is a clear context-specific reason to rename them.

# Root Detection
- Detect repository root automatically when script behavior depends on repo layout.
- Accept optional RepoRoot parameter; validate with Resolve-Path.
- Prefer a shared helper named Set-CorrectWorkingDirectory or equivalent deterministic logic.
- Never assume caller current directory is the repository root.

# Parameter and Validation Rules
- Validate required paths before processing.
- Use Test-Path with LiteralPath for filesystem operations.
- Use Join-Path for path composition.
- Define explicit switch parameters for optional behavior.
- Return exit code 0 for success and 1 for validation/runtime failure.

# Logging and Diagnostics
- Use structured messages with stable prefixes for failures and warnings.
- Keep success summary at the end with counts/results when applicable.
- Support verbose diagnostics through a switch and helper logger.
- Do not print secrets or sensitive configuration values.

# Mutation Safety
- Prefer safe default mode; destructive behavior must be opt-in.
- Add DryRun or equivalent preview mode for deletion/bulk rewrite scripts.
- Use Force switches only when explicitly requested by caller.
- Wrap critical mutations in try/catch and continue safely when possible.

# Code Quality Rules
- Keep functions small and single-purpose.
- Avoid duplicated path resolution logic across the script.
- Keep script idempotent whenever feasible.
- Use UTF-8 encoding for file writes unless target format requires otherwise.

# Example Skeleton
```powershell
param(
    [string] $RepoRoot,
    [switch] $Verbose
)

$ErrorActionPreference = 'Stop'

function Write-VerboseColor {
    param([string] $Message)
    if ($Verbose) { Write-Host $Message -ForegroundColor Gray }
}

function Set-CorrectWorkingDirectory {
    param([string] $RequestedRoot)
    # Resolve and validate repository root
}

# Main execution
$resolvedRepoRoot = Set-CorrectWorkingDirectory -RequestedRoot $RepoRoot
Write-Host "Done." -ForegroundColor Green
exit 0
```