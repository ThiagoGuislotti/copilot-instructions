# Shared POML Library Boundary Phase 7 Plan

Generated: 2026-03-26 11:16
LastUpdated: 2026-03-26 11:16

## Status

- State: completed
- Spec: `planning/specs/completed/spec-shared-poml-library-boundary-phase-7.md`
- Priority: high
- Execution mode: final pre-Rust boundary cleanup

## Objective And Scope

Move the reusable POML library out of `definitions/providers/github/prompts/poml/`
into a shared authoritative location before the Rust phase starts, while keeping
`.github/prompts/poml/` as the projected runtime/editor surface.

In scope for this phase:
- create `definitions/shared/prompts/poml/` as the authoritative shared POML library
- move the authored POML guide, styles, templates, and fixtures out of
  `definitions/providers/github/prompts/poml/`
- keep GitHub provider prompts limited to provider-specific prompt entrypoints
- update the GitHub renderer so `.github/prompts/poml/` is rendered from the shared tree
- update docs, validation, tests, and projection metadata

Out of scope:
- Rust/Cargo implementation
- restructuring provider-specific prompt entrypoints such as `route-instructions.prompt.md`
- refactoring Codex orchestration prompts

## Ordered Tasks

1. Register the phase-7 plan/spec and define the shared POML authority model
2. Create `definitions/shared/prompts/poml/` and move the authored POML assets into it
3. Update the GitHub renderer/catalog/docs/tests so `.github/prompts/poml/` projects from the shared POML library
4. Remove duplicate provider-owned POML copies from `definitions/providers/github/prompts/poml/`
5. Run validation and confirm the repository is fully ready for the Rust phase

## Outcome

- `definitions/shared/prompts/poml/` is now the authoritative shared POML library
- `definitions/providers/github/prompts/` now contains provider-specific prompt entrypoints only
- `.github/prompts/poml/` remains the projected runtime/editor surface
- validation passed and the pre-Rust folder-boundary cleanup is complete

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/runtime/render-github-instruction-surfaces.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Closeout Expectations

- confirm whether this is the last required folder-boundary cleanup before Rust
- keep commit guidance in English
- do not start Cargo/Rust implementation in this phase