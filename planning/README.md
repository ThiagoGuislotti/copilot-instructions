# Planning Workspace

Versioned planning artifacts for non-trivial work live here. This folder is part of the repository operating model, not disposable temporary state.

## Purpose

- Keep active plans visible and searchable.
- Preserve completed plans as operational history.
- Support the mandatory sub-agent chain for non-trivial work.
- Separate stable planning assets from transient runtime artifacts under `.temp/`.

## Structure

```text
planning/
├─ README.md
├─ active/
├─ completed/
└─ specs/
   ├─ README.md
   ├─ active/
   └─ completed/
```

## Rules

- Create or update active plans in `planning/active/`.
- Move a plan to `planning/completed/` only after implementation, validation, review, and closeout are materially complete.
- Create or update versioned specs in `planning/specs/active/` when non-trivial work needs design decisions locked before planning.
- Move specs to `planning/specs/completed/` together with their workstream when the associated plan is materially complete.
- `planning/active`, `planning/completed`, `planning/specs/active`, and `planning/specs/completed` are created on demand and are not kept alive with placeholder files.
- Reuse an existing active plan for the same workstream instead of creating duplicates.
- Use stable slugged names such as `plan-<scope>.md` when creating new plans.
- Keep transient run outputs, smoke artifacts, and execution scratch data in `.temp/`, not here.

## References

- `.github/instructions/super-agent.instructions.md`
- `.github/instructions/brainstorm-spec-workflow.instructions.md`
- `.github/instructions/subagent-planning-workflow.instructions.md`
- `.github/instructions/repository-operating-model.instructions.md`