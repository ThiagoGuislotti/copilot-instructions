---
name: test-engineer
description: Design, implement, and stabilize automated tests (unit, integration, E2E) for .NET/C#, Rust, APIs, and frontend flows. Use when the user asks to create tests, increase coverage, fix flaky tests, or validate behavior changes.
---

# Test Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Testing instruction packs

- Core .NET:
  - `.github/instructions/dotnet-csharp.instructions.md`
  - `.github/instructions/backend.instructions.md`
- Integration and E2E:
  - `.github/instructions/e2e-testing.instructions.md`
- Rust:
  - `.github/instructions/rust-testing.instructions.md`
  - `.github/instructions/rust-code-organization.instructions.md`
- Quality gates (when requested):
  - `.github/instructions/static-analysis-sonarqube.instructions.md`
- TDD:
  - `.github/instructions/tdd-verification.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent within the Super Agent pipeline. Always runs after implementation, before review.

## Execution workflow

1. Map changed behavior and high-risk scenarios first.
2. Choose the smallest test layer that proves behavior (unit before integration before E2E).
3. Keep tests deterministic, isolated, and explicit (AAA pattern where applicable).
4. Cover success path, edge cases, and failure path.
5. Validate only after all targeted tests pass.

## Prompt accelerators

- `.github/prompts/generate-unit-tests.prompt.md`

## Validation examples

```powershell
dotnet test --filter "Category=Unit"
dotnet test --filter "Category=Integration"
cargo test
```