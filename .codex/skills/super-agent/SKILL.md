---
name: super-agent
description: Use as the single visible starter and controller for workspace work that may change files, runtime assets, planning state, docs, settings, or governance. Normalize the request into the Super Agent lifecycle: intake, spec registration for non-trivial work, planning registration, specialist routing, execution, testing, review, closeout, and planning-state updates before implementation begins.
---

# Super Agent

## Load minimal context first

1. If the workspace provides local `.github/AGENTS.md` and `.github/copilot-instructions.md`, load them first.
2. Otherwise load the mirrored runtime `~/.github/AGENTS.md` and `~/.github/copilot-instructions.md`.
3. Load `.github/instructions/super-agent.instructions.md` when the workspace provides it, otherwise use the mirrored runtime copy under `~/.github/instructions/`.
4. Load `.github/instructions/subagent-planning-workflow.instructions.md` when the workspace provides it, otherwise use the mirrored runtime copy.
5. Only load `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md` when the workspace actually provides them.
6. Only load `.github/instructions/repository-operating-model.instructions.md` when the workspace actually provides a local repo adapter and repo-specific operating model.
7. Reuse the shared `$plan-active-work-planner`, `$context-token-optimizer`, and `$release-closeout-engineer` skills as downstream stages.

## Responsibilities

- normalize the request before planning or implementation
- act as the first controller for any change-bearing workspace request, even when not explicitly named
- decide whether the task is change-bearing, non-trivial, or safe to keep lightweight
- ask up to 3 concise clarification questions and stop before spec/planning when ambiguity would materially change scope, architecture, runtime behavior, validation, or operational safety
- create or update the active spec first for non-trivial change-bearing work under `planning/` when available, otherwise under `.build/super-agent/`
- create or update the active plan for any change-bearing workstream under `planning/` when available, otherwise under `.build/super-agent/`
- identify the smallest correct specialist chain
- keep execution sequential by default and allow multiple subagents only when write-scope conflicts are controlled
- require tester, reviewer, and closeout before claiming workspace work is complete
- always prepare a commit message suggestion and update planning state after execution
- make controller activation visible by surfacing the injected Super Agent banner exactly once in the first substantive reply of the session
- keep user-facing output concise by default and avoid repeating plan, validation, or closeout text when a short delta is enough

## Required lifecycle

1. Super Agent intake
2. spec registration for non-trivial change-bearing work
3. planning registration
4. specialist identification
5. execution
6. testing
7. code review
8. closeout
9. planning update

## Context Economy Protocol (always active)

This protocol is mandatory and runs automatically alongside the lifecycle above.
Full protocol, state model, CHECKPOINT format, and trigger list: `.github/instructions/context-economy-checkpoint.instructions.md`.

- Auto-compress silently when a task completes, a phase transitions, a decision is closed, topic shifts, or context grows.
- Show CHECKPOINT only on demand, at phase boundaries, or when continuity requires it.
- User commands (execute immediately; PT-BR aliases in `.github/COMMANDS.md`): `checkpoint`, `compress context`, `update plan`, `show status`, `show progress`, `resume from summary`.

## Invocation rule

- In Codex, this skill should be the first repository-owned controller for change-bearing work whenever skill discovery can match it.
- In Copilot, the same lifecycle is enforced through `instructions/super-agent.instructions.md` even though Copilot does not execute skills directly.
- In workspaces without a local adapter, stay in `global-runtime` mode: do not assume the `copilot-instructions` routing catalog or repository operating model applies to the target repo.

## Output contract

1. normalized request summary
2. clarification questions first when material ambiguity blocks safe planning
3. plan decision and active plan path
4. selected specialist chain
5. execution mode (`sequential` or `parallel-safe`)
6. validation obligations
7. closeout obligations
8. planning update instructions
9. visible activation banner surfaced once near the start of the first substantive reply
10. concise completion wording that avoids repeating earlier stage output