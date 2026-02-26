# Release Governance

## Scope

This repository uses local-first governance for instruction and runtime assets.
Validation is deterministic and runs from scripts under `scripts/validation` and `scripts/runtime`.

## Branch Protection

Branch protection baseline is versioned in `.github/governance/branch-protection.baseline.json`.
Apply or validate baseline drift with:

```powershell
pwsh -File .\scripts\governance\set-branch-protection.ps1
pwsh -File .\scripts\governance\set-branch-protection.ps1 -Apply
```

Notes:
- Branch protection mutation is opt-in (`-Apply`).
- Script requires `gh` CLI authenticated with permissions to manage branch protection.
- Keep `required_status_checks.contexts` aligned with active GitHub Actions job names.

## CODEOWNERS

`CODEOWNERS` is mandatory and validated by:
- `scripts/validation/validate-policy.ps1` (file presence)
- `scripts/validation/validate-release-governance.ps1` (rule quality checks)

At minimum:
- Catch-all owner rule (`* owner`)
- Governance path ownership for `.github/`, `.githooks/`, and `scripts/`

## Release Checklist

1. Run baseline validations:
   - `pwsh -File .\scripts\validation\validate-instructions.ps1`
   - `pwsh -File .\scripts\validation\validate-policy.ps1`
   - `pwsh -File .\scripts\validation\validate-agent-orchestration.ps1`
   - `pwsh -File .\scripts\validation\validate-release-governance.ps1`
2. Confirm branch protection drift is zero:
   - `pwsh -File .\scripts\governance\set-branch-protection.ps1`
3. Update `CHANGELOG.md` with semantic version entry `[X.Y.Z] - YYYY-MM-DD`.
4. Create tag `copilot-vX.Y.Z` after merge to default branch.
5. Export audit package:
   - `pwsh -File .\scripts\validation\export-audit-report.ps1 -StrictExtras`

## Rollback

1. Revert faulty commit(s) in a dedicated fix branch.
2. Re-run all validation scripts.
3. Re-apply branch protection baseline if drift was introduced.
4. Publish corrective changelog entry and matching tag.
