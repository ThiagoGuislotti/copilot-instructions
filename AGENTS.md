# Repository Guidelines

## Scope & References
- Repo-wide; subfolder `AGENTS.md` may specialize. Direct prompts override.
- Core: `.github/copilot-instructions.md`. Language policy: EN code/commits, pt-BR UI via i18n, EN DB schema.
- Mandatory: `.github/instructions/workflow-optimization.instructions.md`, `.github/instructions/ai-orchestration.instructions.md`, `.github/instructions/powershell-execution.instructions.md`, `.github/instructions/feedback-changelog.instructions.md`.
- For `.github`: `.github/instructions/copilot-instruction-creation.instructions.md`. Domain sets live in `.github/instructions/*`.
- SCM/CI: Azure DevOps primary; `.github` hosts agent/PR guidance.
 - Branches like `feature/dynamicFilter` are ephemeral; avoid branch-specific rules.

## Overview
Monorepo of libraries, modules, and samples for robust .NET services using Clean Architecture and CQRS: mediator via `NetToolsKit.Mediator`, EF Core, ASP.NET Core, and worker patterns.

## Structure
- `src/` libraries; `modules/` features (Authentication, Services, Tools); `samples/src/Rent.Service.*` (Domain/Application/Infrastructure/Api/Worker); `tests/` mirrors; `native/`; `benchmarks/`; `.github/`.

## Build, Test & Run
- `dotnet build NetToolsKit.sln`; targeted: `dotnet build -f net8.0|net9.0`.
- Tests: `dotnet test --filter "Category=Unit"`; module integration: `dotnet test modules/Authentication --filter "Category=Integration"`.
- Run sample API: `dotnet run --project samples/src/Rent.Service.Api`.
- Pack/format/security: `dotnet pack -c Release`; `dotnet format`; `dotnet list package --vulnerable`.

## Style
- Namespaces mirror folders (`src/NetToolsKit.DynamicQuery/*` -> `NetToolsKit.DynamicQuery`). C#: PascalCase types, camelCase locals/params, UPPER_SNAKE_CASE constants.
- Prefer `sealed` when appropriate; clean `using`; UTF-8 without BOM; public APIs with XML docs; avoid inline comments unless asked.
- EOF: `.github/instructions/*.md` and Codex outputs without final newline; others follow `.editorconfig` (final newline). No trailing whitespace.

## UI Guidelines
- UI strings via i18n (pt-BR). HTTP APIs: plural nouns, standard status codes, `application/problem+json` for errors.

## Testing
- Projects `{Project}.Tests`; files `{TypeName}Tests.cs`. Categories: `Unit`, `Integration`.
- Assert behavior (CQRS handlers, EF Core, REST). Ensure tests pass locally.

## Commits & PRs
- Commits in EN, imperative, ≤72 chars; optional scope (e.g., `DynamicQuery:`).
- PRs: Context | Changes | Rationale | Risks | Testing | Docs | Breaking Changes | Migration.
- List Applied instructions paths and deviations; require green build/tests; no secrets. Session tracking: `project | file | component/method | action`.

## Transparency
- List applied instructions only when executing plans/commands/patches. Use a short preamble before tool calls. Consolidate full instruction list in PR/CHANGELOG when applicable.

## Agent Workflow (Copilot -> Codex)
- Copilot: small edits/refactors/tests/docs. Codex: deterministic single-file gen, infra/pipeline YAML.
- For non-trivial tasks: short plan; preamble before tool calls. Response: TOOL SELECTION + confidence | rationale | if Codex: exact command | validation.
- Validate: namespace, TFMs, XML docs, sealed, usings, EOF; fix via Copilot if needed.

## Patterns
- Multi-target .NET 8/9 with consistent public API; use `#if` only when necessary. Vulnerabilities: `dotnet list package --vulnerable`. Test attributes: xUnit `[Trait("Category","Unit")]`, NUnit `[Category("Integration")]`.

## Security & Changelog
- No secrets in repo; use User Secrets/Azure Key Vault; typed options via `IOptions`.
- CHANGELOG: `.github/CHANGELOG.md` for `.github`; root `CHANGELOG.md` for project; entries with `[X.Y.Z]` and `YYYY-MM-DD`.
 
## Domain Instruction References
- Development: `.github/instructions/clean-architecture-code.instructions.md`, `.github/instructions/dotnet-csharp.instructions.md`, `.github/instructions/backend.instructions.md`, `.github/instructions/frontend.instructions.md`, `.github/instructions/vue-quasar.instructions.md`, `.github/instructions/ui-ux.instructions.md`
- Data: `.github/instructions/orm.instructions.md`, `.github/instructions/database.instructions.md`, `.github/instructions/microservices-performance.instructions.md`
- Infrastructure: `.github/instructions/docker.instructions.md`, `.github/instructions/k8s.instructions.md`, `.github/instructions/ci-cd-devops.instructions.md`, `.github/instructions/static-analysis-sonarqube.instructions.md`
- Testing: `.github/instructions/e2e-testing.instructions.md`
- Documentation: `.github/instructions/readme.instructions.md`, `.github/instructions/prompt-templates.instructions.md`, `.github/instructions/effort-estimation-ucp.instructions.md`, `.github/instructions/pr.instructions.md`