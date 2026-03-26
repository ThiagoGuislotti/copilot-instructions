# Shared Authority Boundary Refactor Phase 6

Generated: 2026-03-26

## Objective

Finish the pre-Rust authority-boundary cleanup so shared reusable assets no longer live under `providers/github`, and GitHub-native repository/community files no longer masquerade as Copilot/provider-authored surfaces.

## Problem Statement

The repository now has a functional `definitions -> projected surface` architecture, but the current GitHub slice still mixes three different ownership classes:
- shared reusable assets such as instruction files and reusable templates
- GitHub/Copilot runtime surfaces such as agents, chatmodes, prompts, hooks, and root adapter files
- GitHub-native repository/community/governance files such as issue templates, PR template, Dependabot config, and dependency review config

That boundary is wrong. It makes `definitions/providers/github/` look complete while still encoding the wrong authority model. Before starting any Rust engine work, the repository should separate shared assets, provider runtime assets, and GitHub-native repository assets clearly.

## Design Summary

This phase remains non-destructive to projected runtime folders:
- create `definitions/shared/instructions/` as the authoritative source for reusable instruction files currently projected into `.github/instructions/`
- create `definitions/shared/templates/` as the authoritative source for reusable repository templates currently projected into `.github/templates/`
- narrow `definitions/providers/github/` to:
  - `root/`
  - `agents/`
  - `chatmodes/`
  - `prompts/`
  - `hooks/`
- keep GitHub-native repository/community assets authored directly in `.github/`:
  - `PULL_REQUEST_TEMPLATE.md`
  - `ISSUE_TEMPLATE/`
  - `dependabot.yml`
  - `dependency-review-config.yml`
  - `governance/`
  - `policies/`
  - `runbooks/`
  - `schemas/`
  - `workflows/`

## Decisions

1. `definitions/shared/` owns reusable authored assets that are not provider-specific.
2. `definitions/providers/github/` owns only GitHub/Copilot runtime-specific projected surfaces.
3. `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/**`, `.github/dependabot.yml`, and `.github/dependency-review-config.yml` remain authored directly in `.github/` and are not provider-projected surfaces.
4. `.github/instructions/` and `.github/templates/` remain projected surfaces, but their authority moves to `definitions/shared/`.
5. Rust/Cargo work remains blocked until this authority boundary is corrected and validated.

## Constraints

- Do not delete `.github`, `.codex`, `.claude`, or `.vscode` runtime surfaces.
- Keep runtime/install/bootstrap behavior stable.
- Keep the projection model explicit through the canonical catalog.
- Do not begin Rust migration in this phase.

## Acceptance Criteria

1. `definitions/shared/instructions/` exists and becomes the authoritative source for reusable instruction files projected into `.github/instructions/`.
2. `definitions/shared/templates/` exists and becomes the authoritative source for shared reusable templates projected into `.github/templates/`.
3. `definitions/providers/github/` no longer owns `instructions/`, `templates/`, `ISSUE_TEMPLATE/`, or GitHub-native root/community files.
4. `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/**`, `.github/dependabot.yml`, and `.github/dependency-review-config.yml` remain authored directly in `.github/`.
5. The provider-surface projection catalog, GitHub renderer, validation suite, runtime tests, and docs all reflect the corrected boundary.
6. `validate-all` and the full `install.ps1 -RuntimeProfile all ...` flow remain green.

## Risks

- Renderers/tests may still assume GitHub-owned instructions/templates.
- Docs may continue to describe GitHub-native files as provider surfaces.
- Partial moves may leave duplicate authoritative copies.

## Mitigations

- Move authority and update renderer/catalog/tests in the same slice.
- Add `definitions/shared/README.md` to document the new boundary explicitly.
- Rerender `.github/` before running validation so parity checks use the new source tree.

## Planning Readiness

ready-for-plan

## Outcome

completed