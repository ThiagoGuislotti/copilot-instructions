---
applyTo: ".github/**/*.*"
priority: high
---

# Task Breakdown
Split large tasks into manageable steps; avoid hard token limits; split by functional domain when possible.

# Planning and Routing
- For non-trivial work, route first and then follow `instructions/subagent-planning-workflow.instructions.md`.
- Treat `planning/README.md`, `planning/active/`, and `planning/completed/` as the versioned planning workspace.
- Keep the context pack minimal, but do not omit mandatory instruction files or the planning workflow when the task needs staging.

# Prioritization
- Critical config changes first
- Core validation logic second
- Template updates third
- Docs fourth
- Validation tests last
- Respect logical dependencies

# Separation of Concerns
Keep single instruction files concise; group related files by domain; handle cross-cutting changes by layer (config, validation, templates); implement new features in phases (creation, integration, testing).

# Context Preservation
Include relevant context gathering; avoid repeating already provided information; focus on requested specific changes; use targeted file searches when necessary.

# Token Efficiency
- Avoid reproducing entire files
- Use comments to represent existing code when allowed
- Focus on minimal diffs
- Consolidate related changes
- Separate independent concerns
- Eliminate redundancies
- Never repeat provided context
- Focus exclusively on deltas
- Minimal examples
- Prioritize clarity over verbosity
- Target duplicated output and repeated narration before attempting any input/context reduction
- Never cut required working context by default just to save tokens; do that only with explicit proof that quality is preserved

## Context Economy and Checkpoint
Full protocol, compression triggers, six-block state model, CHECKPOINT format, and user commands: `instructions/context-economy-checkpoint.instructions.md`.

User commands: `checkpoint`, `compress context`, `update plan`, `show status`, `show progress`, `resume from summary` (PT-BR aliases in `.github/COMMANDS.md`).

# Workspace Awareness
Consider current workspace traits; apply appropriate architectural patterns when relevant; keep consistency with existing patterns; adapt approach to present technologies.

# Execution Style
Maximum token efficiency; be concise and direct; avoid verbosity; prioritize actions and code; keep clarity as requirement.

# Workflow Optimization
Cache dependencies; parallel jobs; conditional steps; reusable workflows; matrix builds for multiple target frameworks.
```yaml
# GitHub Actions matrix example
strategy:
  matrix:
    dotnet-version: ['8.0', '9.0']
    os: [ubuntu-latest, windows-latest]
```

# Response Structure
Use shortest preambles before commands/tools; use minimal plans for non-trivial tasks; avoid unnecessary text; focus on essential output only.
- Prefer a single concise final summary over multiple overlapping recap sections.
- Do not restate plan text, validation output, or retrieved repository context when a short delta plus file references is sufficient.
- Keep progress updates short and avoid re-reporting the same status in the final completion message.

# Confirmation
Use concise completion cues when appropriate; keep confirmations minimal and aligned with structured answer guidelines.

# Context Awareness
Reference files/paths precisely; include commands only when executing; assume user knowledge of workspace.

# Maximum Economy
Respond with simplest possible form; direct tool calls; minimal explanatory text; prioritize token conservation over elaboration.

# Compatibility
Respect sandbox and approval policies; align with agent format including minimal preambles and structured answers.