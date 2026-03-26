# Rust Runtime Engine Foundation Phase 8 Plan

Generated: 2026-03-26 11:48
LastUpdated: 2026-03-26 11:48

## Status

- State: active
- Spec: `planning/specs/active/spec-rust-runtime-engine-foundation-phase-8.md`
- Priority: high
- Execution mode: planning-ready, awaiting Rust directives

## Objective And Scope

Start the Rust/Cargo migration on top of the now-stable repository topology:

- `definitions/` remains the authoritative source for non-executable assets
- `scripts/` remains the operator-facing wrapper layer
- `.github/.codex/.claude/.vscode` remain projected/runtime surfaces
- `src/` and `tests/` become the new executable engine and engine-test layout

This phase is limited to planning readiness and migration guardrails until the
user provides the Rust-specific directives.

In scope for this planning phase:
- define the Rust migration contract and compatibility constraints
- define the initial Cargo workspace and CLI ownership boundaries
- define the staged migration path from PowerShell wrappers to Rust-backed execution
- keep legacy PowerShell scripts working during the migration

Out of scope until user directives arrive:
- creating `Cargo.toml`
- adding Rust crates/modules
- switching any production runtime path from PowerShell to Rust
- deleting legacy scripts or projected provider surfaces

## Ordered Tasks

1. Lock the pre-Rust architecture as the baseline contract
2. Capture the Rust migration constraints, compatibility model, and fallback rules
3. Wait for user-provided Rust directives before creating any Cargo/Rust files
4. After directives, implement phase 8 in incremental slices with parity tests and PowerShell fallback wrappers

## Migration Guardrails

- Do not delete or break current PowerShell runtime/install/bootstrap flows
- Do not move authoritative content out of `definitions/`
- Keep `scripts/` as the canonical operator entrypoint layer
- Introduce Rust behind wrappers and feature-gated cutover steps only
- Require parity validation before replacing any PowerShell implementation path

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`

## Closeout Expectations

- receive explicit Rust directives from the user
- then open the first implementation slice for Cargo workspace + CLI foundation
- keep commit guidance in English