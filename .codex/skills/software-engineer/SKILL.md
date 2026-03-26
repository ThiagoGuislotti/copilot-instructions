---
name: software-engineer
description: Implement and refactor application code in this repository across .NET/C#, backend APIs, database/ORM, frontend Vue/Quasar, and Rust with Clean Architecture rules. Use when the user asks to build features, fix bugs, refactor modules, or improve code-level performance.
---

# Software Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md`.
3. Keep only mandatory files plus the selected domain pack.

## Select domain instruction pack

- .NET and backend:
  - `.github/instructions/dotnet-csharp.instructions.md`
  - `.github/instructions/clean-architecture-code.instructions.md`
  - `.github/instructions/backend.instructions.md`
- Database and ORM:
  - `.github/instructions/database.instructions.md`
  - `.github/instructions/orm.instructions.md`
- Frontend Vue/Quasar:
  - `.github/instructions/frontend.instructions.md`
  - `.github/instructions/vue-quasar.instructions.md`
  - `.github/instructions/vue-quasar-architecture.instructions.md`
  - `.github/instructions/ui-ux.instructions.md`
- Rust:
  - `.github/instructions/rust-code-organization.instructions.md`
  - `.github/instructions/rust-testing.instructions.md`
- Performance/microservices (when applicable):
  - `.github/instructions/microservices-performance.instructions.md`

## Execution workflow

1. Define scope, constraints, and impacted modules.
2. Implement the smallest safe change that satisfies the request.
3. Preserve layer boundaries and dependency direction.
4. Add or update tests for changed behavior.
5. Run targeted validation commands and dependency vulnerability audit for each impacted stack before build/package.

## Prompt accelerators

- `.github/prompts/create-dotnet-class.prompt.md`
- `.github/prompts/create-api-endpoint.prompt.md`
- `.github/prompts/create-ef-migration.prompt.md`
- `.github/prompts/create-vue-component.prompt.md`
- `.github/prompts/create-rust-module.prompt.md`
- `.github/prompts/refactor-to-clean-architecture.prompt.md`

## Validation examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-PreBuildSecurityGate.ps1') -RepoRoot $PWD -FailOnSeverities Critical,High
dotnet build
dotnet test --filter "Category=Unit"
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-VulnerabilityAudit.ps1') -RepoRoot $PWD -FailOnSeverities Critical,High
npm run build
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-FrontendPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath src/WebApp -FailOnSeverities Critical,High
cargo test
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-RustPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath . -FailOnSeverities Critical,High
```