## [1.0.2] - 2025-09-17

### Added
- Enhanced `templates/dotnet-class-template.cs` with comprehensive static members organization:
  - Added `#region Constants` for constant fields (string and integer types)
  - Added `#region Static Variables` for static readonly fields and Lazy dependencies
  - Added `#region Static Properties` for static properties with custom getters/setters
  - Updated usage comments with examples for all new placeholders
  - Improved template documentation with clear separation between variables and properties

### Changed
- Updated template usage guide with new placeholder explanations:
  - `[CONSTANT_NAME]`, `[CONSTANT_VALUE]`, `[CONSTANT_NAME_INT]`, `[CONSTANT_VALUE_INT]`
  - `[STATIC_VARIABLE_DESCRIPTION]`, `[StaticVariableName]`, `[STATIC_VARIABLE_VALUE]`, `[staticDependencyName]`
  - `[STATIC_PROPERTY_DESCRIPTION]`, `[StaticPropertyName]`, `[PropertyAccessor]`, `[PropertySetter]`, `[StaticBooleanProperty]`

## [1.0.1] - 2025-09-14

### Added
- Updated `.github/copilot-instructions.md` with "STYLE (EOF and whitespace)" rules:
  - Do not leave a trailing blank line at the end of files.
  - For files under `.github/instructions/*.md` and Copilot/Codex instruction outputs: do NOT include a final newline (consistent with `AGENTS.md`).
  - For other files, follow `.editorconfig` rules (final newline usually enforced); always avoid trailing whitespace.

## [1.0.0] - 2025-09-13

### Added
- Core docs:
  - `AGENTS.md` — Agent policies, context selection and workflow.
  - `copilot-instructions.md` — Global rules and domain mapping for the repository.
  - `README.md` — Overview, quick start and contribution guidance.

- Instructions (`instructions/`):
  - `ai-orchestration.instructions.md` — Tool selection, progress cadence, validation.
  - `backend.instructions.md` — Backend development conventions.
  - `ci-cd-devops.instructions.md` — CI/CD pipeline standards and practices.
  - `clean-architecture-code.instructions.md` — Universal Clean Architecture principles.
  - `copilot-instruction-creation.instructions.md` — Rules to author/edit instruction files.
  - `database.instructions.md` — Database design and performance guidance.
  - `docker.instructions.md` — Containerization best practices.
  - `dotnet-csharp.instructions.md` — .NET/C# specific conventions and patterns.
  - `e2e-testing.instructions.md` — E2E and integration testing guidance.
  - `effort-estimation-ucp.instructions.md` — Estimation guidance (UCP).
  - `feedback-changelog.instructions.md` — Feedback workflow and changelog guidelines.
  - `frontend.instructions.md` — Frontend performance and quality standards.
  - `k8s.instructions.md` — Kubernetes manifests and Helm best practices.
  - `microservices-performance.instructions.md` — Performance, caching and resiliency.
  - `orm.instructions.md` — ORM mapping and repository conventions.
  - `powershell-execution.instructions.md` — PowerShell execution and safety rules.
  - `pr.instructions.md` — Pull request structure and requirements.
  - `prompt-templates.instructions.md` — Prompt templates guidelines.
  - `readme.instructions.md` — README authoring rules.
  - `static-analysis-sonarqube.instructions.md` — Static analysis and quality gates.
  - `ui-ux.instructions.md` — UI/UX and accessibility standards.
  - `vue-quasar.instructions.md` — Vue + Quasar specific guidance.
  - `workflow-optimization.instructions.md` — Workflow and token efficiency rules.

- Templates (`templates/`):
  - `changelog-entry-template.md` — Changelog entry template.
  - `copilot-instruction-creation.instructions-template.md` — Instruction authoring template.
  - `docker-compose-template.yml` — Docker Compose base template.
  - `dotnet-class-template.cs` — .NET class with XML docs.
  - `dotnet-dockerfile-template` — .NET Dockerfile base template.
  - `dotnet-integration-test-template.cs` — .NET integration test template.
  - `dotnet-interface-template.cs` — .NET interface template.
  - `dotnet-unit-test-template.cs` — .NET unit test template.
  - `effort-estimation-poc-mvp-template.md` — Effort estimation (POC/MVP) template.
  - `github-change-checklist-template.md` — Checklist for changes in this repo.
  - `readme-template.md` — Standard README template.

- VS Code folder (`.vscode/`):
  - `snippets/copilot.code-snippets` — Custom instructions, commit/PR guidance, applied instructions block, quality gates, progress update, changelog entry, README mapping row.
  - `snippets/codex-cli.code-snippets` — Codex safe command; orchestration decision; task snippets (backend, frontend, ui-ux, infra, db, testing, readme, prompt, k8s, docker, ci-cd, sonar, performance, e2e, orm, ps, instruction, PR).
  - `settings.json` — Workspace settings.

### Changed
- Standardized snippet texts to English.
- Updated paths to match repo structure (`instructions/`, `templates/`); removed obsolete `.github/` references.
- Enforced mandatory context for Copilot (AGENTS.md, `copilot-instructions.md`, core instructions).
- Fixed minor validation issues (backticks, descriptions).