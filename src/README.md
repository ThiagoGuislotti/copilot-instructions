# Source Engine

This directory is reserved for future executable engine code.

## Purpose

- renderers and projection engines
- local context indexing and retrieval engine
- runtime sync helpers that may later move behind a compiled CLI

## Rules

- keep non-code authored assets out of `src/`
- do not move `.github`, `.codex`, `.claude`, or `.vscode` content here directly
- keep `scripts/` as the operator-facing wrapper layer while the migration is in progress

## Status

- scaffolded as part of the runtime source/projection architecture migration
- Rust/Cargo adoption is deferred until the repository topology is stable