# Provider Surface Projection Catalog Phase 4

Generated: 2026-03-26

## Objective

Add one canonical projection catalog that describes the repository-owned `definitions/ -> projected surface` architecture so bootstrap, validation, and docs consume the same surface map instead of duplicating it.

## Problem Statement

The repository already projects GitHub instruction assets, Codex skills/orchestration/compatibility assets, Claude skills/runtime settings, and VS Code profiles/workspace assets from `definitions/`. However, the authoritative surface map is still duplicated across:
- `scripts/runtime/bootstrap.ps1`
- `scripts/validation/validate-instructions.ps1`
- `definitions/README.md`
- `README.md`
- `scripts/README.md`

That duplication increases drift risk every time a new projected surface is added. The safe next architectural step is to define one versioned projection catalog and use it as the shared runtime/documentation/validation reference.

## Design Summary

The phase is additive and non-destructive:
- create a canonical provider-surface projection catalog under `.github/governance/`
- add a schema under `.github/schemas/`
- add shared helpers for reading/querying the catalog
- add a catalog-driven runtime entrypoint that can summarize and invoke the known renderers
- migrate bootstrap to dispatch through the catalog where ordering is safe
- migrate projected-surface validation to use catalog entries instead of repeating per-surface path maps in script logic
- keep renderer-specific scripts intact; the catalog coordinates them rather than replacing them

## Candidate Catalog Shape

Each surface entry should carry enough metadata for runtime, validation, and docs:
- `id`
- `provider`
- `kind`
- `authoritativePath`
- `projectedPath`
- `rendererScript`
- `rendererArgs`
- `bootstrapModes` or `bootstrapProfiles`
- `validationMode`
- `description`
- `generated` flag for catalog-driven exceptions
- `notes`

Intentional generated exceptions remain represented in the catalog but flagged as generated rather than `definitions/`-authored:
- `.vscode/mcp.tamplate.jsonc`
- `.vscode/mcp-vscode-global.json`
- `.codex/mcp/servers.manifest.json`

## Decisions

1. The new catalog becomes the canonical architecture map for projected surfaces, but not for GitHub-native governance assets such as workflows, policies, schemas, templates, and runbooks.
2. Existing renderer scripts stay in place; the catalog dispatcher orchestrates them rather than replacing them.
3. Bootstrap ordering remains explicit through ordered catalog entries, not arbitrary filesystem discovery.
4. Validation migrates only the projected/provider-surface checks to the catalog; repository-native governance checks remain explicit.
5. Docs should describe the catalog as the source of truth and keep only short examples rather than duplicating the full surface matrix manually.

## Constraints

- Do not change external runtime target paths.
- Do not move governance-native `.github/` assets into `definitions/`.
- Do not rework MCP generated exceptions into authored definitions surfaces.
- Do not introduce Rust/Cargo in this phase.

## Acceptance Criteria

1. A versioned provider-surface projection catalog and schema exist under `.github/governance/` and `.github/schemas/`.
2. A shared helper can load/query the catalog from runtime and validation scripts.
3. A runtime entrypoint can summarize and invoke known projected surfaces from the catalog.
4. `bootstrap.ps1` uses the catalog-driven dispatcher for projected surfaces instead of a fixed renderer list.
5. `validate-instructions.ps1` uses the catalog to validate projected surface parity without duplicating the whole surface map inline.
6. The main architecture docs point to the catalog as the authoritative projection map.
7. `validate-all` and the full `install.ps1 -RuntimeProfile all ...` flow remain green.

## Risks

- The catalog may under-specify renderer-specific behavior and make the dispatcher brittle.
- Bootstrap may regress if the ordered surface list changes unintentionally.
- Validation failures may become harder to read if catalog abstraction hides the concrete source/target pair.

## Mitigations

- Keep renderer-specific scripts as first-class entrypoints.
- Add explicit order fields and bootstrap flags in the catalog.
- Emit concrete source/target paths in validation failures and dispatcher logs.

## Planning Readiness

ready-for-plan