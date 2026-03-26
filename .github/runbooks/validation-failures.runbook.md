# Validation Failures Runbook

## Scope

Use this runbook when one or more validation scripts report failures or warnings that need triage.

## Triage

1. Run full suite with current profile:

```powershell
pwsh -File .\scripts\validation\validate-all.ps1
```

2. Run with release profile for full diagnostics:

```powershell
pwsh -File .\scripts\validation\validate-all.ps1 -ValidationProfile release
```

3. Export evidence:

```powershell
pwsh -File .\scripts\validation\export-audit-report.ps1 -ValidationProfile release
```

## Classify Findings

1. Contract issues:
- `validate-policy`
- `validate-release-governance`
- `validate-release-provenance`

2. Instruction/runtime issues:
- `validate-instructions`
- `validate-routing-coverage`
- `validate-agent-permissions`
- `validate-agent-orchestration`

3. Engineering quality issues:
- `validate-powershell-standards`
- `validate-warning-baseline`
- `validate-supply-chain`

## Recovery

1. Apply targeted fixes.
2. Re-run failing scripts individually.
3. Re-run `validate-all`.
4. Generate updated audit report.

## Escalation

Escalate when any finding indicates secrets exposure, supply-chain compromise, or persistent provenance/ledger corruption.