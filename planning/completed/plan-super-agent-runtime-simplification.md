# Plan: Super Agent Runtime Simplification

## Objective

Simplify the Super Agent VS Code runtime so activation stays obvious without adding ongoing prompt overhead or local hook telemetry.

## Scope Summary

- `.github/hooks/super-agent.bootstrap.json`
- `.github/hooks/scripts/common.ps1`
- `.github/hooks/scripts/session-start.ps1`
- `.github/hooks/scripts/subagent-start.ps1`
- `scripts/validation/validate-agent-hooks.ps1`
- `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
- `CHANGELOG.md`

## Spec Decision

- Separate spec not required. This is a simplification pass based on the observed superpowers hook model.

## Ordered Tasks

1. Remove runtime hook telemetry and prompt-level reinforcement that do not materially improve activation confidence.
2. Keep SessionStart as the primary activation point, with a single visible activation banner contract.
3. Update validation/tests to match the simplified hook surface.
4. Remove obsolete prompt-level reinforcement artifacts, update changelog, and move the plan to completed after validation.

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/bootstrap.ps1 -RepoRoot .`