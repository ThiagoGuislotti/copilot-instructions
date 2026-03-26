---
description: Generate PowerShell scripts under scripts/ using repository standards and templates
mode: ask
tools: ['codebase', 'search', 'findFiles']
---

# Create PowerShell Script
Create a new PowerShell script in `scripts/` following this repository's safety, structure, and logging conventions.

## Instructions
Create the script based on:
- [powershell-script-template.ps1](../templates/powershell-script-template.ps1)
- [powershell-script-creation.instructions.md](../instructions/powershell-script-creation.instructions.md)
- [powershell-execution.instructions.md](../instructions/powershell-execution.instructions.md)

## Input Variables
- `${input:scriptPath:Relative path in scripts/ (example: scripts/maintenance/my-script.ps1)}` - Destination script path
- `${input:summary:One-line script purpose}` - Script objective
- `${input:targetPath:Primary target path or resource}` - Main input resource to process
- `${input:mutationMode:read-only | dry-run-and-apply}` - Whether mutations are allowed
- `${input:requiresRepoRoot:true | false}` - Whether repository root auto-detection is needed

## Requirements
- Keep comment-based help with SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE, and NOTES.
- Keep `param` block before executable logic.
- Set `$ErrorActionPreference = 'Stop'`.
- Use approved verbs for function names.
- Add `-DryRun` when the script mutates files or configuration.
- Resolve paths with `Join-Path`; validate with `Test-Path -LiteralPath`.
- Keep logs in English with stable prefixes (`[INFO]`, `[WARN]`, `[ERROR]`, `[OK]`).
- Print a summary at the end (processed items, changes, warnings).
- Return exit code `0` on success and `1` on validation/runtime failure.

## Output
Return:
1. Full script content.
2. Placeholder-to-value mapping used.
3. Suggested execution commands (`pwsh -File ...` dry-run and apply modes when applicable).