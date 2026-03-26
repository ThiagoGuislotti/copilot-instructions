---
name: dev-rust-engineer
description: Implement, organize, and test Rust modules following mandatory project organization and test discovery rules. Use when tasks involve Cargo crates, module structure, Rust refactors, or creation/fix of Rust tests including required error test coverage.
---

# Rust Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Rust instruction pack

- `.github/instructions/rust-code-organization.instructions.md`
- `.github/instructions/rust-testing.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent within the Super Agent pipeline.

## Execution workflow

1. Keep module/file organization aligned with repository structure rules.
2. Implement behavior changes with explicit error handling and public API focus.
3. Add/update required tests, including error-path coverage.
4. Ensure `tests/test_suite.rs` discovery strategy remains valid.
5. Run validation only after green checks.

## Prompt accelerators

- `.github/prompts/create-rust-module.prompt.md`

## Validation examples

```powershell
cargo fmt --check
cargo build
cargo test
```