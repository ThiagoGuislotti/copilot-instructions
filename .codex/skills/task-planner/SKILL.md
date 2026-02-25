---
name: task-planner
description: Plan and sequence complex implementation work into deterministic, testable steps for this repository. Use when the user asks for planning, roadmap breakdown, execution strategy, effort estimation, or multi-step delivery coordination across domains.
---

# Task Planner

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md`.
3. Load only planning/process files plus the domain packs needed by the plan.

## Planning instruction pack

- `.github/instructions/workflow-optimization.instructions.md`
- `.github/instructions/effort-estimation-ucp.instructions.md`
- `.github/instructions/pr.instructions.md` (when output is PR-oriented)
- `.github/instructions/feedback-changelog.instructions.md` (when release/change log impact exists)

## Planning workflow

1. Define objective, constraints, assumptions, and acceptance criteria.
2. Break work into small ordered tasks with dependencies.
3. Add validation per task (build, tests, smoke checks).
4. Identify risks and fallback path for each critical task.
5. Produce an execution order that can be run incrementally.

## Output contract

1. Scope summary.
2. Ordered tasks.
3. Validation checklist.
4. Risk list and mitigation.
5. Delivery slices (POC, incremental, final).