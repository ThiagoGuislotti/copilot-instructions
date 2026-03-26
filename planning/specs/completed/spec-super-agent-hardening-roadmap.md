# Super Agent Hardening Roadmap

Generated: 2026-03-21

## Status

- State: completed
- Completed: 2026-03-22
- Result: Phase 1 approval gate is implemented and validated, and the umbrella roadmap is now archived as historical design intent. Future phases should open phase-specific active specs only when execution actually starts.

## Current Status

- Phase 1 approval gate is implemented and validated.
- Next recommended increment when work resumes: contextual security policy engine for tool-call sequences and prompt-injection resistance.

## Objective

Harden the repository-owned Super Agent with the next tier of enterprise capabilities without replacing the current Codex/Copilot-based architecture. Focus on improvements that materially raise safety, execution reliability, observability, and interoperability.

## Normalized Request Summary

The user wants a concrete planning workstream that turns the previously identified gaps into an execution roadmap and starts implementation immediately. The improvements must preserve the existing Super Agent workflow, validations, and runtime integration.

## Design Summary

The Super Agent remains a repository-owned controller on top of Codex/Copilot. We will not replace it with an external framework. Instead, we will absorb the highest-value capabilities from reference systems in phased increments:

1. approval gate for sensitive execution
2. security policy engine for contextual tool-call guardrails
3. richer trace, cost, and replay observability
4. durable resume from persisted checkpoints
5. eval harness for agentic regression tracking
6. interoperability and model-routing improvements

Phase 1 is complete: approval gating for sensitive stages and agents is now enforced in the orchestration runner. This umbrella roadmap is now archived in `planning/specs/completed/`; future phases should be represented by smaller phase-specific specs in `planning/specs/active/` only while execution is active.

## Key Decisions

1. Keep the current Super Agent pipeline, hooks, skills, and repo-owned governance model.
2. Treat external agent frameworks as capability references, not architectural replacements.
3. Start with approval gating because it closes the strongest near-term safety gap with limited blast radius.
4. Implement approval gating through repository-owned contracts, runner enforcement, and persisted approval artifacts.
5. Preserve existing scripted and live execution modes while making sensitive execution explicitly approvable.

## Alternatives Considered

1. Replace the orchestration runtime with LangGraph, CrewAI, or OpenHands.
   - Rejected because it would throw away too much repository-owned workflow and governance value.
2. Add only documentation for future approval rules without changing runtime behavior.
   - Rejected because it would not materially improve safety.
3. Implement observability first.
   - Rejected because approval gating is the more immediate risk reduction.

## Assumptions And Constraints

- The repository-owned orchestration pipeline stays the source of truth.
- Existing validations must remain green after each phase.
- Phase 1 should avoid invasive changes to every stage script.
- Approval gating must stay auditable and understandable from CLI entrypoints.
- The solution must remain PowerShell-first and Windows-safe.

## Risks

- Requiring approval for sensitive execution can break existing workflow expectations if not documented clearly.
- Approval gating that is too coarse can become friction rather than safety.
- Approval metadata added to manifests and runtime outputs can drift if validations are not strengthened.

## Acceptance Criteria

1. A versioned roadmap exists for Super Agent hardening.
2. Phase 1 approval gate is implemented in the runner and exposed through entrypoints.
3. Sensitive stage execution fails clearly when explicit approval is missing.
4. Approval metadata is versioned, validated, and persisted in run artifacts.
5. The impacted runtime and orchestration tests pass.
6. Later phases remain explicitly identified for future work, but must reopen as phase-specific active specs only when execution resumes.

## Closeout Statement

The roadmap served its purpose for Phase 1. It is now closed as an umbrella reference so `planning/specs/active/` does not carry a long-lived strategic placeholder. The next execution phase should start with a new active spec focused on the immediate slice being implemented.

## Recommended Specialist Focus

- Primary: `ops-devops-platform-engineer`
- Secondary: `sec-api-performance-security-engineer`
- Mandatory follow-on phases: `obs-sre-observability-engineer`, `review-code-engineer`, `release-closeout-engineer`