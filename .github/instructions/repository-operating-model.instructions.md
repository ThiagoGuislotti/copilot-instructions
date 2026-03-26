---
applyTo: "**/*.{cs,csproj,sln,ps1,rs,toml,ts,tsx,js,jsx,vue,yml,yaml,json,jsonc,md,sql}"
priority: high
---

# Repository Operating Model

## Purpose
- Centralize repository-specific operational rules so `AGENTS.md` and `copilot-instructions.md` stay focused on global behavior, routing, and precedence.
- Centralize repository-specific operational rules so `AGENTS.md` and `copilot-instructions.md` stay focused on global behavior, routing, precedence, and mandatory planning.
- Keep repo topology, build/test/run commands, style, release process, and domain instruction references in one canonical location.

## Scope and References
- Repo-wide; subfolder `AGENTS.md` may specialize. Direct prompts override.
- Core global files remain:
  - `AGENTS.md`
  - `copilot-instructions.md`
- Cross-cutting policies remain centralized:
  - `instructions/authoritative-sources.instructions.md`
  - `instructions/artifact-layout.instructions.md`
  - `.github/governance/authoritative-source-map.json`
- Planning lifecycle rules are centralized in `instructions/subagent-planning-workflow.instructions.md` and `planning/README.md`.
- Brainstorm/spec rules are centralized in `instructions/brainstorm-spec-workflow.instructions.md` and `planning/specs/README.md`.
- Super Agent lifecycle rules are centralized in `instructions/super-agent.instructions.md`.
- Worktree isolation rules are centralized in `instructions/worktree-isolation.instructions.md`.
- TDD and verification rules are centralized in `instructions/tdd-verification.instructions.md`.
- For GitHub Actions in external repositories, consume pinned shared scripts from `https://github.com/ThiagoGuislotti/copilot-instructions` instead of copying scripts into target repositories.
- Validate remote script integrity using `.github/governance/shared-script-checksums.manifest.json`.

## Repository Topology
- Monorepo of libraries, modules, and samples for robust .NET services using Clean Architecture and CQRS: mediator via `NetToolsKit.Mediator`, EF Core, ASP.NET Core, and worker patterns.
- Main layout:
  - `src/` libraries
  - `modules/` feature modules such as Authentication, Services, and Tools
  - `samples/src/Rent.Service.*` for Domain/Application/Infrastructure/Api/Worker sample structure
  - `tests/` mirrors source modules
  - `native/`
  - `benchmarks/`
  - `.github/`
  - `planning/` versioned planning workspace with `active/` and `completed/`
  - `planning/specs/` versioned brainstorming/spec workspace with `active/` and `completed/`

## Planning Workspace
- Use `instructions/super-agent.instructions.md` for the mandatory intake-to-closeout lifecycle on change-bearing work.
- Use `instructions/brainstorm-spec-workflow.instructions.md` when non-trivial work needs design direction locked before execution planning.
- Use `instructions/subagent-planning-workflow.instructions.md` for the planning and sub-agent workflow on non-trivial work.
- Use `instructions/worktree-isolation.instructions.md` when the workstream should move into an isolated git worktree.
- Use `instructions/tdd-verification.instructions.md` for code-bearing work that needs explicit verification checkpoints.
- Active plans live in `planning/active/`.
- Completed plans move to `planning/completed/` only after implementation, validation, review, and release closeout are materially complete.
- Active specs live in `planning/specs/active/`.
- Completed specs move to `planning/specs/completed/` with the related workstream when applicable.

## Build, Test, and Run
- Build solution:
  - `dotnet build NetToolsKit.sln`
  - targeted: `dotnet build -f net8.0`
  - targeted: `dotnet build -f net9.0`
- Run tests:
  - `dotnet test --filter "Category=Unit"`
  - module integration: `dotnet test modules/Authentication --filter "Category=Integration"`
- Run sample API:
  - `dotnet run --project samples/src/Rent.Service.Api`
- Packaging and formatting:
  - `dotnet pack -c Release`
  - `dotnet format`
- Vulnerability checks:
  - `dotnet list package --vulnerable`
  - prefer `~/.codex/shared-scripts/security/Invoke-PreBuildSecurityGate.ps1`
- Runtime sync:
  - `pwsh -File scripts/runtime/bootstrap.ps1`
  - mirrors `.github` and `scripts` into `~/.github`
  - syncs `.codex/skills` into `~/.agents/skills` as the single visible Codex/VS Code starter/controller surface
  - removes legacy starter/controller skill duplicates from both `~/.github/skills` and `~/.copilot/skills` so the shared `super-agent` starter stays canonical
  - syncs remaining `.codex` runtime assets into `~/.codex`
- Non-versioned artifact layout:
  - `.build/` for transient build and generated outputs
  - `.deployment/` for publish, package, release, and deployment-ready outputs
  - do not invent new top-level artifact folders when these two cover the need

## Style and Artifact Hygiene
- Namespaces mirror folders such as `src/NetToolsKit.DynamicQuery/*` -> `NetToolsKit.DynamicQuery`.
- C# naming:
  - PascalCase for types
  - camelCase for locals and parameters
  - UPPER_SNAKE_CASE for constants
