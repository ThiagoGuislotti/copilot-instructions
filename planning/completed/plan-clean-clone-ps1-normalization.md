# Clean Clone PowerShell Normalization

Generated: 2026-03-20
Completed: 2026-03-20

## Scope
- Eliminate tracked PowerShell files that leave a fresh clone dirty immediately after checkout.
- Normalize affected repository `.ps1` files to the repository CRLF working-tree policy without mixed line endings.
- Add validation coverage so tracked PowerShell files cannot remain `i/mixed` under `git ls-files --eol`.

## Ordered Tasks
1. Reproduce the dirty clone in an isolated checkout and confirm the worktree is already dirty before install.
2. Identify tracked `.ps1` files reported as `i/mixed ... attr/text eol=crlf`.
3. Normalize the affected files in the repository without changing their logical content.
4. Add validation coverage to fail when tracked PowerShell files have mixed or non-normalized index line endings.
5. Re-run validation and verify a fresh isolated clone stays clean.

## Findings
- The repository was already dirty immediately after a fresh clone, before `install.ps1` executed.
- `git ls-files --eol` showed the affected scripts as `i/mixed ... attr/text eol=crlf`, which means the bug lived in committed Git index normalization rather than in runtime hooks or install steps.
- `git diff --ignore-cr-at-eol` on the affected clone was empty, confirming the visible diffs were line-ending-only drift.
- After renormalization and revalidation in an isolated verification clone, `git status` stayed clean both immediately after clone and after `install.ps1 -CreateSettingsBackup -ApplyMcpConfig`.

## Validation Checklist
- `passed` isolated verification clone is clean immediately after clone
- `passed` `git ls-files --eol` reports `i/lf w/crlf attr/text eol=crlf` for the affected tracked `.ps1` files after renormalization
- `passed` `scripts/validation/validate-powershell-standards.ps1`
- `passed` `scripts/validation/validate-shell-hooks.ps1 -WarningOnly:$false`
- `passed` isolated verification clone remains clean after `scripts/runtime/install.ps1 -CreateSettingsBackup -ApplyMcpConfig`

## Specialist
- Runtime / repository hygiene

## Closeout
- Update `CHANGELOG.md`
- Return detailed commit message