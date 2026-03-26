# Runtime Source/Projection Architecture Migration

Generated: 2026-03-25

## Objective

Define and phase in a durable repository topology that separates authoritative authored content from projected provider/runtime surfaces, while preserving the current runtime contracts for `.github`, `.codex`, `.claude`, and `.vscode`.

## Problem Statement

The repository currently mixes authored content, rendered provider surfaces, and executable operational logic across several top-level folders. This creates drift, duplicated policy, and unclear ownership. The repository has now consolidated the first architecture slice under `definitions/`, and the documented target model is ready to host a later Rust/Cargo engine cleanly without another topology rewrite.

## Design Summary

The repository should converge on four roles:

1. `definitions/`
- authoritative non-code authored content
- instructions, skills, templates, provider-authored adapters, MCP catalogs, and VS Code profile definitions

2. `src/`
- executable engine code only
- future render/index/query/sync internals, likely the first Rust/Cargo adoption surface

3. `tests/`
- tests for the engine layer and deterministic render/parity validation
- unit, integration, and fixture/golden coverage

4. `scripts/`
- stable operator-facing wrapper layer
- install/bootstrap/healthcheck/sync commands remain here even if they later delegate to binaries from `src/`

Top-level provider/runtime folders remain in place:
- `.github`
- `.codex`
- `.claude`
- `.vscode`

These remain projected/runtime surfaces because external tools expect them at fixed paths. In the completed phase-1 architecture they stay operational and are not deleted or deprecated until parity and operator ergonomics are proven over time.

## Architecture Principles

1. One authoritative source per artifact type.
2. Projected surfaces must be renderable deterministically from authored definitions.
3. Executable logic belongs under `scripts/` now and under `src/` later; not inside provider folders.
4. Rust/Cargo is a later implementation detail, not the driver of the topology.
5. The topology must remain legible to contributors using common market conventions.

## Decisions

1. `definitions/` is preferred over `source/` for authored non-code assets because it communicates ownership more clearly.
2. `src/` is reserved for code, not content.
3. `tests/` should be introduced now as a contract even if the future engine remains small at first.
4. `.codex`, `.claude`, `.github`, and `.vscode` stay as projected surfaces through the migration.
5. PowerShell remains the execution wrapper technology until the architecture stabilizes; Rust/Cargo is deferred.

## Alternatives Considered

### Keep using `source/`

Rejected as the long-term name because it is too generic and does not clearly distinguish authored definitions from executable code.

### Put everything under `src/`

Rejected because it would again mix authored content with executable logic and would make future provider/runtime projections harder to reason about.

### Rewrite install/bootstrap into Rust immediately

Rejected because the current problem is topology and authority, not runtime performance of the wrappers.

## Acceptance Criteria

1. A migration workstream exists that defines the authoritative vs projected model explicitly.
2. The repository has a documented target naming model of `definitions/ + src/ + tests/ + scripts/ + projected provider surfaces`.
3. The early migration phases explicitly forbid deleting `.github/.codex/.claude/.vscode`.
4. The future Rust/Cargo adoption point is documented as a later phase after topology stabilization.
5. The first implementation slice completed by consolidating the temporary `source/` concept into `definitions/` without changing external runtime behavior.

## Risks

- Partial migration could leave mixed naming (`source/` and `definitions/`) longer than intended.
- Over-eager cleanup of projected surfaces could break runtime expectations.
- Moving too fast toward Rust could increase complexity before the topology is stable.

## Mitigations

- Keep the migration phased and non-destructive.
- Add render/parity validation before each surface is declared projected-only.
- Preserve `scripts/` as the stable operator interface through the transition.

## Planning Readiness

ready-for-plan