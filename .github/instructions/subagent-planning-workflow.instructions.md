---
applyTo: "**/*.{cs,csproj,sln,ps1,rs,toml,ts,tsx,js,jsx,vue,yml,yaml,json,jsonc,md,sql}"
priority: high
---

# Sub-Agent Planning Workflow

## Purpose
- Standardize how the Super Agent lifecycle plans, routes, executes, reviews, and closes out non-trivial work with a deterministic sub-agent chain.
- Keep planning artifacts versioned under `planning/` when the workspace owns that surface, and fall back to `.build/super-agent/` when it does not.

## Planning Workspace Contract
- When the workspace provides `planning/README.md`, use it as the planning workspace guide.
- Active plans live in `planning/active/` when the workspace provides a versioned planning surface; otherwise they live in `.build/super-agent/planning/active/`.
- Finished plans move to `planning/completed/` or `.build/super-agent/planning/completed/` only when the work is genuinely complete.
- When the workspace provides `planning/specs/README.md`, use it as the versioned specification guide for brainstorming/spec artifacts.
- Active specs live in `planning/specs/active/` when the workspace provides a versioned spec surface; otherwise they live in `.build/super-agent/specs/active/`.
- Finished specs move to `planning/specs/completed/` or `.build/super-agent/specs/completed/` with the related workstream when applicable.
- Plan files should use stable slugged names such as `plan-<scope>.md`.
- Reuse and update an existing active plan when the request continues the same workstream instead of creating a duplicate file.

## Dating Policy (Mandatory)
Planning artifacts are the primary continuity mechanism across context resets, session boundaries, and agent handoffs. Dates make it safe to resume after any interruption.

- Every plan must include a `Generated: YYYY-MM-DD HH:mm` at the top.
- Every task or step entry must carry a `[YYYY-MM-DD HH:mm]` prefix when it is created, updated, or completed.
- When a task is completed, append `✓ [YYYY-MM-DD HH:mm]` — never remove the original creation timestamp.
- When a task is in progress, mark it `[YYYY-MM-DD HH:mm IN PROGRESS]`.
- When a task is blocked, append `⚠ blocked [YYYY-MM-DD HH:mm]: <reason>`.
- The plan status block must include a `LastUpdated: YYYY-MM-DD HH:mm` field updated on every change.
- A plan without timestamps on its tasks cannot be used as a reliable resume point — treat undated tasks as unverified.

Example task format:
```
Generated: 2026-03-23 09:00
LastUpdated: 2026-03-23 14:32

1. [2026-03-23 09:00] Create CLAUDE.md ✓ [2026-03-23 09:45]
2. [2026-03-23 10:10] Update install scripts ✓ [2026-03-23 11:30]
3. [2026-03-23 14:00 IN PROGRESS] Expand README coverage
4. [2026-03-23 14:32] Fix long overflow in clean-codex-runtime.ps1 ✓ [2026-03-23 14:32]
```

## When Planning Is Mandatory
Create or update an active planning document when any of these are true:
- the task is non-trivial or spans multiple files
- the task crosses more than one technical domain
- the task needs staged validation or rollout control
- the task requires sub-agent delegation or specialist routing
- the user explicitly asks for planning, roadmap, phases, or execution slices

## Iterative In-Session Directive Exception
When the user is actively directing fixes iteratively within a single session (each request is a direct correction or small follow-up to the previous step), the strict upfront spec → plan → execute order may be relaxed:
- A formal spec is not required upfront when the user is the real-time design authority for each step.
- A retroactive plan update at the END of the session is acceptable instead of blocking execution on a formal plan first.
- The retroactive plan update MUST still carry `[YYYY-MM-DD HH:mm]` completion timestamps on every task so the artifact remains a valid resume point.
- This exception applies only when:
  - the user is actively present and directing each iteration
  - no sub-agent delegation or worktree isolation is needed
  - the scope of each individual step is clear before it is executed
- When the session ends, the plan must be updated to reflect the completed work — an undated or empty plan is not an acceptable outcome even under this exception.

## Mandatory Sub-Agent Chain
For non-trivial work, prefer this execution chain unless the user explicitly asks for a lighter flow:
1. `super-agent` contract
   - normalize the request and decide whether the task is change-bearing
   - ensure spec registration happens before planning for non-trivial change-bearing work
   - ensure planning registration happens before execution
2. `brainstorm-spec-architect` agent
   - create or update a spec in `planning/specs/active/` when the workspace owns that surface, otherwise in `.build/super-agent/specs/active/`
   - do this for non-trivial change-bearing work so design direction is locked before planning
   - capture decisions, alternatives, risks, acceptance criteria, and planning readiness
3. `planner` agent
   - create or update the active plan in `planning/active/` when available, otherwise in `.build/super-agent/planning/active/`
   - consume the current active spec and require explicit planning readiness before planning starts
   - define scope, ordered tasks, validations, risks, and closeout requirements
4. `context-token-optimizer` agent, when needed
   - use it only when the task spans multiple domains or the context pack has obvious redundancy
   - recommend the correct specialist path
   - never remove required working context by default solely for token savings
5. worktree isolation decision
   - for risky, long-running, or broad-scope work, prefer `instructions/worktree-isolation.instructions.md`
   - use the repository-owned helper `scripts/runtime/new-super-agent-worktree.ps1` when isolation is warranted
6. `specialist` agent
   - perform the domain implementation using the routed context only
   - keep execution aligned with `instructions/tdd-verification.instructions.md`
7. `tester` agent
   - mandatory when code, runtime behavior, or validation scripts changed
8. `reviewer` agent
   - mandatory final risk-focused code review
9. `release-closeout` agent
   - update relevant README files when needed
   - produce suggested commit message
   - update CHANGELOG with entry-ready content when the change belongs in version history
10. planning update
   - update execution state, validation status, blockers, and closeout notes
   - move the plan to `planning/completed/` and the spec to `planning/specs/completed/` when the workspace owns those versioned folders
   - otherwise move them to `.build/super-agent/planning/completed/` and `.build/super-agent/specs/completed/` only when materially complete

## Specialist Selection Rule
- Use the smallest specialist capable of executing the task correctly.
- Prefer repository specialists such as `.NET`, `frontend`, `Rust`, `platform`, `security`, `observability`, or `privacy` over the generic engineer when the domain is clear.
- Use the generic engineer only when the task is mixed or no narrower specialist fits.

## Output Contract
Every active plan must define:
1. `Generated: YYYY-MM-DD HH:mm` at the top
2. `LastUpdated: YYYY-MM-DD HH:mm` in the status block — updated on every task change
3. objective and scope summary
4. normalized request or intake summary
5. spec path or explicit statement that a separate spec was not required
6. ordered tasks — each prefixed with `[YYYY-MM-DD HH:mm]` creation date and suffixed with `✓ [YYYY-MM-DD HH:mm]` on completion
7. per-task target paths, explicit commands, expected checkpoints, and commit checkpoint suggestion
8. validation checklist with explicit verification evidence expectations
9. risks and fallback path
10. selected specialist or specialist candidates
11. closeout expectations for README, commit message, and changelog
12. whether isolated worktree execution is recommended

## Closeout Rules
- If the change affects stable documentation, update the relevant README in the same workstream.
- Always return a suggested commit message when the work reaches a stable checkpoint.
- If the change should be retained in release history, update the changelog with entry-ready content following `instructions/feedback-changelog.instructions.md`.
- Do not move a plan to `planning/completed/` until implementation, validation, review, and closeout are all materially complete.