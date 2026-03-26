# Closeout README and CHANGELOG Automation

## Objective
- Extend the closeout stage so it can apply README updates and CHANGELOG updates directly when the closeout result is ready for commit.

## Scope
- closeout schema
- closeout prompt
- release-closeout skill metadata
- closeout stage script
- orchestration pipeline/template output artifacts
- runtime engine tests
- minimal documentation alignment

## Tasks
1. [x] Extend the closeout result contract with structured README updates and changelog update payloads.
2. [x] Implement safe file-application logic in `scripts/orchestration/stages/closeout-stage.ps1`.
3. [x] Add output artifacts for README and CHANGELOG update reports.
4. [x] Update prompts, skill docs, pipeline contracts, and repository docs.
5. [x] Update runtime tests to verify applied updates and restore modified files.
6. [x] Run the relevant validation suite.

## Validation
- `pwsh -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1 -RepoRoot .`
- `pwsh -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot .`
- `pwsh -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Result
- Closeout now accepts structured README rewrite payloads and a structured changelog update payload.
- Closeout writes `readme-updates` and `changelog-update` artifacts in addition to the existing release summary outputs.
- README rewrites and changelog prepends run only when the closeout result is `ready-for-commit`.
- Runtime engine tests verify that the closeout stage updates files and restores repository docs afterward.

## Risks
- Closeout must not write outside the repository root.
- README and CHANGELOG updates must not run when closeout is blocked.
- Test coverage must restore touched docs to avoid dirtying the repo from runtime tests.

## Closeout Expectations
- README updates are applied only from schema-valid closeout output.
- CHANGELOG update is prepended deterministically and skipped if already present.
- The closeout summary reports which docs were updated.