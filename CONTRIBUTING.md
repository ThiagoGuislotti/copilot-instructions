# Contributing

Contribution flow for this repository follows the same enterprise-first standards used by the runtime assets under `.github`, `.codex`, `.vscode`, and `scripts/`.

## Scope

Use this guide when contributing:

- instruction files under `.github/instructions/`
- prompts, chat modes, schemas, and governance assets under `.github/`
- Codex runtime assets under `.codex/`
- VS Code templates under `.vscode/`
- automation scripts under `scripts/`

## Before You Change Anything

1. Read `.github/AGENTS.md`.
2. Read `.github/copilot-instructions.md`.
3. Load the domain-specific instructions that match the files you will change.
4. Prefer the versioned repository assets over direct edits in `%USERPROFILE%\.github`, `%USERPROFILE%\.codex`, or the global VS Code profile.

## Contribution Types

- Instruction improvements
- Skills and runtime asset changes
- Validation and governance enhancements
- Documentation and onboarding improvements
- VS Code template/runtime sync improvements
- Security, compliance, and release-governance updates

## Development Workflow

1. Make the change in `<REPO_ROOT>`.
2. Keep paths parameterized in tracked files. Use placeholders such as `%USERPROFILE%` and `%APPDATA%` instead of personal absolute paths.
3. If the change affects runtime-managed assets, update the corresponding sync script or baseline instead of editing generated runtime files by hand.
4. If the change introduces a new contract, add or update validation coverage.

## Validation Commands

Run the smallest relevant set first, then the unified suite.

```powershell
pwsh -File .\scripts\validation\validate-instructions.ps1
pwsh -File .\scripts\validation\validate-runtime-script-tests.ps1 -WarningOnly:$false
pwsh -File .\scripts\validation\validate-template-standards.ps1
pwsh -File .\scripts\validation\validate-all.ps1 -ValidationProfile dev
```

Use a narrower command when the scope is obvious:

- runtime scripts: `scripts/validation/validate-runtime-script-tests.ps1`
- PowerShell authoring: `scripts/validation/validate-powershell-standards.ps1`
- templates: `scripts/validation/validate-template-standards.ps1`
- workspace rules: `scripts/validation/validate-workspace-efficiency.ps1`

## Pull Requests

Every PR should include:

- context
- change summary
- rationale
- risks
- validation executed
- documentation/runtime impact
- applied instruction files when relevant

Use `.github/PULL_REQUEST_TEMPLATE.md`.

## Issue Intake

Use the GitHub issue templates when opening new work:

- instruction/runtime bugs
- new skill requests
- runtime sync problems
- validation gaps

## Runtime Sync

After versioned assets change, use repository scripts instead of hand-copying files:

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -Mirror
pwsh -File .\scripts\runtime\sync-vscode-global-settings.ps1 -CreateBackup
pwsh -File .\scripts\runtime\sync-vscode-global-snippets.ps1
```

## Validation Checklist

- [ ] Scope-specific instructions were loaded before editing
- [ ] Versioned source-of-truth files were updated instead of generated runtime files
- [ ] Relevant validation commands were executed
- [ ] Documentation was updated when behavior, onboarding, or runtime flow changed
- [ ] Paths in tracked files remain parameterized and privacy-safe