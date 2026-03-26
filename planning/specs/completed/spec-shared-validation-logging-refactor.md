# Shared Validation Logging Refactor

## Summary
- Standardize validation-script logging through a shared helper instead of repeating warning, failure, verbose, and summary scaffolding in each script.
- Preserve current validation behavior and exit-code semantics while reducing duplication across `scripts/validation/*.ps1` and validation-style runtime scripts.

## Motivation
- Validation scripts currently duplicate the same log and state helpers dozens of times.
- The install/healthcheck flows surface validator output heavily, so inconsistent log scaffolding creates maintenance cost and raises the risk of drift.
- Recent runtime issue-ID work already centralized runtime summaries; validation scripts need the same level of reuse.

## Design Decisions
- Add a dedicated shared helper under `scripts/common/` for validation logging and state management.
- Keep repository path resolution in `scripts/common/repository-paths.ps1`; the new helper will depend on that shared path layer instead of re-implementing root/path helpers.
- Preserve per-script custom summaries; only centralize the repeated building blocks:
  - validation state initialization
  - verbose logging
  - warning/failure registration
  - optional standard summary writer for scripts that can use it directly
- Migrate the validation script family first, plus `scripts/runtime/validate-vscode-global-alignment.ps1` because it follows the same validation contract.

## Alternatives Considered
- Put validation helpers directly into `repository-paths.ps1`.
  - Rejected because the file already mixes path and runtime issue tracking concerns; adding validation state would make it harder to reason about.
- Create a single universal logging bootstrap for every script type.
  - Rejected for now because runtime/orchestration scripts and validation scripts have different summary semantics and exit policies.

## Risks
- Bulk migration can accidentally change warning-only behavior for specific validators.
- Shared helper changes can affect a large number of scripts simultaneously.
- Validation summaries must remain stable enough for existing tests and human operators.

## Acceptance Criteria
- A shared validation helper exists under `scripts/common/`.
- Repeated `Write-VerboseLog`, `Add-ValidationFailure`, `Add-ValidationWarning`, and local root/path helpers are removed from the migrated validation scripts.
- `validate-all` still passes under the `dev` profile.
- The resulting validator output preserves current pass/warn/fail semantics.

## Planning Readiness
- Ready for planning.

## Recommended Specialist
- `Super Agent` with repository script refactor execution.