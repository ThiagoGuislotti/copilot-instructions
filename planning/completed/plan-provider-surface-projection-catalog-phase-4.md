# Provider Surface Projection Catalog Phase 4 Plan

Generated: 2026-03-26 15:40
LastUpdated: 2026-03-26 17:18

## Status

- State: completed
- Spec: `planning/specs/completed/spec-provider-surface-projection-catalog-phase-4.md`
- Priority: high
- Execution mode: non-destructive architecture consolidation

## Objective And Scope

Introduce a canonical repository-owned catalog for projected provider surfaces so bootstrap, validation, and documentation stop hardcoding the same surface map in multiple places.

In scope for this phase:
- canonical provider-surface projection catalog under `.github/governance/`
- schema for the catalog under `.github/schemas/`
- shared helper(s) to read and query the catalog
- runtime renderer/inspection entrypoint(s) that can execute or summarize the catalog
- bootstrap migration from hardcoded renderer calls to catalog-driven dispatch where safe
- validation migration from hardcoded surface expectations to catalog-driven checks where safe
- README/docs updates describing the authoritative catalog
- tests for the catalog-driven surface contract

Out of scope:
- Rust/Cargo migration
- broad repository cleanup
- moving GitHub-native governance assets into `definitions/`
- changing the intentional generated MCP exceptions (`.vscode/mcp.tamplate.jsonc`, `.vscode/mcp-vscode-global.json`, `.codex/mcp/servers.manifest.json`)

## Normalized Request Summary

The repository already uses `definitions/` as the source of truth for most projected provider/runtime surfaces, but the mapping still appears in several hardcoded places: bootstrap, README files, and `validate-instructions.ps1`. The safe next step is to add one canonical projection catalog and consume it from the runtime/validation/docs layer without changing external runtime paths.

## Ordered Tasks

1. Register the phase-4 plan/spec and define the catalog contract for projected provider surfaces and intentional generated exceptions
2. Add a canonical provider-surface projection catalog plus schema and shared PowerShell helpers
3. Add a catalog-driven runtime entrypoint to summarize and optionally render known provider surfaces through existing renderers
4. Migrate bootstrap to use the catalog-driven dispatcher instead of a fixed renderer list where safe
5. Migrate validation to derive required/provider-surface parity checks from the catalog instead of duplicated hardcoded lists where safe
6. Update docs/changelog/tests and close the phase when validation and install stay green

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig -GitHookEofMode autofix -GitHookEofScope global`

## Risks And Fallbacks

- Risk: a catalog-driven dispatcher could hide renderer-specific arguments and regress bootstrap ordering.
  - Fallback: keep renderer-specific scripts intact and let the catalog dispatcher call them explicitly with curated parameter maps.
- Risk: `validate-instructions.ps1` may become harder to reason about if all surface expectations are abstracted at once.
  - Fallback: migrate only projected surface checks to catalog-driven logic and leave governance-native `.github/` checks explicit.
- Risk: docs may drift if they describe the catalog but still list stale manual examples.
  - Fallback: update `definitions/README.md`, `README.md`, and `scripts/README.md` in the same slice and keep examples anchored to the new catalog entrypoint.

## Recommended Specialists

- Planning: `plan-active-work-planner`
- Documentation: `docs-release-engineer`
- Review: `review-code-engineer`

## Closeout Expectations

- Keep commit guidance and changelog in English.
- Document the catalog as the authoritative architecture map for projected surfaces.
- Move the plan/spec to `completed` only after runtime validation and full install are green.