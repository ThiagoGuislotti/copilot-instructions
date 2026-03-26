# Runtime Drift Runbook

## Scope

Use this runbook when runtime folders (`~/.github`, `~/.codex`) diverge from repository source-of-truth.

## Detect

```powershell
pwsh -File .\scripts\runtime\doctor.ps1 -Detailed
```

## Repair

1. Sync runtime using mirror mode:

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -Mirror
```

2. Re-check drift:

```powershell
pwsh -File .\scripts\runtime\doctor.ps1 -Detailed
```

3. Run healthcheck:

```powershell
pwsh -File .\scripts\runtime\healthcheck.ps1
```

## Cleanup

```powershell
pwsh -File .\scripts\runtime\clean-codex-runtime.ps1 -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 30 -Apply
```

## Notes

- Healthcheck runs in warning-only mode by default.
- Use strict enforcement only when explicit governance requires it.