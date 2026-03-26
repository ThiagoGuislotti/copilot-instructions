# GitHub Definitions Coverage Completion Phase 5

Generated: 2026-03-26

## Objective

Finish the authored GitHub provider coverage under `definitions/` before introducing Rust so the repository has one clear authoritative source for provider-authored GitHub assets.

## Problem Statement

The repository already projects GitHub instructions, prompts, hooks, chatmodes, agents, and selected root files from `definitions/providers/github/`. However, several authored GitHub assets still live only under `.github/`:
- root-level provider files such as `PULL_REQUEST_TEMPLATE.md`, `dependabot.yml`, and `dependency-review-config.yml`
- `.github/ISSUE_TEMPLATE/`
- `.github/templates/`

That leaves the definitions tree visually and structurally incomplete, even though the broader architecture already positions `definitions/` as the authoritative source for provider-authored assets. Before starting any Rust engine work, the GitHub provider surface should be complete enough that only intentionally native governance assets remain outside `definitions/`.

## Design Summary

This phase remains additive and non-destructive:
- move the remaining authored GitHub root/provider files behind `definitions/providers/github/root/`
- add authoritative `definitions/providers/github/ISSUE_TEMPLATE/`
- add authoritative `definitions/providers/github/templates/`
- extend the GitHub renderer and provider-surface catalog to project those assets back into `.github/`
- keep governance-native assets authored directly in `.github/`:
  - `governance/`
  - `policies/`
  - `runbooks/`
  - `schemas/`
  - `workflows/`

## Decisions

1. `definitions/providers/github/` should cover provider-authored GitHub assets, not governance-native repository policy assets.
2. `PULL_REQUEST_TEMPLATE.md`, `dependabot.yml`, and `dependency-review-config.yml` are treated as authored GitHub provider root files and should move behind `definitions/providers/github/root/`.
3. `.github/ISSUE_TEMPLATE/` and `.github/templates/` are treated as authored GitHub provider directories and should move behind `definitions/providers/github/`.
4. Governance-native `.github/{governance,policies,runbooks,schemas,workflows}/` remain authored in place and are documented as explicit exceptions.
5. No Rust/Cargo work begins until this coverage gap is closed and validated.

## Constraints

- Do not delete or relocate runtime-facing `.github/` paths.
- Do not move governance-native assets into `definitions/` in this phase.
- Do not introduce Rust/Cargo yet.
- Keep install/bootstrap behavior stable.

## Acceptance Criteria

1. `definitions/providers/github/root/` contains all authored GitHub root files that are intended to be projected.
2. `definitions/providers/github/ISSUE_TEMPLATE/` exists and projects deterministically to `.github/ISSUE_TEMPLATE/`.
3. `definitions/providers/github/templates/` exists and projects deterministically to `.github/templates/`.
4. The GitHub renderer and provider-surface projection catalog cover the expanded GitHub provider surface.
5. `validate-instructions.ps1` validates parity for the new GitHub definition-backed surfaces.
6. README/docs describe the expanded coverage and the remaining native exceptions clearly.
7. `validate-all` and the full `install.ps1 -RuntimeProfile all ...` flow remain green.

## Risks

- The provider boundary may become unclear if governance-native assets are mixed into the same renderer.
- Renderer expansion could accidentally delete native `.github/` content if the directory scope is wrong.
- The definitions tree could still look incomplete if the native exceptions are not explicitly documented.

## Mitigations

- Keep the renderer/catalog scope explicit by directory and file list.
- Add catalog entries only for the newly definitions-backed GitHub assets.
- Update `definitions/README.md` and `definitions/providers/github/README.md` to call out the remaining native exceptions directly.

## Planning Readiness

ready-for-plan