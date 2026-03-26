# Runtime Warning Remediation And Issue Summary Plan

## Objective
- remove the current warning-only noise from runtime validation flows
- add shared issue IDs and a final deduplicated warning/error summary to runtime scripts, especially `install.ps1`

## Scope Summary
- shared runtime logging helpers in `scripts/common/repository-paths.ps1`
- runtime script integration in `install.ps1`, `healthcheck.ps1`, and `self-heal.ps1`
- validation ledger self-repair in `validate-all.ps1`
- governance baseline updates for current intentional warning thresholds
- docs, changelog, and tests required by the changes

## Ordered Tasks
1. Add a shared issue registry helper layer in `scripts/common/repository-paths.ps1`.
2. Refactor `install.ps1` to emit issue IDs for warnings/errors and print a final issue summary plus a compact severity count table.
3. Refactor `healthcheck.ps1` and `self-heal.ps1` to use the same issue-summary contract.
4. Autorepair broken validation ledgers in `validate-all.ps1` by archiving the invalid ledger before new writes.
5. Update governance thresholds in `.github/governance/instruction-ownership.manifest.json` and `.github/governance/warning-baseline.json` to match the now-intentional validated state.
6. Add or update runtime tests and any README/changelog entries required by the changed script behavior.
7. Run targeted validations, then rerun `validate-all` until the current warning set is clean or intentionally accounted for.
8. Move the active spec/plan to completed when the workstream is validated.

## Validation Checklist
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Recommended Specialist
- `dev-software-engineer`
- reviewer mandatory
- release closeout mandatory

## Closeout Expectations
- update `CHANGELOG.md`
- update `scripts/README.md` if user-facing script behavior changes materially
- provide a commit message with validation evidence