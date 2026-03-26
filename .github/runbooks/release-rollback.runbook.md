# Release Rollback Runbook

## Scope

Use this runbook when a committed change must be rolled back after validation or runtime regression.

## Prerequisites

1. Identify offending commit hash.
2. Confirm rollback scope (`docs`, `scripts`, `governance`, or mixed).

## Procedure

1. Create rollback branch:

```powershell
git checkout -b rollback/<date>-<topic>
```

2. Revert target commit(s):

```powershell
git revert <commit-hash>
```

3. Run release profile validations:

```powershell
pwsh -File .\scripts\validation\validate-all.ps1 -ValidationProfile release
```

4. Generate audit evidence:

```powershell
pwsh -File .\scripts\validation\export-audit-report.ps1 -ValidationProfile release
```

5. Update `CHANGELOG.md` with rollback entry.

## Post-Rollback

1. Run runtime sync if assets changed:

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -Mirror
```

2. Re-run healthcheck:

```powershell
pwsh -File .\scripts\runtime\healthcheck.ps1
```

3. Attach audit artifacts to release notes.