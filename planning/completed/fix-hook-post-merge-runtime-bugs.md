# Hook Post-Merge Runtime Bug Fix

Generated: 2026-03-20

## Scope
- Fix PowerShell boolean argument passing in shell hooks so post-merge, pre-commit, and post-checkout do not break on `validate-all`.
- Fix `clean-codex-runtime.ps1` so empty file collections do not crash byte-sum calculations.
- Add regression coverage so the same bug cannot silently return through hooks/runtime cleanup.

## Ordered Tasks
1. Correct shell hook boolean invocation for `validate-all`, including shell-safe quoting for PowerShell boolean literals.
2. Harden runtime cleanup byte aggregation for empty collections.
3. Add regression validation/tests for hook argument shape and empty cleanup scenarios.
4. Run validation and close out the plan.

## Validation Checklist
- `passed` hook scripts use the shell-safe single-quoted literal form `'-WarningOnly:$true'`
- `passed` `scripts/tests/runtime/runtime-scripts.tests.ps1`
- `passed` `scripts/validation/validate-shell-hooks.ps1 -WarningOnly:$false`
- `passed` `scripts/validation/validate-runtime-script-tests.ps1 -WarningOnly:$false`

## Specialist
- Runtime / shell-hook maintenance

## Closeout
- Update `CHANGELOG.md`
- Return detailed commit message