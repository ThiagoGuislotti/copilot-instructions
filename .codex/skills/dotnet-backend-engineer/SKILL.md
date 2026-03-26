---
name: dotnet-backend-engineer
description: Implement, refactor, and troubleshoot .NET/C# backend APIs in this repository with Clean Architecture, CQRS, EF Core, and production-ready practices. Use when tasks involve ASP.NET endpoints, handlers, services, dependency injection, MediatR, migrations, or backend performance and resilience.
---

# Dotnet Backend Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml` and `.github/prompts/route-instructions.prompt.md`.
3. Keep only mandatory files plus backend pack.

## Backend instruction pack

- `.github/instructions/dotnet-csharp.instructions.md`
- `.github/instructions/clean-architecture-code.instructions.md`
- `.github/instructions/backend.instructions.md`
- `.github/instructions/database.instructions.md`
- `.github/instructions/orm.instructions.md`
- `.github/instructions/microservices-performance.instructions.md` (when applicable)

## Prompt accelerators

- `.github/prompts/create-dotnet-class.prompt.md`
- `.github/prompts/create-api-endpoint.prompt.md`
- `.github/prompts/create-ef-migration.prompt.md`
- `.github/prompts/refactor-to-clean-architecture.prompt.md`

## Execution workflow

1. Confirm layer boundaries and domain model ownership.
2. Implement minimal backend change preserving contracts.
3. Apply validation, error model, and observability patterns.
4. Add/update unit and integration tests for changed behavior.
5. Run dependency vulnerability audit before build/pack and then execute targeted tests.

## Validation examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-VulnerabilityAudit.ps1') -RepoRoot $PWD -SolutionPath NetToolsKit.sln -FailOnSeverities Critical,High
dotnet build
dotnet test --filter "Category=Unit"
dotnet test --filter "Category=Integration"
dotnet pack -c Release
```