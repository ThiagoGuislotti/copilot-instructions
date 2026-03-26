# VS Code EOF Origin Fix

Generated: 2026-03-20

## Scope
- Remove the shared VS Code formatter configuration that is reintroducing final newlines in conflict with the repository EOF policy.
- Keep the repository baseline aligned between `.vscode/settings.tamplate.jsonc` and the global VS Code `settings.json`.
- Add regression coverage so the shared baseline does not silently restore Prettier as the default formatter for file types that must honor `insert_final_newline = false`.

## Ordered Tasks
1. Register the current EOF policy and identify the formatter settings that still conflict with it.
2. Remove the shared Prettier default formatter assignments from the VS Code global template where they can force terminal newlines.
3. Update workspace-efficiency guidance so the formatter baseline stays compatible with the repository EOF contract.
4. Add regression coverage for the shared settings template and sync flow.
5. Sync the updated template to the global VS Code profile, validate alignment, and close out the plan.

## Validation Checklist
- `passed` Prettier default formatter assignments removed from the shared global template for JS/TS/HTML/CSS/SCSS/Vue/JSON/Markdown
- `passed` `scripts/tests/runtime/vscode-global-settings-sync.tests.ps1`
- `passed` `scripts/runtime/validate-vscode-global-alignment.ps1 -WarningOnly:$false`
- `passed` empirical formatter check confirmed the bundled Prettier formatter converts `beforeEndsWithNewline=false` to `afterEndsWithNewline=true`, validating the root cause
- `passed` `scripts/validation/validate-planning-structure.ps1 -WarningOnly:$false`
- `passed` `scripts/validation/validate-instructions.ps1`
- `passed` `scripts/validation/validate-all.ps1 -ValidationProfile dev`

## Specialist
- VS Code baseline / runtime configuration

## Closeout
- Update `CHANGELOG.md`
- Return a detailed commit message