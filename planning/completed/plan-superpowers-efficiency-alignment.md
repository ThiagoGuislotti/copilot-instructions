# Superpowers Efficiency Alignment Plan

Generated: 2026-03-20

## Goal
- Capture the practical efficiency gains of `obra/superpowers` in `copilot-instructions` without losing existing instructions, skills, validations, runtime sync, or enterprise governance.

## Non-Negotiables
- Preserve all current repository instructions, policies, and validations.
- Keep `copilot-instructions` as the source of truth for runtime assets.
- Prefer additive improvements and controlled centralization over replacement.
- Do not regress Windows/PowerShell-first support.
- Do not reduce validation coverage or make safety checks optional by default.

## Current Baseline
- Versioned planning workspace under `planning/`.
- Deterministic orchestration pipeline with `plan -> route -> implement -> validate -> review -> closeout`.
- Runtime sync for `%USERPROFILE%\\.github`, `%USERPROFILE%\\.codex`, VS Code global settings, and snippets.
- Strong validation and governance coverage (`validate-all`, policy baselines, ownership manifest, runtime tests).
- Repository specialists already available for planning, routing, implementation, review, closeout, security, platform, and observability.
- Codex `multi_agent = true` already enabled in runtime config.

## Superpowers Gaps That Matter

### 1. Session bootstrap discipline
- `superpowers` injects `using-superpowers` at session start through a hook.
- Current repo relies on static mandatory context plus routing, but does not enforce a session-start bootstrap layer for Codex.
- Impact: weaker guarantee that the workflow is activated before ad-hoc implementation starts.

### 2. Dedicated spec / brainstorming phase
- `superpowers` separates brainstorming/spec approval before plan writing.
- Current repo has planning and routing, but no explicit first-class brainstorming/spec artifact workflow.
- Impact: some tasks can move into implementation planning before design alternatives are fully locked down.

### 3. Plan granularity
- `superpowers` plans are stricter: tiny steps, exact files, explicit commands, expected failures, expected passes, and commit checkpoints.
- Current repo plans are structured and versioned, but not yet uniformly that granular.
- Impact: controller-to-worker handoff is less deterministic than it could be.

### 4. Worktree isolation
- `superpowers` has a dedicated `using-git-worktrees` workflow.
- Current repo has strong Git hook automation but no first-class worktree setup skill/runbook for isolated execution.
- Impact: less isolation for large or risky workstreams.

### 5. Task-level subagent execution loop
- `superpowers` executes each task with a fresh implementer, then runs spec review, then code-quality review, and loops until approved.
- Current repo orchestration is stage-based and sequential, but not yet task-loop driven with two-stage review per task.
- Impact: reviews happen later and at coarser granularity than ideal.

### 6. Safe parallel dispatch
- `superpowers` has an explicit `dispatching-parallel-agents` pattern.
- Current repo has multi-agent support enabled and orchestration contracts, but real DAG-based parallel fan-out with write-set conflict protection is not delivered yet.
- Impact: we are leaving performance on the table for independent work items.

### 7. Hard TDD / verification discipline
- `superpowers` enforces strict TDD and verification-before-completion as rigid process skills.
- Current repo has `test-engineer` and validation gates, but not the same strict global TDD contract.
- Impact: implementation quality depends more on task interpretation than on enforced workflow.

### 8. Lightweight runtime entry commands
- `superpowers` exposes simple workflow entry points and plugin hooks.
- Current repo has scripts and prompts, but no thin workflow entry layer for `brainstorm`, `write-plan`, `execute-plan`, or equivalent runtime shortcuts.
- Impact: workflow is powerful but less ergonomic than it could be.

## What We Should Not Copy
- Do not replace repository governance with external skill content.
- Do not make TDD dogma override explicit user direction.
- Do not introduce plugin-marketplace-specific assumptions into the repo source of truth.
- Do not duplicate skills or instructions when the current repo already has the stronger enterprise version.
- Do not bypass the existing routing catalog, ownership manifest, baselines, or runtime sync model.

## Target Architecture

### A. Session Entry Layer
- Add a repository-native session bootstrap pattern for Codex.
- Inject a lightweight "workflow activation" contract at session start.
- Keep it repo-owned and runtime-synced, not external-repo dependent.

### B. Spec Layer
- Add a first-class brainstorming/spec workflow before implementation planning.
- Keep specs versioned and separable from implementation plans.
- Require design approval for non-trivial feature work before plan execution.

### C. Planning Layer
- Strengthen active plans so each task can be handed to a worker with minimal ambiguity.
- Standardize:
  - exact file paths
  - explicit test commands
  - expected failure/pass checkpoints
  - commit checkpoint suggestions

