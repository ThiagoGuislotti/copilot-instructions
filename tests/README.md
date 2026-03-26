# Engine Tests

This directory is reserved for future engine-oriented tests.

## Purpose

- unit tests for render/index/query logic
- integration tests for projection/runtime parity
- fixtures and golden cases for deterministic output verification

## Rules

- prefer engine-level tests here once `src/` starts owning executable code
- keep current PowerShell runtime tests under `scripts/tests/` until the migration moves those concerns intentionally
- do not duplicate provider/runtime projection outputs here

## Status

- scaffolded as part of the runtime source/projection architecture migration
- the current repository test surface still lives primarily under `scripts/tests/`