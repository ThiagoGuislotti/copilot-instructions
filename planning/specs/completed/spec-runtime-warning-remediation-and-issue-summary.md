# Spec: Runtime Warning Remediation And Issue Summary

## Objective

Eliminate the current warning-only noise from the repository runtime/validation flow and add a shared issue-summary mechanism so runtime scripts emit stable warning/error IDs at the point of occurrence and print a deduplicated final summary with counts.

## Normalized Request Summary

- The current install and related runtime scripts scatter warnings and errors throughout the log without a consolidated issue summary.
- The user wants every logged warning/error to carry an ID, and the final summary to list only the issue IDs/codes plus a compact count table without duplicating full details.
- The user also wants the currently reported warnings fixed, not just suppressed.

## Design Summary

1. Add a shared runtime issue registry to `scripts/common/repository-paths.ps1`.
2. Use the shared registry in `install.ps1`, `healthcheck.ps1`, and `self-heal.ps1` so warning/error lines get issue IDs and each script prints one final deduplicated summary.
3. Autocure the local validation ledger chain when it is broken so `validate-all` no longer warns repeatedly for stale local artifacts.
4. Update governance thresholds that are intentionally too low for the now-larger global instruction surfaces and warning baseline.

## Key Decisions

1. Issue IDs will be generated per severity bucket with stable run-local numbering such as `WRN001` and `ERR001`.
2. Repeated log sites with the same code/message signature will reuse the same issue ID within a run.
3. Final summaries will show only IDs, severity, code, occurrence count, and first message.
4. The shared helper will preserve existing info/ok logs without issue IDs to avoid unnecessary noise.
5. Warning remediation will prefer targeted governance fixes and ledger repair over muting outputs.

## Scope

In scope:
- `scripts/common/repository-paths.ps1`
- `scripts/runtime/install.ps1`
- `scripts/runtime/healthcheck.ps1`
- `scripts/runtime/self-heal.ps1`
- `scripts/validation/validate-all.ps1`
- governance JSON updates for current warning thresholds/budgets
- tests/docs/changelog needed by the changes

Out of scope:
- retrofitting every validation script in the repository to the new runtime issue contract
- changing the meaning of warning-only mode

## Risks

1. Centralizing issue tracking can break existing log expectations if the helper changes too broadly.
2. Ledger auto-repair must not destroy evidence silently; it should archive broken ledgers before starting a new chain.
3. Raising governance thresholds without justification could mask real regressions, so only the currently validated intentional deltas should be reflected.

## Acceptance Criteria

1. `install.ps1` prints issue IDs on warning/error lines and a final deduplicated issue summary with counts.
2. `healthcheck.ps1` and `self-heal.ps1` use the same shared issue-summary contract.
3. `validate-all.ps1` no longer emits the current ledger chain-break warning for stale local ledgers; broken ledgers are archived/rotated.
4. The current warnings from instruction-architecture and warning-baseline are resolved through explicit governed changes.
5. Relevant runtime and validation tests pass.

## Planning Readiness

Ready for execution planning.