# Runtime Install Sync Contract Deduplication Plan

Generated: 2026-03-22

## Status

- State: completed
- Owner: Super Agent
- Completed: 2026-03-22
- Result target: runtime install, bootstrap, doctor, healthcheck, self-heal, and audit export resolve one shared runtime execution contract instead of repeating profile and target resolution logic.

## Objective And Scope

Reduce duplicated runtime orchestration code by extracting one shared PowerShell helper for runtime execution context and install-step planning boundaries. Keep responsibilities separated: `install.ps1` remains the onboarding orchestrator, `bootstrap.ps1` remains the sync executor, and post-commit continues to call sync directly without reimplementing runtime target logic.

## Normalized Request Summary

The user wants the runtime install flow to stay non-intrusive by default and also wants synchronization behavior to remain configurable without duplicating logic across install and sync scripts. The repository should centralize shared runtime/profile/target resolution so future changes do not drift between `install`, `bootstrap`, and the runtime maintenance scripts.

## Design Decision

- Introduce one shared runtime execution helper under `scripts/common/` that resolves:
  - repo root
  - runtime profile
  - effective runtime locations
  - effective target roots
  - canonical source roots used by runtime sync and diagnostics
- Refactor runtime scripts to consume that helper instead of re-resolving the same contract independently.
- Keep `install.ps1` responsible only for deciding which steps to run, while `bootstrap.ps1` stays responsible only for synchronizing the enabled runtime surfaces.
- Leave the Git shell hooks thin and continue to route actual synchronization through `bootstrap.ps1`.

## Ordered Tasks

1. Add the shared runtime execution helper and wire it into `common-bootstrap`.
2. Refactor `bootstrap.ps1` and `install.ps1` to consume the shared helper.
3. Refactor `doctor.ps1`, `healthcheck.ps1`, `self-heal.ps1`, and `export-audit-report.ps1` to consume the same helper.
4. Update docs, tests, checksums, and close out the plan.

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Closeout

- Added one shared runtime execution contract helper for repo root, runtime profile, effective runtime locations, target roots, and canonical source layout.
- Refactored install/bootstrap/doctor/healthcheck/self-heal/audit export to consume the same shared contract instead of repeating profile and target resolution logic.
- Added a second shared runtime operation helper for output/log artifact initialization and standardized runtime `check`/`step` child-script invocation so healthcheck/self-heal/audit export no longer repeat the same execution/logging boilerplate.
- Removed the duplicate validation verbose helper implementation by making `validation-logging.ps1` consume the verbose helpers already centralized in `repository-paths.ps1`.
- Kept responsibilities separated: install remains the onboarding orchestrator, bootstrap remains the runtime sync executor, and automatic sync still stays behind explicitly configured repo-local hooks.