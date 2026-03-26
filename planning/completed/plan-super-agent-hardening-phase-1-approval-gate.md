# Super Agent Hardening Phase 1 Plan

Generated: 2026-03-21

## Status

- State: completed
- Completed: 2026-03-21
- Result: approval gate for sensitive stages and agents is enforced in the orchestration runner, persisted in run artifacts, exposed through entrypoints, and covered by runtime/orchestration validation.

## Objective And Scope

Implement the first hardening increment for the repository-owned Super Agent: explicit approval gating for sensitive execution paths in the orchestration runner, while also registering the broader roadmap for later phases.

## Normalized Request Summary

The user wants a concrete roadmap of high-value Super Agent improvements and wants implementation to start immediately. The first increment should deliver real safety improvement rather than only documentation.

## Active Spec

- `planning/specs/completed/spec-super-agent-hardening-roadmap.md`

## Phase Roadmap

1. Phase 1: approval gate for sensitive stages and agents
2. Phase 2: contextual security policy engine for tool-call sequences and prompt-injection resistance
3. Phase 3: trace, cost, replay, and OpenTelemetry-aligned observability
4. Phase 4: durable resume and checkpoint-aware recovery
5. Phase 5: eval harness and regression scorecards for agentic execution
6. Phase 6: interoperability and model-routing improvements, including A2A-compatible surfaces where useful

## Ordered Tasks

1. Extend orchestration contracts for approval metadata
   - Target paths:
     - `.github/schemas/agent.contract.schema.json`
     - `.codex/orchestration/agents.manifest.json`
     - `.github/schemas/agent.run-artifact.schema.json` if needed
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot . -WarningOnly:$false`
   - Checkpoints:
     - schema accepts approval metadata cleanly
     - manifest marks sensitive agents explicitly
   - Commit checkpoint:
     - scope: `task`
     - when: `after schema and manifest contracts validate`
     - suggestedMessage: `feat: add approval metadata to agent orchestration contracts`

2. Enforce approval in the runtime pipeline and entrypoints
   - Target paths:
     - `scripts/runtime/run-agent-pipeline.ps1`
     - `scripts/runtime/invoke-super-agent-execute.ps1`
     - `scripts/runtime/invoke-super-agent-parallel-dispatch.ps1`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/super-agent-entrypoints.tests.ps1 -RepoRoot .`
     - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
   - Checkpoints:
     - pipeline refuses sensitive stage execution without approval
     - approval record is persisted per run
     - entrypoints expose approval parameters clearly
   - Commit checkpoint:
     - scope: `task`
     - when: `after runner enforcement and wrapper forwarding are green`
     - suggestedMessage: `feat: enforce approval gate for sensitive Super Agent stages`

3. Strengthen validation and runtime tests
   - Target paths:
     - `scripts/validation/validate-agent-orchestration.ps1`
     - `scripts/tests/runtime/agent-orchestration-engine.tests.ps1`
     - `scripts/tests/runtime/super-agent-entrypoints.tests.ps1`
     - `scripts/tests/runtime/runtime-scripts.tests.ps1`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1 -RepoRoot .`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot . -WarningOnly:$false`
   - Checkpoints:
     - missing approval fails deterministically
     - approved execution passes deterministically
     - orchestration validation checks the new contract
   - Commit checkpoint:
     - scope: `slice`
     - when: `after runtime and validation tests pass for the approval flow`
     - suggestedMessage: `test: cover approval gating in orchestration runtime`

4. Document phase 1 and preserve the next phases
   - Target paths:
     - `README.md`
     - `scripts/README.md`
     - `CHANGELOG.md`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
   - Checkpoints:
     - docs explain approval usage without overstating future phases
     - roadmap remains explicit for later work
   - Commit checkpoint:
     - scope: `phase`
     - when: `after docs and validate-all are green`
     - suggestedMessage: `docs: record Super Agent phase 1 approval gate and roadmap`

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/super-agent-entrypoints.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Validation Results

- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot . -WarningOnly:$false`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/super-agent-entrypoints.tests.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Risks And Fallbacks

- Risk: approval requirements may surprise existing users of `invoke-super-agent-execute.ps1`.
  - Fallback: document the approval parameters and keep phase 1 limited to clearly sensitive stages.
- Risk: approval enforcement in the runner can create test churn.
  - Fallback: keep the gate at the runner layer and update only the impacted orchestration tests.
- Risk: approval metadata can drift from actual stage sensitivity.
  - Fallback: keep the policy close to the manifest and validate it in orchestration checks.

## Recommended Specialists

- Implementation: `ops-devops-platform-engineer`
- Security review focus: `sec-api-performance-security-engineer`
- Final review: `review-code-engineer`
- Closeout: `release-closeout-engineer`

## Closeout Expectations

- Update README and scripts README for the approval flow.
- Return a commit message for the stable phase 1 checkpoint.
- Keep the umbrella roadmap archived in completed planning/spec once phase 1 is materially complete, and open later phases as smaller active specs only when execution resumes.