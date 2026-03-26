---
applyTo: "**/*.{cs,csproj,sln,ps1,rs,toml,ts,tsx,js,jsx,vue,yml,yaml,json,jsonc,md,sql}"
priority: high
---

# Super Agent Lifecycle

## Purpose
- Normalize all change-bearing work through one Super Agent lifecycle before implementation starts.
- Ensure planning, routing, specialist selection, testing, review, closeout, and planning-state updates happen in a fixed order.
- Prevent silent skipping of skills, instructions, or validation stages.
- Provide a workspace-safe bootstrap controller that can operate in both repository-adapter mode and global-runtime mode without making external skills or unrelated repositories the source of truth.
- Keep user-facing orchestration output concise by default without hiding failures, validation state, or operator decisions.

## Scope
- Apply this lifecycle to any task that changes code, scripts, instructions, docs, runtime assets, workspace settings, pipelines, or repository governance.
- Purely informational answers with no intended file or runtime change may stay lightweight, but must still respect global routing and context rules.
- When the workspace exposes local `.github` adapter files, use the workspace-owned operating model and planning surfaces.
- When the workspace does not expose those files, stay in global-runtime mode and use `.build/super-agent/` for transient planning/spec artifacts.

## Hard Rule
- Do not jump directly from user request to implementation.
- The Super Agent flow owns intake, normalization, spec registration for non-trivial change-bearing work, planning registration, specialist selection, execution strategy, validation, closeout, and planning-state updates.
- In Codex, prefer the repo-owned `super-agent` skill as the bootstrap controller whenever skill discovery can activate it.
- In Copilot, enforce the same lifecycle through this instruction and the mandatory routing flow because Copilot does not execute local skills directly.
- Do not assume `instruction-routing.catalog.yml`, `planning/`, or `instructions/repository-operating-model.instructions.md` belong to an arbitrary client repo unless that repo actually provides them.

## Required Lifecycle
1. `Super Agent` intake
   - normalize the request
   - identify goals, constraints, risks, and whether the task is trivial or change-bearing
   - break the request into explicit work items when needed
   - ask up to 3 concise clarification questions and stop after intake when ambiguity would materially change planning scope, architecture/design, runtime behavior, validation obligations, or operational safety
2. spec registration for non-trivial change-bearing work
   - create or update the active spec under `planning/specs/active/` when the workspace provides `planning/specs/README.md`
   - otherwise create or update the transient spec under `.build/super-agent/specs/active/`
   - do not continue to planning until the active spec is planning-ready when the work is non-trivial, behavior-changing, architecture-affecting, workflow-affecting, or otherwise design-bearing
   - skip a separate spec only when the work is trivial and no design direction needs to be locked before planning
3. planning registration
   - create or update the active planning artifact under `planning/active/` when the workspace provides `planning/README.md`
   - otherwise create or update the transient planning artifact under `.build/super-agent/planning/active/`
   - reuse the existing active plan for the same workstream instead of creating duplicates
   - consume the current active spec whenever one exists
   - define expected generated outputs up front and keep non-versioned artifacts under `.build/` or `.deployment/`
4. specialist identification
   - when the workspace provides `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md`, route through that local catalog
   - otherwise build the minimal local context pack manually from the target repo structure and select the smallest correct specialist set
5. execution
   - execute sequentially by default
   - divide into multiple subagents only when work items are independent and write-scope conflicts are controlled
6. testing
   - mandatory when code, runtime behavior, scripts, validation logic, or generated artifacts changed
7. code review
   - mandatory final risk-focused review for any repository change
8. closeout
   - always produce a commit message suggestion — this step is NEVER optional
   - commit only when the user explicitly allows it or the active workflow policy authorizes it
   - CHANGELOG update: MANDATORY when the target workspace contains a CHANGELOG.md and the change is behavior-affecting, user-visible, or release-relevant; do NOT skip silently — if skipped, explicitly state why
   - README update: MANDATORY when the target workspace uses README.md as source of truth for the changed area (e.g., new features, changed commands, modified workflows, updated architecture); do NOT skip silently — if skipped, explicitly state why
   - when both CHANGELOG and README are skipped, the closeout response MUST include a one-line justification for each omission
9. planning update
   - update plan status, validation status, blockers, and completion notes
   - move the plan to `planning/completed/`only when the workstream is materially finished
   - move the spec to `planning/specs/completed/` with the same completion standard

