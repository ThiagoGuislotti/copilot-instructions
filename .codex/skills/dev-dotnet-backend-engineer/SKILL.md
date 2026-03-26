---
name: dev-dotnet-backend-engineer
description: Extend dev-software-engineer with .NET/C# backend specialization for Clean Architecture, CQRS, EF Core, and production-ready API practices. Use when tasks involve ASP.NET endpoints, handlers, services, dependency injection, MediatR, migrations, or backend performance/resilience and should follow the base implementation workflow.
---

# Dev Dotnet Backend Engineer

## Inherit from base skill

1. Load and apply `../dev-software-engineer/SKILL.md` as the base contract.
2. Reuse the base workflow and safety rules unless this file defines a stricter override.
3. Keep `.github/instructions/repository-operating-model.instructions.md` as the canonical repo-operating reference inherited from the base skill.
4. Restrict domain scope to .NET backend, database, and ORM concerns only.

## Domain instruction delta (override base selection)

- `.github/instructions/dotnet-csharp.instructions.md`
- `.github/instructions/clean-architecture-code.instructions.md`
- `.github/instructions/backend.instructions.md`
- `.github/instructions/database.instructions.md`
- `.github/instructions/orm.instructions.md`
- `.github/instructions/microservices-performance.instructions.md` (when applicable)

## Prompt accelerator delta

- `.github/prompts/create-dotnet-class.prompt.md`
- `.github/prompts/create-api-endpoint.prompt.md`
- `.github/prompts/create-ef-migration.prompt.md`
- `.github/prompts/refactor-to-clean-architecture.prompt.md`

## Execution workflow delta

1. Confirm layer boundaries and domain model ownership.
2. Implement minimal backend change preserving contracts.
3. Apply validation, error model, and observability patterns.
4. Add/update unit and integration tests for changed behavior.
5. Run .NET dependency vulnerability audit before build/pack and then execute targeted tests.

## Validation delta examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-VulnerabilityAudit.ps1') -RepoRoot $PWD -SolutionPath NetToolsKit.sln -FailOnSeverities Critical,High
dotnet build
dotnet test --filter "Category=Unit"
dotnet test --filter "Category=Integration"
dotnet pack -c Release
```