# Rust Runtime Engine Foundation Phase 8

Generated: 2026-03-26

## Objective

Define the safe migration contract for introducing a Rust/Cargo engine into the
repository without disturbing the now-stable source/projection architecture.

## Baseline Architecture

Current authoritative model:

- `definitions/` -> non-executable authoritative content
- `scripts/` -> operator-facing runtime/install/bootstrap/sync wrappers
- `.github/.codex/.claude/.vscode` -> projected/runtime surfaces
- `src/` -> reserved executable engine space
- `tests/` -> reserved engine-oriented test space

## Design Summary

The Rust migration must follow a compatibility-first approach:

1. keep PowerShell as the current production wrapper layer
2. introduce Rust under `src/` as the new execution engine
3. route wrappers in `scripts/` to Rust only after parity is proven
4. preserve legacy PowerShell implementations until cutover is explicitly complete

## Initial Target Areas

Candidate first Rust ownership areas after directives:

- CLI bootstrap surface
- renderer dispatch engine
- projection parity engine
- local context index engine
- future query/index subcommands

Not first targets:

- Git hook installation
- full install orchestration
- destructive cleanup flows
- direct provider runtime mutation without wrapper fallback

## Acceptance Criteria

1. The repository has an explicit Rust migration contract before implementation begins.
2. No Rust implementation starts before user directives are supplied.
3. The staged migration keeps `scripts/` as the stable operator surface.
4. The eventual Cargo workspace is introduced without breaking current validations or runtime install flows.

## Planning Readiness

ready-for-plan