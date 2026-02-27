---
name: rust-engineer
description: Implement, organize, and test Rust modules in this repository following mandatory project organization and test discovery rules. Use when tasks involve Cargo crates, module structure, Rust refactors, or creation/fix of Rust tests including required error test coverage.
---

# Rust Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Keep only mandatory files plus Rust pack.

## Rust instruction pack

- `.github/instructions/rust-code-organization.instructions.md`
- `.github/instructions/rust-testing.instructions.md`

## Prompt and chatmode accelerators

- `.github/prompts/create-rust-module.prompt.md`
- `.github/chatmodes/rust-expert.chatmode.md`

## Execution workflow

1. Keep module/file organization aligned with repository structure rules.
2. Implement behavior changes with explicit error handling and public API focus.
3. Add/update required tests, including error-path coverage.
4. Ensure `tests/test_suite.rs` discovery strategy remains valid.
5. Run dependency vulnerability audit before build/test and finish only after green checks.

## Validation examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-RustPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath . -FailOnSeverities Critical,High
cargo fmt --check
cargo build
cargo test
```