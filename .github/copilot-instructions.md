# Global Instructions

Language: pt-BR for chat; EN for code/commits/docs/UI/database; pt-BR i18n output.

# Enterprise-First Default
- Default quality bar is real-world enterprise standard for all tasks.
- Target the highest feasible quality level by default in planning, implementation, validation, and documentation.
- Plan and execute with high rigor in security, reliability, observability, testing, documentation, and maintainability.
- Only downgrade to lightweight/prototype mode when the user explicitly labels the request as `POC`, `spike`, or `informal test`.
- Even in POC/informal mode, keep baseline safety controls (no secrets exposure, no unsafe destructive actions).

# EOF Policy
- Preserve the exact EOF state of every edited file.
- The repository default in `.editorconfig` is `insert_final_newline = false`.
- Do not append a terminal newline when editing or creating files unless a narrower file-specific rule explicitly requires it.
- Do not leave trailing blank lines at EOF.

# Workspace Mode Detection
- `workspace-adapter` mode:
  - active when the target workspace provides local `.github/AGENTS.md` and `.github/copilot-instructions.md`
  - use workspace-owned instructions first
  - use local static routing only when `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md` also exist
  - use `planning/` when the workspace provides `planning/README.md` and `planning/specs/README.md`
- `global-runtime` mode:
  - active when the target workspace lacks that local adapter
  - use the mirrored runtime baseline under `%USERPROFILE%\\.github`
  - do not assume the runtime repository routing catalog or `instructions/repository-operating-model.instructions.md` applies to the target workspace
  - use `.build/super-agent/planning/` and `.build/super-agent/specs/` for transient orchestration artifacts when the workspace does not provide versioned planning folders

# Language Policy
- Chat/Conversation: pt-BR (Portuguese) - all responses to user in chat
- Code/Commits/Docs: EN (English) - all technical content
- UI: EN (English) keys/structure; pt-BR translations via i18n for end users
- Database: EN (English) - schema, table names, column names

# Hierarchy and Scope
- Global rules live here and are always applied.
- The Super Agent lifecycle lives in `instructions/super-agent.instructions.md` and is always applied for change-bearing work.
- The canonical non-versioned artifact layout lives in `instructions/artifact-layout.instructions.md`.
- Non-trivial design-bearing work also uses `instructions/brainstorm-spec-workflow.instructions.md` before execution planning.
- Risky execution may use `instructions/worktree-isolation.instructions.md`.
- Code-bearing work also uses `instructions/tdd-verification.instructions.md`.
- Repository-specific operating rules live in `instructions/repository-operating-model.instructions.md`.
- Domain instruction files extend these rules; do not duplicate globals.
- Prefer the most specific domain rule when conflicts occur.
- Map and reference new instruction files here.

# Context Selection

## Hard rule
- Always load `AGENTS.md` first, then this file.
- In `workspace-adapter` mode, load the workspace-owned copies first.
- In `global-runtime` mode, load the runtime copies from `%USERPROFILE%\\.github`.

# Static RAGs Routing
Preferred default workflow in `workspace-adapter` mode: **Route → Execute** (always route first to generate a minimal Context Pack).

Use static routing when you want consistent instruction selection without running any external service and the workspace actually provides a local routing surface.

Flow (two-stage):
1) Route: Use `.github/instruction-routing.catalog.yml` + `.github/prompts/route-instructions.prompt.md` to produce a Context Pack (mandatory + minimal domain files).
2) Execute: Perform the actual task using ONLY the Context Pack files as context.

Rules:
- Always include mandatory context (AGENTS.md + this file) and mandatory instruction files.
- Prefer 2–5 domain instruction files per task.
- If ambiguous, ask up to 3 clarifying questions before executing.
- In `global-runtime` mode, do not use the runtime repo routing catalog as if it belonged to the target workspace; assemble the minimal local context pack manually from the target repo files you are actually changing.

## Decision Quickstart (Instruction Hierarchy)

Follow this order of operations on every task:

1) Read the user request and identify the target area
- `.github/**` (policies, prompts, instructions)
- Code workspace (C#, Rust, TS/JS, etc.)
- Build/CI/CD/infra (pipelines, Docker, Kubernetes)

2) Apply instructions in this precedence order
- User prompt (explicit constraints)
- `AGENTS.md` + this file
- Domain instruction files under `instructions/` (pick by language/folder)
- Any additional, file-scoped instructions (e.g., `instructions/copilot-instruction-creation.instructions.md` when editing `instructions/*`)

3) Resolve conflicts
- More specific scope wins (narrower `applyTo` beats broader)
- Prefer safer/minimal changes when ambiguous, and ask 1–3 clarifying questions if needed

# Workflow

## Super Agent Lifecycle
- Treat `instructions/super-agent.instructions.md` as the mandatory controller contract for change-bearing work.
- Default lifecycle:
  1. Super Agent intake
     - ask up to 3 concise clarification questions and stop before spec/planning when ambiguity would materially change scope, architecture, runtime behavior, validation, or safety
  2. spec registration for non-trivial change-bearing work
  3. planning registration
  4. specialist identification
  5. worktree isolation when warranted
  6. execution
  7. testing
  8. code review
  9. closeout
  10. planning update
- Do not skip directly from request to implementation when files, runtime assets, or repository state are expected to change.
- When the workspace does not provide `planning/`, use `.build/super-agent/planning/` and `.build/super-agent/specs/` as the fallback orchestration roots.