- Prefer `sealed` when appropriate.
- Keep `using` directives clean and deterministic.
- Use UTF-8 without BOM unless a file-specific format requires otherwise.
- Public APIs should include XML docs.
- Avoid inline comments unless the user explicitly asks for them or the logic is genuinely non-obvious.
- EOF and whitespace:
  - never leave trailing blank lines at EOF
  - follow `.editorconfig`
  - repository policy currently uses `insert_final_newline = false`
  - preserve the exact terminal EOF state during edits; when a file currently has no terminal newline, keep it that way after AI-generated changes
  - do not append a terminal newline unless a narrower file-specific rule explicitly requires it
  - do not add trailing whitespace
- Generated output hygiene:
  - keep non-versioned build or generated output in `.build/`
  - keep publish, release, and deployable output in `.deployment/`
  - do not scatter generated artifacts under source folders when the artifacts are not source of truth

## UI, API, and Database Conventions
- Chat remains pt-BR, but technical assets stay in English unless the repository explicitly requires localized user-facing text.
- UI strings for end users should flow through i18n with pt-BR translations.
- HTTP APIs should use plural nouns, standard status codes, and `application/problem+json` for errors.
- Database schema, table names, and column names remain in English.

## Testing Expectations
- Test projects use `{Project}.Tests`.
- Test files use `{TypeName}Tests.cs`.
- Categories stay consistent:
  - xUnit: `[Trait("Category","Unit")]`
  - NUnit: `[Category("Integration")]`
- Assert behavior across CQRS handlers, EF Core access, REST contracts, and integration boundaries.
- Ensure relevant tests pass locally whenever practical.

## Commits, PRs, and Transparency
- Commits must be in English, imperative, and no longer than 72 characters.
- Use semantic prefixes such as:
  - `feat:`
  - `fix:`
  - `docs:`
  - `refactor:`
  - `test:`
  - `chore:`
  - `perf:`
  - `build:`
  - `ci:`
- When a logically complete item is finished, always return a suggested commit message to the user.
- When the current changes are stable and ready to persist, explicitly state that the work is ready to commit.
- For large tasks, surface stable intermediate commit checkpoints.
- PR structure:
  - Context
  - Changes
  - Rationale
  - Risks
  - Testing
  - Docs
  - Breaking Changes
  - Migration
- List applied instruction paths and deviations when relevant.
- Require green validation and no secrets.

## Security and Changelog
- No secrets in repo; use User Secrets, Azure Key Vault, and typed options via `IOptions`.
- Root `CHANGELOG.md` is the single source of truth for `.github` and project changes.
- Every changelog entry must include semantic version `[X.Y.Z]` and `YYYY-MM-DD`.

## Agent Workflow and Patterns
- Copilot: small edits, refactors, tests, docs.
- Codex: deterministic generation, infra/pipeline YAML, runtime/governance automation, and multi-step repository tasks.
- For non-trivial tasks:
  - create a short plan
  - use a short preamble before tool calls
  - validate namespace, TFMs, XML docs, sealing, `using` directives, and EOF policy when relevant
  - follow super-agent -> brainstorm-spec -> planner -> specialist -> tester -> reviewer -> release-closeout
  - use `context-token-optimizer` only when the task is multi-domain or the context pack has obvious redundancy; do not trim required working context purely for token savings
  - prefer isolated worktrees for risky or long-running workstreams
  - treat verification evidence as mandatory before completion claims
  - keep plan artifacts in `planning/active/` and spec artifacts in `planning/specs/active/` until the work is genuinely complete
- Patterns:
  - multi-target .NET 8/9 with consistent public API
  - use `#if` only when necessary
  - use stack-specific audit scripts under `scripts/security/` before build/package

## Domain Instruction Map
- Development:
  - `instructions/clean-architecture-code.instructions.md`
  - `instructions/dotnet-csharp.instructions.md`
  - `instructions/backend.instructions.md`
  - `instructions/api-high-performance-security.instructions.md`
  - `instructions/frontend.instructions.md`
  - `instructions/vue-quasar.instructions.md`
  - `instructions/vue-quasar-architecture.instructions.md`
  - `instructions/ui-ux.instructions.md`
- Data:
  - `instructions/orm.instructions.md`
  - `instructions/database.instructions.md`
  - `instructions/database-configuration-operations.instructions.md`
  - `instructions/data-privacy-compliance.instructions.md`
  - `instructions/microservices-performance.instructions.md`
- Infrastructure:
  - `instructions/docker.instructions.md`
  - `instructions/k8s.instructions.md`
  - `instructions/ci-cd-devops.instructions.md`
  - `instructions/workflow-generation.instructions.md`
  - `instructions/static-analysis-sonarqube.instructions.md`
  - `instructions/observability-sre.instructions.md`
  - `instructions/platform-reliability-resilience.instructions.md`
  - `instructions/powershell-script-creation.instructions.md`
- Developer workspace:
  - `instructions/vscode-workspace-efficiency.instructions.md`
- Security:
  - `instructions/security-vulnerabilities.instructions.md`
  - `instructions/api-high-performance-security.instructions.md`
  - `instructions/data-privacy-compliance.instructions.md`
- Testing:
  - `instructions/e2e-testing.instructions.md`
  - `instructions/rust-code-organization.instructions.md`
  - `instructions/rust-testing.instructions.md`
- Documentation and process:
  - `instructions/readme.instructions.md`
  - `instructions/prompt-templates.instructions.md`
  - `instructions/effort-estimation-ucp.instructions.md`
  - `instructions/brainstorm-spec-workflow.instructions.md`
  - `instructions/subagent-planning-workflow.instructions.md`
  - `instructions/super-agent.instructions.md`
  - `instructions/worktree-isolation.instructions.md`
  - `instructions/tdd-verification.instructions.md`
  - `instructions/pr.instructions.md`