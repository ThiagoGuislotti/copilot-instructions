# Spec: Super Agent Universal Workspace Mode

## Objective

Make the repository-owned `Super Agent` usable as a real startup controller in any VS Code workspace, not only in `copilot-instructions`, while preserving the richer repository adapter behavior when a workspace provides its own `.github` instruction surface.

## Normalized Request Summary

- The current Super Agent bootstrap behaves well inside `copilot-instructions` but does not generalize cleanly to arbitrary client repositories.
- The user wants `Super Agent` to remain the default controller and to manage subagents in any repository.
- The runtime must stop assuming the target workspace uses the `copilot-instructions` planning, routing, and closeout layout.

## Design Summary

Adopt a two-mode startup model:

1. `workspace-adapter` mode
   - activated when the workspace provides `.github/AGENTS.md` and `.github/copilot-instructions.md`
   - uses workspace-owned instructions first
   - uses workspace routing when `instruction-routing.catalog.yml` and `prompts/route-instructions.prompt.md` are present
   - uses versioned planning/spec folders when `planning/README.md` and `planning/specs/README.md` exist
2. `global-runtime` mode
   - activated when the workspace does not provide the repository adapter files
   - uses the mirrored runtime instructions under `~/.github`
   - avoids the runtime repository static routing catalog for unrelated repositories
   - falls back to non-versioned orchestration artifacts under `.build/super-agent/`
   - keeps closeout generic: commit message always, README/CHANGELOG only when present and relevant

## Key Decisions

1. Keep `Super Agent` as the default selected startup controller through the existing selector contract.
2. Detect workspace mode dynamically inside the hook helper layer instead of forcing per-repo configuration.
3. Use `.build/super-agent/planning/...` and `.build/super-agent/specs/...` as the universal fallback orchestration workspace in global mode.
4. Treat workspace-owned `.github` instructions as the adapter boundary; when absent, the runtime baseline must avoid assuming `copilot-instructions` repository conventions.
5. Keep `trim-trailing-blank-lines.ps1` manual only; universal mode must not rely on cleanup scripts.

## Alternatives Considered

### Alternative 1: Keep repo-first behavior and document the limitation
- Rejected because it does not satisfy the user requirement that `Super Agent` be universal.

### Alternative 2: Require every client repo to install a `.github` adapter before using Super Agent
- Rejected because the startup controller would still not work out of the box in arbitrary repositories.

### Alternative 3: Make the runtime global instructions fully repo-agnostic and drop workspace adapters
- Rejected because it would degrade the richer, repository-owned lifecycle inside `copilot-instructions` and any future repo that provides a local adapter.

## Assumptions And Constraints

- VS Code hooks can bootstrap context but cannot force skill execution with absolute guarantees.
- The universal solution must therefore improve deterministic context and workflow hints, not promise impossible platform behavior.
- The runtime baseline under `~/.github` is still the only portable instruction surface available when a workspace lacks local `.github` files.
- The target repository may not want versioned planning artifacts committed; `.build/super-agent/` is the safe fallback.

## Risks

1. Global runtime instructions may still carry hidden repo-specific assumptions if not fully split by mode.
2. The fallback `.build/super-agent/` layout could surprise users if the workspace already has another planning convention.
3. Overly verbose bootstrap context could reduce adherence if the message becomes too heavy.

## Acceptance Criteria

1. SessionStart and SubagentStart clearly distinguish `workspace-adapter` and `global-runtime` modes.
2. In a workspace without local `.github` files, bootstrap context must not instruct the agent to use `copilot-instructions` static routing or `planning/` paths.
3. In a workspace with local adapter files, bootstrap context must still prefer workspace-owned instructions and planning paths.
4. The runtime `Super Agent` and `Using Super Agent` skills must describe universal behavior, including the `.build/super-agent/` fallback.
5. Hook/runtime tests must cover both modes.
6. Validation must pass through `validate-agent-hooks`, relevant runtime tests, and `validate-all`.

## Planning Readiness

Ready for execution planning.

## Recommended Specialist Focus

- hook/runtime orchestration
- instruction architecture
- runtime skill bootstrap