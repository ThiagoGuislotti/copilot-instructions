# Planning Specs Workspace
Versioned brainstorming and specification artifacts for non-trivial feature, behavior, workflow, and architecture work live here.

## Purpose
- Separate design intent from implementation planning.
- Keep approved design direction versioned before execution planning begins.
- Preserve active and completed specs as operational history.
- Prevent non-trivial work from jumping straight from intake to implementation planning without an explicit design checkpoint.

## Structure
```text
planning/
|-- README.md
|-- active/
|-- completed/
`-- specs/
    |-- README.md
    |-- active/
    `-- completed/
```

## Rules
- Create or update specs in `planning/specs/active/` for non-trivial feature, behavior, workflow, or architecture work.
- Reuse an existing active spec for the same workstream instead of creating duplicates.
- Move a spec to `planning/specs/completed/` only when the workstream is materially finished and the active plan is also ready to close.
- Do not keep umbrella roadmaps or strategic backlogs open indefinitely in `planning/specs/active/`; once no immediate execution slice is active, archive the roadmap in `planning/specs/completed/` and reopen future phases as focused active specs when work resumes.
- `planning/specs/active` and `planning/specs/completed` are created on demand and are not kept alive with placeholder files.
- Use stable slugged names such as `spec-<scope>.md`.
- Keep the spec focused on intent, decisions, alternatives, risks, and acceptance criteria. Do not turn it into the task execution plan.

## References
- `.github/instructions/super-agent.instructions.md`
- `.github/instructions/brainstorm-spec-workflow.instructions.md`
- `.github/instructions/subagent-planning-workflow.instructions.md`