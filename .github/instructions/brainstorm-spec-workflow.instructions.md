---
applyTo: "**/*.{cs,csproj,sln,ps1,rs,toml,ts,tsx,js,jsx,vue,yml,yaml,json,jsonc,md,sql}"
priority: high
---
# Brainstorming And Specification Workflow
## Purpose
- Introduce a brainstorming and specification step before implementation planning for non-trivial change-bearing work.
- Keep design intent, alternatives, risks, and acceptance criteria versioned separately from execution plans.
- Prevent implementation planning from becoming the first place where architectural decisions are made.

## When A Spec Is Mandatory
Create or update a spec under `planning/specs/active/` when the workspace provides that surface, otherwise under `.build/super-agent/specs/active/`, when any of these are true:
- the task introduces or changes behavior, architecture, workflow, or feature scope
- the task is non-trivial and planning is already required
- the task spans multiple work items and design tradeoffs must be documented first
- the request changes orchestration, runtime behavior, governance flow, or user-facing workflows
- the request is ambiguous enough that alternatives or explicit design decisions are needed before implementation planning

## When A Spec Can Be Skipped
A separate spec is usually not required when all of these are true:
- the work is trivial and tightly scoped
- the task is maintenance-only, doc-only, title-only, or configuration-only
- there is no meaningful design tradeoff to lock down before planning

## Spec Workspace Contract
- Use `planning/specs/README.md` as the guide for versioned specs when the workspace provides it.
- Active specs live in `planning/specs/active/` when the workspace provides a versioned spec surface; otherwise they live in `.build/super-agent/specs/active/`.
- Completed specs move to `planning/specs/completed/` or `.build/super-agent/specs/completed/` only when the associated workstream is materially finished.
- Reuse the same spec file for the same workstream instead of creating duplicates.
- Use stable names such as `spec-<scope>.md`.

## Dating Policy (Mandatory)
- Every spec must include `Generated: YYYY-MM-DD HH:mm` at the top.
- Every key decision, alternative, or assumption added after creation must carry a `[YYYY-MM-DD HH:mm]` prefix.
- When planning readiness changes (e.g., spec updated after new information), append `Updated: YYYY-MM-DD HH:mm — <reason>` to the planning readiness statement.
- Dates allow agents resuming from a compacted context to read the spec and understand exactly when each design decision was made and whether it is still current.

## Required Spec Content
Each active spec must capture:
1. `Generated: YYYY-MM-DD HH:mm`
2. objective
3. normalized request summary
4. design summary
5. key decisions — each prefixed with `[YYYY-MM-DD HH:mm]`
6. alternatives considered
7. assumptions and constraints
8. risks
9. acceptance criteria
10. planning readiness statement (with `Updated: YYYY-MM-DD HH:mm` if revised)
11. recommended specialist focus when it is already clear

## Relationship To Planning
- A spec does not replace the active plan.
- The spec locks down intent and design direction.
- The active plan under `planning/active/` or `.build/super-agent/planning/active/` translates the approved spec into ordered execution tasks, validation steps, routing, and closeout expectations.
- For non-trivial change-bearing work, planning must consume the current active spec before generating or updating the active plan.
- Do not generate or update the active plan for non-trivial change-bearing work until the active spec exists and its planning readiness statement is explicit.

## Closeout Rule
- When a workstream is materially complete, move both the active plan and the active spec to their completed locations together when applicable.
- Do not leave completed design artifacts stranded in `planning/specs/active/` or `.build/super-agent/specs/active/`.