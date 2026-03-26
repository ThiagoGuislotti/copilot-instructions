# Runtime Source/Projection Architecture Migration Plan

Generated: 2026-03-25 18:20
LastUpdated: 2026-03-25 19:43

## Status

- State: completed
- Spec: `planning/specs/completed/spec-runtime-source-projection-architecture-migration.md`
- Priority: high
- Execution mode: phased migration with runtime parity preserved

## Objective And Scope

Introduce a stable repository architecture that separates authoritative authored content from rendered runtime/provider surfaces without breaking the current `.github`, `.codex`, `.claude`, or `.vscode` contracts.

The target model is:
- `definitions/` for authoritative non-code artifacts
- `src/` for future executable engine code
- `tests/` for engine/render/integration coverage
- `scripts/` for operator-facing wrappers and install/bootstrap entrypoints
- `.github`, `.codex`, `.claude`, `.vscode` kept as projected/runtime surfaces

This workstream kept the existing projected surfaces intact while organization, render parity, and source-of-truth rules were established first. Rust/Cargo adoption remains explicitly deferred until the architecture is stable and the content/runtime separation is proven.

## Normalized Request Summary

The user wants to stop the repository from drifting into a mixed topology where provider folders contain both authored content and operational logic. They want a market-recognizable structure that can later host a Rust/Cargo engine cleanly, but they do not want an immediate rewrite or destructive cleanup of `.codex`, `.claude`, `.github`, or `.vscode`. The repository has now adopted `definitions/` as the durable authoritative name for non-code assets, and the remaining work is to extend that model consistently without breaking current runtime surfaces.

## Target Architecture

### Authoritative Trees

- `definitions/`
  - shared instructions, skills, templates, MCP catalogs, VS Code profile definitions, and provider-specific authored surfaces
- `src/`
  - future Rust or other executable engine code for rendering, indexing, sync, and query logic
- `tests/`
  - unit, integration, fixtures, and parity/golden tests for the engine layer

### Projected Runtime Trees

- `.github/`
- `.codex/`
- `.claude/`
- `.vscode/`

These remain required top-level surfaces because external tools expect them in place. They become render targets and runtime adapters, not primary authoring locations.

### Execution Layer

- `scripts/`
  - remains the only operator-facing execution surface during the migration
  - continues to own install, bootstrap, healthcheck, sync, and wrapper commands
  - may call a future Rust/Cargo engine under `src/` once the engine exists

## Key Decisions

1. Do not move to Rust/Cargo yet; first stabilize content topology and render contracts.
2. Do not delete `.github`, `.codex`, `.claude`, or `.vscode` in the organization phase.
3. Consolidate the temporary `source/` concept into `definitions/` as the durable source-of-truth name.
4. Keep `src/` reserved for executable engine code only; do not store `SKILL.md`, instructions, templates, or profile JSON there.
5. Keep `tests/` aligned with the future engine layer instead of spreading new framework-specific tests arbitrarily.
6. `scripts/` remains the stable CLI/interface layer even after Rust arrives.
7. Rendering/parity validation must exist before any provider/runtime surface is declared non-authoritative.

## Ordered Tasks

1. Establish the structural migration baseline
   - create the dedicated plan/spec workstream
   - scaffold `src/README.md` and `tests/README.md` as reserved engine roots without moving projected surfaces yet
   - document the target architecture and non-destructive migration rules
   - validation:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`

2. Replace the temporary `source/` naming with `definitions/` ✓ completed
   - migrated the current provider skill source tree from `source/providers/**` to `definitions/providers/**`
   - updated renderers, tests, docs, and validators
   - preserved projected `.codex/.claude` outputs unchanged in behavior

3. Introduce `src/` and `tests/` as reserved engine roots ✓ completed
   - add the directories with README-level contracts
   - move only code that is truly engine-oriented when ready
   - keep PowerShell wrappers in `scripts/`

4. Expand authoritative content separation ✓ completed for phase 1
   - consolidate provider-authored skills under `definitions/`
   - add GitHub instruction/runtime surfaces and VS Code profile baselines under `definitions/providers/**`
   - keep provider-facing runtime projection folders in place while parity validation is added

5. Prepare future Rust/Cargo adoption
   - document the first acceptable Rust engine candidates:
     - local context indexing
     - chunking/query engine
     - renderer/parity engine
   - keep install/bootstrap on PowerShell wrappers until the engine is stable

## Constraints

- No destructive deletion of provider/runtime folders in this workstream’s early phases.
- No switch to Rust/Cargo before the content/runtime separation is complete enough to justify an engine.
- No direct provider drift: any new authoritative source introduced must have parity validation for projected outputs.

## Validation Strategy

- planning structure must remain valid at every checkpoint
- renderer parity checks must pass for any migrated authoritative tree
- runtime tests and full install must continue to pass whenever runtime sync/bootstrap behavior changes

## Exit Criteria

- `definitions/` is the clear authoritative home for non-code authored runtime content, including provider skill surfaces, GitHub instruction/runtime surfaces, and VS Code profile baselines
- `src/` and `tests/` exist with explicit contracts
- provider/runtime folders remain stable projected surfaces
- the repository is ready for a later Rust/Cargo engine without another topology rewrite