## How to use
- Start with AGENTS.md for solution-specific details (stack, folders, commands).
- Use this file for global rules, precedence, and always-applied policies.
- Use `instructions/repository-operating-model.instructions.md` only when the target workspace provides a local repo adapter and repo-specific operating model.
- Follow domain-specific files in instructions/*.md for technical details.

# Authoritative Sources Policy
- Use repository context first for project-specific behavior, architecture, scripts, templates, and conventions.
- For external platform, framework, SDK, API, CLI, or tool behavior, follow `instructions/authoritative-sources.instructions.md`.
- Use `.github/governance/authoritative-source-map.json` as the single source of truth for stack-specific official documentation domains.
- Do not duplicate official domain lists across domain instruction files.

# Validation Checklist Policy
- Every non-trivial task must define a concrete validation checklist before or during implementation.
- The checklist must be scope-specific and cover only the relevant checks for the task (for example: build, tests, docs, security, migrations, runtime behavior, links, formatting).
- Final task reporting must include checklist status using `passed`, `pending`, or `blocked`.
- If a validation item cannot be executed, keep it in the checklist and state why it remained pending or blocked.

# Output Economy Policy
- Optimize token usage through shorter default responses, less repeated narration, and better reuse of retrieved local context.
- Do not optimize token usage by shrinking required execution context by default; quality and correctness take precedence over raw token reduction.
- Keep default final answers in this order when relevant:
  1. outcome
  2. changed files or affected area
  3. validation status
  4. open risks or next steps only when they exist
- Avoid repeating the same status in progress updates, final summaries, commit guidance, and closeout text.
- When repository artifacts already hold the detail, reference the artifact path and summarize only the delta instead of restating the full content.
- Keep subagent, planner, reviewer, and closeout outputs delta-focused and concise unless the user explicitly asks for the detailed version.

# Chat Session Naming and Runtime Paths
- Start each new Copilot or Codex chat by normalizing the session title to `<project-prefix> - <task summary>` as soon as the client or runtime allows it.
- The project prefix must come from the active workspace or repository name; do not omit it and do not duplicate it when the title is already prefixed.
- Prefer workspace-scoped Copilot sessions over empty-window sessions for project work so the title stays attached to the correct project scope.
- When scripting or documenting chat runtime storage, never hardcode personal absolute paths in tracked files. Use parameterized paths such as:
  - `"%USERPROFILE%\\.codex\\session_index.jsonl"`
  - `"%APPDATA%\\Code\\User\\workspaceStorage\\<workspace-id>\\chatSessions\\*.json"`
  - `"%APPDATA%\\Code\\User\\workspaceStorage\\<workspace-id>\\chatSessions\\*.jsonl"`
  - `"%APPDATA%\\Code\\User\\globalStorage\\emptyWindowChatSessions\\*.json"`
  - `"%APPDATA%\\Code\\User\\globalStorage\\emptyWindowChatSessions\\*.jsonl"`
- If Copilot session titles need bulk normalization, use `scripts/runtime/update-copilot-chat-titles.ps1` instead of editing unrelated session payload fields by hand.

# Mandatory Instructions

## Always Applied
- AGENTS.md (agents and context policy)
- instructions/super-agent.instructions.md
- instructions/brainstorm-spec-workflow.instructions.md
- instructions/artifact-layout.instructions.md
- instructions/subagent-planning-workflow.instructions.md
- instructions/worktree-isolation.instructions.md
- instructions/tdd-verification.instructions.md
- instructions/authoritative-sources.instructions.md
- instructions/workflow-optimization.instructions.md
- instructions/powershell-execution.instructions.md
- instructions/feedback-changelog.instructions.md

## Only for Workspace-Adapter Mode
- instructions/repository-operating-model.instructions.md

## Only for .github Changes
- instructions/copilot-instruction-creation.instructions.md

# Repository and Domain Rules
- In `workspace-adapter` mode, repo topology, build/test/run commands, style, security/changelog process, and the full domain instruction map live in `instructions/repository-operating-model.instructions.md`.
- In `global-runtime` mode, infer repo topology and local commands from the target workspace itself; do not import the `copilot-instructions` repo topology into an unrelated client repository.
- Change-bearing work must start with `instructions/super-agent.instructions.md` before planning and implementation.
- Non-trivial tasks must also follow `instructions/subagent-planning-workflow.instructions.md` and the workspace planning surface under `planning/` when it exists, otherwise the fallback under `.build/super-agent/`.
- When the work is non-trivial and design-bearing, create or update a spec under `planning/specs/` when available, otherwise under `.build/super-agent/specs/`, and do not continue to planning until that spec is planning-ready.
- Use domain instructions from that map according to the active route and file scope.
- For generated build or deployment outputs, use `.build/` and `.deployment/` according to `instructions/artifact-layout.instructions.md`.

# Transparency

## Pragmatic use
- List applied instructions only when there are relevant actions (plans, command executions, patches/file changes).
- Use a short preamble to indicate key instructions before tool/command calls; omit in purely informational answers.
- When the Super Agent bootstrap is active, the first substantive reply in the session should expose the activation banner injected by the hook exactly once near the start.
- In every substantive terminal-facing completion message, include a short final `Agents used:` line that lists the controller and any specialists or subagents actually used for the task.
- Format each reported agent name in backticks, for example: `Agents used: `Super Agent``.
- When no specialist or delegated subagent was used, state that explicitly in the same line instead of omitting it.
- For auditing, consolidate the full list of instructions in PR/commit body or CHANGELOG.md.
- When requested, include an Applied instructions section with the actually used set.
- After finishing a logically complete item, return a suggested commit message in English using semantic commit prefixes such as `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`, `build:`, or `ci:`.
- When the current state is stable and ready for persistence, explicitly tell the user that the work is ready to commit.
- For large tasks, surface stable intermediate commit checkpoints as soon as they are reached.

# Repository Style, Security, and Release
- Follow `instructions/repository-operating-model.instructions.md` for style, EOF policy, security handling, commit/PR expectations, and changelog rules.