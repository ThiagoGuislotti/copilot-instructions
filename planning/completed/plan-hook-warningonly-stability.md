# Hook WarningOnly Stability

Generated: 2026-03-20
Completed: 2026-03-20

## Scope
- Stop Git shell hooks from failing on PowerShell boolean binding for `validate-all.ps1`.
- Keep the shell-safe quoted PowerShell boolean literal convention in `.githooks/*`.
- Make `validate-all.ps1` tolerant of older hook wrappers that still pass string-like boolean values.

## Ordered Tasks
1. Confirm the failing runtime shape from `post-checkout` / `post-merge`.
2. Keep the shell-safe hook form `'-WarningOnly:$true'` instead of introducing unsupported bare or unquoted variants.
3. Harden `scripts/validation/validate-all.ps1` so stale wrappers using `-WarningOnly true` no longer crash argument binding.
4. Revalidate shell hooks and smoke-test hook execution paths.
5. Update `CHANGELOG.md` and close out the plan.

## Findings
- The active hook implementation was not writing back into repository scripts during local reproduction.
- The reproducible bug was PowerShell parameter binding on `WarningOnly`, not hook-driven script mutation.
- Local script dirtiness seen on the extra machine is more consistent with separate working-tree drift such as EOF/line-ending normalization, not with `post-checkout` rewriting files.

## Validation Checklist
- `passed` `.githooks/pre-commit` uses shell-safe `'-WarningOnly:$true'`
- `passed` `.githooks/post-checkout` uses shell-safe `'-WarningOnly:$true'`
- `passed` `.githooks/post-merge` uses shell-safe `'-WarningOnly:$true'`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shell-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev -WarningOnly true`
- `passed` `sh .githooks/post-checkout`

## Specialist
- Runtime / shell-hook maintenance

## Closeout
- Updated `CHANGELOG.md`
- Return detailed commit message