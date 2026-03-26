---
name: plan-active-work-planner
description: Create or update active planning documents under `planning/active`, then define the execution slices, validations, specialist handoff, and closeout expectations. Use when the task is non-trivial, multi-step, or explicitly asks for planning.
---

# Active Work Planner

## Load minimal context first

1. Load `.github/AGENTS.md`.
2. Load `.github/copilot-instructions.md`.
3. Load `.github/instruction-routing.catalog.yml`.
4. Load `.github/instructions/repository-operating-model.instructions.md`.
5. Load `.github/instructions/super-agent.instructions.md`.
6. Load `.github/instructions/subagent-planning-workflow.instructions.md`.
7. Reuse the shared `$plan-task-planner` skill for plan quality and validation discipline.

## Responsibilities

- create or update the active planning document under `planning/active/`
- preserve the normalized intake summary from the Super Agent intake stage when one exists
- keep scope, ordered tasks, validations, risks, and closeout rules explicit
- name the plan with a stable slug and reuse the same file when continuing the same workstream
- declare the recommended specialist and whether tester, reviewer, and release closeout are mandatory
- make each task worker-ready with the narrowest safe target paths, explicit commands, checkpoints, and commit checkpoint suggestions

## Output contract

1. active plan path
2. scope summary
3. ordered tasks
4. validation checklist
5. recommended specialist
6. closeout expectations for README, commit message, and changelog
7. per-task target paths, commands, checkpoints, and commit checkpoints