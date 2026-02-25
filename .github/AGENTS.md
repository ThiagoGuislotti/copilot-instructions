# Copilot Agents and Context Policy

# Agents
- Workspace: code-first agent for this repo. Reads/edits files, runs searches, and proposes patches.
- GitHub: PR/issue-centric agent. Summarizes, reviews, and changes GitHub artifacts.
- Profiler: performance agent. Benchmarks, profiles, and optimizes hot paths.
- VS: IDE helper. Settings, build/debug help, MSBuild/solution issues.

# Mandatory Context Files
- Always include BOTH of these files first when selecting context for Copilot Chat:
  1. AGENTS.md (this file)
  2. copilot-instructions.md

Default workflow for all tasks: Static RAGs Routing (Route → Execute)
- Route first (pick minimal context):
  - `instruction-routing.catalog.yml` (single source of truth for routes)
  - `prompts/route-instructions.prompt.md` (route-only prompt that outputs a JSON context pack)
- Execute next: use ONLY the files returned by the Context Pack.

If context budget is tight, prefer dropping any other files before these. These two documents coordinate global rules and agent usage and must be loaded to avoid inconsistent answers.

# How to Use in Chat
- Prefer the Workspace agent for code changes in this repo.
- Switch to GitHub for PR/issue workflows.
- Switch to Profiler for performance/benchmark tasks.
- Switch to VS for IDE or build tooling questions.

# Instruction Entry Point (Decision Flow)
Use this section as the quick “what do I load / follow first?” guide.

## Static RAGs Routing
Baseline workflow for anything in this repo.

1) Always load these first (in order)
Follow the **Mandatory Context Files** list above.

2) Then select additional instruction files based on what you are changing
- If editing `.github/**`: include `instructions/pr.instructions.md` and `instructions/prompt-templates.instructions.md` when relevant.
- If editing `instructions/**`: include `instructions/copilot-instruction-creation.instructions.md`.
- If editing code: select the domain instruction file(s) under `instructions/` that match the language/folder (e.g., `instructions/dotnet-csharp.instructions.md`, `backend.instructions.md`, `database.instructions.md`, etc).

3) Precedence rules when instructions conflict
- Follow the user prompt first.
- Then follow `AGENTS.md` + `copilot-instructions.md`.
- Then prefer the most specific instruction file by scope/path (narrower `applyTo` wins over broader).
- If two instructions are equally specific and conflict, pick the safer/minimal option and call out the ambiguity.

# Auditing & Transparency
- When listing applied instructions in a response or PR body, reference both copilot-instructions.md and AGENTS.md when they influence the change.

# Context Preservation & Execution Patterns

## Session Continuity
- Load previous context at session start: review recent changes and current state
- Maintain architectural patterns and decisions from earlier work
- Preserve Clean Architecture boundaries and established abstractions
- Respect previous technical choices unless explicitly changing approach

## Execution Flow for Development Tasks
1. Task Analysis: Load mandatory context files, identify domain, analyze scope
2. Planning: Create execution plan for non-trivial tasks, validate architecture
3. Implementation: Follow established templates and patterns, maintain standards
4. Validation: Verify compilation, run tests, confirm architectural compliance

### For Multi-Task Requests
- Apply Task-Based Execution Methodology (see below)
- Break complex requests into numbered, sequential tasks
- Validate each task completion before proceeding
- Maintain session continuity across task boundaries

## Quality Gates
Before generating code: Context loaded, patterns identified, approach validated
During implementation: Templates followed, naming conventions applied, boundaries respected
After changes: Code compiles, tests pass, architecture maintained, documentation updated

## Command Usage Patterns
- Use semantic_search for finding related patterns and implementations
- Use grep_search for locating specific patterns across files
- Use file_search for finding files by naming patterns
- Always use create_file following templates and replace_string_in_file for targeted changes

## Common Pitfalls to Avoid
- Context loss: Forgetting architectural decisions from earlier in session
- Pattern deviation: Creating new patterns instead of following established ones
- Layer violations: Breaking Clean Architecture dependency rules
- Standard drift: Not maintaining consistent coding standards

# Task-Based Execution Methodology

## Multi-Task Request Structure
- Break complex requests into numbered, sequential tasks
- Each task should have clear scope, dependencies, and success criteria
- Use format: "Tarefas: 1- [task], 2- [task], 3- [task]"
- Validate completion of each task before proceeding to next

## Task Execution Pattern
1. Task Analysis: Review all tasks, identify dependencies and execution order
2. Task Planning: Confirm approach and tools needed for each task
3. Sequential Execution: Complete tasks in order, validate each step
4. Progress Tracking: Report completion status and any blockers
5. Final Validation: Ensure all tasks completed successfully

## Task Documentation
- Document task completion in session context
- Reference specific files/changes made per task
- Note any deviations from original task specification
- Provide rollback information if tasks need to be undone

## Benefits of Task-Based Approach
- Improved clarity and reduced ambiguity in complex requests
- Better progress tracking and session continuity
- Easier debugging when tasks fail or need modification
- Enhanced collaboration between human and AI agents
- Systematic approach aligned with Clean Architecture principles

# Repository Guidelines

## Scope & References
- Repo-wide; subfolder `AGENTS.md` may specialize. Direct prompts override.
- Core: `copilot-instructions.md`. Language policy: EN code/commits, pt-BR UI via i18n, EN DB schema.
- Mandatory: `instructions/workflow-optimization.instructions.md`, `instructions/powershell-execution.instructions.md`, `instructions/feedback-changelog.instructions.md`.
- For `.github`: `instructions/copilot-instruction-creation.instructions.md`. Domain sets live in `instructions/*`.
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
- EOF: `instructions/*.md` and Codex outputs without final newline; others follow `.editorconfig` (final newline). No trailing whitespace.

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
- CHANGELOG: single source at root `CHANGELOG.md` for `.github` and project changes; entries with `[X.Y.Z]` and `YYYY-MM-DD`.

## Domain Instruction References
- Development: `instructions/clean-architecture-code.instructions.md`, `instructions/dotnet-csharp.instructions.md`, `instructions/backend.instructions.md`, `instructions/frontend.instructions.md`, `instructions/vue-quasar.instructions.md`, `instructions/ui-ux.instructions.md`
- Data: `instructions/orm.instructions.md`, `instructions/database.instructions.md`, `instructions/microservices-performance.instructions.md`
- Infrastructure: `instructions/docker.instructions.md`, `instructions/k8s.instructions.md`, `instructions/ci-cd-devops.instructions.md`, `instructions/static-analysis-sonarqube.instructions.md`, `instructions/powershell-script-creation.instructions.md`
- Testing: `instructions/e2e-testing.instructions.md`
- Documentation: `instructions/readme.instructions.md`, `instructions/prompt-templates.instructions.md`, `instructions/effort-estimation-ucp.instructions.md`, `instructions/pr.instructions.md`
