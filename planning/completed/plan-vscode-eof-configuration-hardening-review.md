# Plan: VS Code EOF Configuration Hardening Review

## Objective

Review the repository-managed VS Code and editor configuration stack that influences terminal newlines, remove any remaining configuration conflicts with the repository EOF policy, and validate the resulting global settings projection without introducing automatic cleanup flows.

## Completed Work

1. Audited the repository and projected user settings stack:
   - `.editorconfig`
   - `.vscode/settings.tamplate.jsonc`
   - `.vscode/base.code-workspace`
   - `%APPDATA%\\Code\\User\\settings.json`
   - `.github/instructions/vscode-workspace-efficiency.instructions.md`
2. Confirmed the main baseline was already correct:
   - `insert_final_newline = false` in `.editorconfig`
   - `files.insertFinalNewline = false` in the shared VS Code template and the projected global user settings
   - no shared default formatter configured for the EOF-sensitive web/document languages
3. Removed the remaining configuration conflicts and weak spots in `.vscode/settings.tamplate.jsonc`:
   - kept `editor.formatOnPaste = false`
   - kept `editor.formatOnType = false`
   - enabled `files.trimFinalNewlines = true` to trim extra blank final lines on save
   - changed `[go].editor.formatOnSave` from `true` to `false` because formatter-managed save behavior conflicts with the repository EOF policy
4. Updated the workspace-efficiency instruction to keep shared format triggers disabled unless a narrower repository rule explicitly accepts formatter-managed EOF behavior.
5. Extended the global settings sync runtime tests to assert the strengthened EOF-related settings and the removed Go format-on-save conflict.
6. Applied the updated shared template to `%APPDATA%\\Code\\User\\settings.json` with a backup.

## Validation

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-global-settings-sync.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/validate-vscode-global-alignment.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Outcome

The configuration stack is now stricter at the editor/settings level without introducing automatic cleanup flows. The repository still relies on the repository-owned hook layer for AI tool writes, but the shared VS Code baseline no longer contains the remaining format-trigger conflict that could reintroduce a terminal newline through normal editor behavior.