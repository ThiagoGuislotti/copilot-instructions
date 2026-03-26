# Shared POML Library Boundary Phase 7

Generated: 2026-03-26

## Objective

Finish the last obvious pre-Rust folder-boundary correction by moving the POML
library out of the GitHub provider prompt tree and into a shared authoritative
location.

## Problem Statement

`definitions/providers/github/prompts/poml/` currently mixes two concerns:

- provider-specific GitHub prompt entrypoints
- a reusable POML asset library with styles, templates, fixtures, and guidance

That POML subtree is not GitHub-specific. It is a reusable prompt asset library
that can be consumed by GitHub, future Rust tooling, and other runtimes.

## Design Summary

- create `definitions/shared/prompts/poml/`
- move these authored assets there:
  - `prompt-engineering-poml.md`
  - `styles/**`
  - `templates/**`
  - `fixtures/**`
- keep `definitions/providers/github/prompts/*.prompt.md` as provider-specific
  prompt entrypoints
- render `.github/prompts/poml/` from the shared POML library

## Acceptance Criteria

1. `definitions/shared/prompts/poml/` becomes the authoritative home of the POML library.
2. `definitions/providers/github/prompts/poml/` no longer owns the POML library.
3. `.github/prompts/poml/` still exists as the projected runtime/editor surface.
4. README/docs refer to the shared POML source correctly.
5. validation and runtime tests remain green.

## Planning Readiness

completed