### D. Execution Layer
- Upgrade from stage-only orchestration to task-aware orchestration.
- Support:
  - fresh worker per task
  - spec-compliance review
  - code-quality review
  - review loops before task completion

### E. Parallelization Layer
- Add true DAG-based parallel dispatch for independent tasks.
- Enforce write-set isolation and conflict blocking before workers start.

### F. Isolation Layer
- Add a repository-native worktree setup workflow for risky or long-running work.
- Keep it optional but preferred for large feature branches and multi-task execution.

### G. Quality Layer
- Introduce stronger default TDD/verification workflow guidance without weakening current enterprise constraints.
- Keep explicit exceptions for POC/spike/informal-test flows.

### H. Ergonomics Layer
- Add thin workflow entry prompts/scripts for:
  - brainstorming
  - writing plans
  - executing plans
  - dispatching parallel workers
- Keep them as wrappers over the repository-native flow, not as a second architecture.

## Recommended Workstreams

## Progress
- [x] 1. Create comparison and tracked plan.
- [x] 2. Define repository-native Super Agent orchestration contract, intake stage, and repo-owned bootstrap behavior for request normalization before planning.
- [ ] 3. Add a true Codex session-start hook only if the runtime later exposes a supported repository-owned startup hook surface.
- [x] 4. Add brainstorming/spec workflow and versioned spec artifact location.
- [x] 5. Harden plan schema and planner skill so tasks become worker-ready with exact files, tests, and checkpoints.
- [x] 6. Add first-class worktree isolation workflow with Windows-safe implementation and validation.
- [x] 7. Upgrade orchestration from stage-only execution to task-loop execution with spec review then code-quality review.
- [x] 8. Implement safe parallel dispatch with dependency graph and write-set conflict detection.
- [x] 9. Add stricter TDD and verification workflow contracts integrated with existing specialists and validations.
- [x] 10. Add workflow entry prompts/commands for brainstorm, write-plan, execute-plan, and parallel dispatch.
- [x] 11. Run full validation, sync runtime, update docs, and produce closeout guidance.

## Validation Checklist
- [x] No current instruction, skill, or policy is removed without a stronger repository-owned replacement.
- [x] `validate-all` remains green after each phase.
- [x] Runtime sync continues to project cleanly into `%USERPROFILE%\\.github`, `%USERPROFILE%\\.codex`, and VS Code global assets.
- [x] New workflow layers are versioned, documented, and tested.
- [x] Parallel execution refuses overlapping write-sets.
- [x] Worktree automation remains Windows-safe and does not introduce destructive defaults.
- [x] Brainstorm/spec workflow is optional only for trivial tasks and mandatory for non-trivial feature work.

## Recommended Specialists
- Primary: `ops-devops-platform-engineer`
- Secondary: `plan-active-work-planner`
- Mandatory reviewers for implementation phases: `review-code-engineer` and `docs-release-engineer`

## Closeout Expectations
- Update README and orchestration docs when any workflow contract changes.
- Produce commit-message guidance per stable phase.
- Add changelog-ready summary whenever the workflow surface or runtime behavior changes materially.

## Notes
- `superpowers` is strongest in session bootstrap, rigid workflow discipline, and ergonomic workflow entry.
- `copilot-instructions` is already stronger in enterprise governance, validation, runtime sync, and source-of-truth control.
- The correct path is selective absorption of the high-leverage workflow mechanics, not wholesale adoption.
- Phase 4 delivered a repository-owned `brainstorm/spec` stage, versioned `planning/specs/` workspace, new brainstorm specialist skill, orchestration contracts, routing coverage, runtime sync, and green validation for the added workflow.
- Phase 5 hardened planner output so each work item now carries target paths, explicit commands, expected checkpoints, and commit checkpoint guidance for deterministic worker handoff.
- Phase 6 delivered repository-owned worktree isolation with instruction coverage, a dedicated skill, runtime helper script, and native tests.
- Phase 7 upgraded implementation from coarse stage execution to task-loop execution with implementer work, task-level spec review, task-level quality review, and retry handling.
- Phase 8 delivered safe parallel dispatch through dependency-aware task batching and overlapping write-set conflict blocking before fan-out.
- Phase 9 added repository-owned TDD and verification workflow contracts that integrate with the existing enterprise specialist chain.
- Phase 10 delivered thin workflow entry commands for brainstorming, planning, full execution, and parallel dispatch.
- Phase 11 closed the workstream with updated public docs, changelog coverage, routing fixtures, runtime validation, and closeout guidance.