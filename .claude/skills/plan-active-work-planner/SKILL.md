---
name: plan-active-work-planner
description: Creates or updates the active planning artifact under planning/active/ for any change-bearing workstream. Consumes the active spec when one exists. Defines ordered tasks, target paths, commands, and checkpoints.
---

# Plan Active Work Planner

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/super-agent.instructions.md`
4. `.github/instructions/subagent-planning-workflow.instructions.md`
5. `planning/README.md`
6. Active spec from `planning/specs/active/` when one exists

## Claude-native execution

- Use `EnterPlanMode` before creating or editing plans.
- Run as a `Plan` agent within the Super Agent pipeline.

## Responsibilities

- Create or update the active plan under `planning/active/`.
- Reuse the existing active plan for the same workstream instead of creating duplicates.
- Consume and reference the current active spec.
- Define ordered tasks with target paths, explicit commands, and checkpoints.
- Identify expected generated outputs; keep non-versioned artifacts under `.build/` or `.temp/`.

## Output contract

1. Plan path
2. Ordered task list with target paths
3. Validation commands per task
4. Checkpoints
5. Planning readiness confirmation