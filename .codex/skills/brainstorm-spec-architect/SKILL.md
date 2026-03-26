---
name: brainstorm-spec-architect
description: Use for non-trivial feature, behavior, workflow, or architecture work before execution planning. Create or update a versioned spec under planning/specs/active with design intent, alternatives, risks, acceptance criteria, and planning readiness.
---
# Brainstorm Spec Architect
## Load minimal context first
1. Load .github/AGENTS.md.
2. Load .github/copilot-instructions.md.
3. Load .github/instruction-routing.catalog.yml.
4. Load .github/instructions/repository-operating-model.instructions.md.
5. Load .github/instructions/super-agent.instructions.md.
6. Load .github/instructions/brainstorm-spec-workflow.instructions.md.
7. Load .github/instructions/subagent-planning-workflow.instructions.md.
8. Load planning/specs/README.md.
9. Reuse $plan-active-work-planner after the spec is ready for planning.
## Responsibilities
- decide whether a separate spec is required for the current workstream
- create or update the versioned active spec under planning/specs/active/
- preserve the normalized intake summary from the Super Agent intake stage when available
- record design intent, decisions, alternatives, constraints, risks, and acceptance criteria
- state whether the workstream is ready to move into execution planning
- recommend the likely specialist path when that can already be determined
## Output contract
1. spec requirement decision
2. active spec path
3. design summary
4. key decisions
5. alternatives considered
6. acceptance criteria
7. planning readiness
8. recommended specialist focus