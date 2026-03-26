# Super Agent Unified Starter And Copilot Native Surface

## Objective

Unify the repository-owned Super Agent startup surface into a single visible controller, harden the lifecycle so non-trivial work requires `spec -> plan`, and add native GitHub Copilot surfaces without regressing the existing Codex/VS Code runtime behavior.

## Normalized Request Summary

The user wants the current Super Agent workflow strengthened and simplified. The requested outcome is:

- one visible starter instead of multiple overlapping starters
- mandatory spec-first flow for non-trivial change-bearing work
- native Copilot access, not only Codex/runtime hook access

## Design Summary

The visible entrypoint becomes `super-agent` only. The removed `using-super-agent` alias is not replaced by another visible starter. The runtime keeps selector-based override support through the existing hook selector, so alternate controllers remain possible without requiring a second fixed starter in source control.

Native Copilot support is added in two ways:

- repository-owned Copilot skill under `.github/skills/super-agent/SKILL.md`
- repository-owned Copilot agent profile under `.github/agents/super-agent.agent.md`

To support global runtime behavior, bootstrap also syncs `.github/skills` into `~/.copilot/skills`.

## Key Decisions

1. Keep `super-agent` as the single visible starter/controller in `.agents/skills`.
2. Remove `using-super-agent` from the repository-managed skill set.
3. Require spec registration before planning for non-trivial change-bearing work.
4. Add Copilot-native surfaces while preserving the lightweight hook-based activation model.
5. Extend runtime bootstrap, doctor, healthcheck, install, self-heal, and audit export to understand `~/.copilot/skills`.

## Alternatives Considered

1. Keep both `using-super-agent` and `super-agent`
   - rejected because it preserves picker ambiguity
2. Add Copilot-native files only in the repo and skip runtime sync
   - rejected because it would not support the shared global-runtime use case
3. Reintroduce heavier prompt-level hook reinforcement
   - rejected because it increases overhead and conflicts with the lighter activation model already chosen

## Assumptions And Constraints

- Existing selector-based hook overrides must remain functional.
- Existing runtime doctor/healthcheck surfaces should continue to describe all managed runtime targets.
- Historical completed planning artifacts can remain untouched even if they mention the removed starter alias.

## Risks

- Removing `using-super-agent` can break tests or docs that still reference it.
- Adding a new runtime target can leave install/doctor/self-heal inconsistent if not propagated everywhere.
- Strengthening the lifecycle can create instruction drift if only one instruction file is updated.

## Acceptance Criteria

1. Only `super-agent` remains as the repository-managed visible starter/controller.
2. Non-trivial change-bearing work is documented as `spec -> plan -> execution`.
3. `.github/skills/super-agent/SKILL.md` exists.
4. `.github/agents/super-agent.agent.md` exists.
5. Bootstrap syncs `.github/skills` into `~/.copilot/skills`.
6. Runtime tests and hook tests pass with the new single-starter model.

## Planning Readiness Statement

Planning is ready. The implementation can proceed as a single workstream covering skill consolidation, lifecycle hardening, runtime sync expansion, documentation, and validation.

## Outcome

Implemented as designed:

- `super-agent` is now the only repository-managed visible starter/controller.
- `using-super-agent` was removed from the versioned skill set.
- native Copilot surfaces now exist under `.github/skills/super-agent/` and `.github/agents/`.
- runtime sync now projects `.github/skills` into `%USERPROFILE%\\.copilot\\skills`.
- non-trivial change-bearing work now requires a planning-ready spec before planning.