## Delegation Rules
- Use the planner first for non-trivial work.
- Use the context optimizer only when the task spans multiple domains or the context pack contains obvious redundancy; do not trim required working context by default solely to save tokens.
- Use the tester whenever repository state changed beyond pure discussion.
- Use the reviewer before claiming completion.
- Use release closeout for commit-message and changelog output.

## Output Economy Rules
- Prefer one concise final completion summary for each stable checkpoint instead of repeating the same facts in multiple recap sections.
- Keep progress updates short and only report new information.
- Use file references and artifact paths instead of restating large plan/spec/validation content already persisted elsewhere.
- Keep planner, reviewer, and closeout summaries delta-focused; do not echo the original request or prior stage outputs when the structured fields already carry them.
- Use detailed breakdowns only on explicit user request, for blocked/failing states, or when the changed area is complex enough that a short summary would be ambiguous.
- Token economy must prioritize output brevity and duplication removal first; do not trade away execution quality by shrinking required context unless later evidence proves that safe.

## Clarification Gate
- Do not silently assume missing scope when the ambiguity would change the actual plan.
- The intake/controller layer must stop before spec or planning when it cannot proceed safely.
- Clarification questions must be concise, bounded, and only cover the unknowns that materially change:
  - planning scope or execution order
  - architecture or design direction
  - runtime/configuration behavior
  - validation criteria
  - operational safety or approval requirements
- Trivial ambiguity that does not change those factors should not trigger a clarification stop.

## Parallelization Rules
- Parallel subagents are allowed only when:
  - tasks are independent
  - file ownership/write-set boundaries are explicit
  - no shared-state race is expected
- If those conditions are not met, keep execution sequential.

## Commit Rules
- The lifecycle must always prepare a commit message when the state is stable.
- The lifecycle must never auto-commit unless the user explicitly opted in to commit execution.

## Context Boundary Monitoring

Context resets, compactions, and session boundaries are normal. The primary resilience mechanism is **the planning artifact itself** — not hooks or memory. A correctly dated plan is the only thing an agent needs to resume from any interruption.

### Planning-first continuity (primary)
- Active plans and specs under `planning/active/` and `planning/specs/active/` are the authoritative resume point.
- Every task must carry `[YYYY-MM-DD HH:mm]` dates so an agent resuming from a compacted context can determine the exact sequence and state of work without relying on session memory.
- The `LastUpdated:` field in each plan's status block must be updated on every change so the most recent plan is always identifiable by date.
- When resuming after a context reset, read the active plan first — the dates tell you what was completed, what is in progress, and what comes next.

### Handoff export (supplementary)
- Use `scripts/runtime/export-planning-summary.ps1` to generate a snapshot of active plans, specs, and recent commits when a long session must be paused deliberately.
- `pwsh -File scripts/runtime/export-planning-summary.ps1` — saves to `.temp/context-handoff-<timestamp>.md`
- `pwsh -File scripts/runtime/export-planning-summary.ps1 -PrintOnly` — prints to console

### Cleanup with automatic export
- Copilot context cleanup: `pwsh -File scripts/runtime/clean-vscode-user-runtime.ps1 -ExportPlanningSummary -Apply`
- Codex session cleanup: `pwsh -File scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -ExportPlanningSummary -Apply`
- Safe periodic housekeeping: `pwsh -File scripts/runtime/invoke-super-agent-housekeeping.ps1 -WorkspacePath . -Apply`
- `SessionStart` and `SubagentStart` dispatch the same housekeeping flow at most once every 2 hours per workspace.
- The periodic flow exports a concise planning handoff first, then cleans only persisted Codex and VS Code runtime state.
- The periodic flow does **not** clear or shrink the live active context window shown in the runtime UI.

### What "session end" means per runtime
- **Claude Code**: `Stop` hook fires on session close → exports planning summary automatically
- **Copilot / Codex**: no session-end event — continuity depends entirely on the dated planning artifact and the `SessionStart` hook injecting workspace context at the start of each new conversation

### In-session context compression and checkpoints
Context compression runs automatically — no user command required. Full protocol, six-block state model, CHECKPOINT format, compression triggers, and preserve/discard rules are defined in `instructions/context-economy-checkpoint.instructions.md`.

User commands (execute immediately; PT-BR aliases in `.github/COMMANDS.md`): `checkpoint`, `compress context`, `update plan`, `show status`, `show progress`, `resume from summary`.

## Preservation Rules
- This lifecycle augments the existing repository governance model; it does not replace it.
- Never drop existing mandatory instructions, baselines, or validations to satisfy the lifecycle.
- User instructions still take precedence over automation details.