---
name: test-engineer
description: Design, implement, and stabilize automated tests in this repository (unit, integration, and E2E) for .NET/C#, Rust, APIs, and frontend flows. Use when the user asks to create tests, increase coverage, fix flaky tests, or validate behavior changes.
---

# Test Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md`.
3. Load only mandatory files plus testing and domain-specific packs.

## Testing instruction packs

- Core .NET testing:
  - `.github/instructions/dotnet-csharp.instructions.md`
  - `.github/instructions/backend.instructions.md`
- Integration and E2E:
  - `.github/instructions/e2e-testing.instructions.md`
- Rust testing:
  - `.github/instructions/rust-testing.instructions.md`
  - `.github/instructions/rust-code-organization.instructions.md`
- Quality gates (when requested):
  - `.github/instructions/static-analysis-sonarqube.instructions.md`

## Execution workflow

1. Map changed behavior and high-risk scenarios first.
2. Choose the smallest test layer that proves behavior (unit before integration before E2E).
3. Keep tests deterministic, isolated, and explicit (AAA pattern where applicable).
4. Cover success path, edge cases, and failure path.
5. Run dependency vulnerability audit for impacted stack before broader test/build validation.

## Prompt accelerators

- `.github/prompts/generate-unit-tests.prompt.md`

## Validation examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-VulnerabilityAudit.ps1') -RepoRoot $PWD -FailOnSeverities Critical,High
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-FrontendPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath src/WebApp -FailOnSeverities Critical,High
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-RustPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath . -FailOnSeverities Critical,High
dotnet test --filter "Category=Unit"
dotnet test --filter "Category=Integration"
cargo test
```