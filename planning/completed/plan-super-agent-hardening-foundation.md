# Super Agent Hardening Foundation Plan

Generated: 2026-03-22

## Status

- State: active
- Spec: `planning/specs/active/spec-super-agent-hardening-foundation.md`

## Objective And Scope

Implement the shared runtime foundation for the next tier of Super Agent hardening: contextual policy enforcement, structured trace/replay, checkpoint-aware resume, eval execution, and model routing. Keep the current orchestration runner authoritative and avoid duplicated helper logic.

## Explicit Deferrals

- Defer true token/cost optimization to a later slice after weekly limits recover.
- The current slice may introduce the routing contract and artifact plumbing, but it must not expand into aggressive model downgrades, per-stage cost tuning, or broader prompt/context compression work in this execution window.
- Future follow-up work should explicitly cover:
  - cheaper-model routing for low-risk stages such as validate, replay, closeout, and parsing-heavy checks
  - stricter minimal-context packing to avoid loading unnecessary repository surfaces
  - eval-backed token/cost comparison before changing the default routing policy

## Normalized Request Summary

The user wants the repository to adopt the highest-value capabilities seen in strong public agent systems and start implementation immediately. The requested improvements must improve performance, quality, and security while remaining repo-owned and PowerShell-first.

## Ordered Tasks

1. Add versioned contracts for policy, trace, checkpoint, and model routing
   - Target paths:
     - `.github/governance/agent-runtime-policy.catalog.json`
     - `.github/governance/agent-model-routing.catalog.json`
     - `.github/schemas/agent.run-artifact.schema.json`
     - `.github/schemas/agent.pipeline.schema.json`
     - `.github/schemas/agent.trace-record.schema.json`
     - `.github/schemas/agent.policy-evaluation.schema.json`
     - `.github/schemas/agent.checkpoint-state.schema.json`
     - `.codex/orchestration/templates/*.json`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot . -WarningOnly:$false`
   - Checkpoints:
     - schemas and templates validate
     - routing/policy catalogs are versioned and deterministic
   - Commit checkpoint:
     - scope: `task`
     - when: `after contracts and templates validate cleanly`
     - suggestedMessage: `feat: add Super Agent hardening runtime contracts`

2. Add shared runtime hardening helper and integrate the pipeline runner
   - Target paths:
     - `scripts/common/agent-runtime-hardening.ps1`
     - `scripts/common/common-bootstrap.ps1`
     - `scripts/runtime/run-agent-pipeline.ps1`
     - `scripts/orchestration/engine/invoke-codex-dispatch.ps1`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1 -RepoRoot .`
   - Checkpoints:
     - runner writes policy, trace, and checkpoint artifacts
     - runner records effective model selection
     - blocked policy decisions fail deterministically
   - Commit checkpoint:
     - scope: `slice`
     - when: `after runner integration and orchestration tests are green`
     - suggestedMessage: `feat: add policy trace and checkpoint artifacts to the agent runner`

3. Add replay, resume, and eval entrypoints
   - Target paths:
     - `scripts/runtime/resume-agent-pipeline.ps1`
     - `scripts/runtime/replay-agent-run.ps1`
     - `scripts/runtime/evaluate-agent-pipeline.ps1`
     - `.codex/orchestration/evals/golden-tests.json`
     - `scripts/tests/runtime/runtime-scripts.tests.ps1`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
   - Checkpoints:
     - resume continues from the last safe completed stage
     - replay summarizes run trace and policy outcomes
     - eval runner executes versioned fixtures and produces a scorecard artifact
   - Commit checkpoint:
     - scope: `slice`
     - when: `after runtime entrypoints and tests are green`
     - suggestedMessage: `feat: add Super Agent replay resume and eval entrypoints`

4. Tighten validations and public docs
   - Target paths:
     - `scripts/validation/validate-agent-orchestration.ps1`
     - `README.md`
     - `scripts/README.md`
     - `CHANGELOG.md`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
   - Checkpoints:
     - docs explain what is enforced now versus deferred later
     - validation catches contract drift for policy/routing/trace/checkpoints
   - Commit checkpoint:
     - scope: `final`
     - when: `after docs and validate-all are green`
     - suggestedMessage: `feat: add Super Agent hardening foundation for policy trace resume eval and routing`

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-orchestration.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/agent-orchestration-engine.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Risks And Fallbacks

- Risk: policy rules over-block valid work.
  - Fallback: keep versioned policy actions explicit (`allow`, `warn`, `block`) and start with a narrow ruleset.
- Risk: resume restarts from an unsafe point.
  - Fallback: only resume from the first pending stage after the last successful checkpointed stage.
- Risk: artifacts proliferate without operational value.
  - Fallback: keep trace/policy/checkpoint outputs summarized and deterministic, and reuse a shared helper for all serialization.
- Risk: this slice grows into model-cost optimization work and burns remaining usage budget.
  - Fallback: keep token/cost optimization explicitly documented as deferred and limit this slice to the hardening foundation only.

## Recommended Specialists

- Implementation: `ops-devops-platform-engineer`
- Security review focus: `sec-api-performance-security-engineer`
- Observability review focus: `obs-sre-observability-engineer`
- Final review: `review-code-engineer`
- Closeout: `release-closeout-engineer`

## Closeout Expectations

- Update README and scripts README for the new hardening foundation commands and artifact layout.
- Return a commit message for the stable checkpoint.
- Keep sandbox isolation and A2A-style interoperability out of this slice unless a minimal, validated repo-owned surface can be added without broad runtime churn.