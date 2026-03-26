---
name: dev-software-engineer
description: Base implementation skill. Use for code changes, bug fixes, refactors, and script work across .NET/C#, backend APIs, database/ORM, Vue/Quasar frontend, Rust, PowerShell, Docker, K8s, CI/CD, security, observability, and SRE domains. Specialized skills extend this as a base.
---

# Dev Software Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`
4. Domain instruction pack selected via `.github/instruction-routing.catalog.yml`

## Domain instruction packs

Select based on target area. Load only the pack(s) relevant to the task.

### .NET / C# / Backend
- `.github/instructions/dotnet-csharp.instructions.md`
- `.github/instructions/clean-architecture-code.instructions.md`
- `.github/instructions/backend.instructions.md`
- `.github/instructions/api-high-performance-security.instructions.md`
- `.github/instructions/microservices-performance.instructions.md`
- `.github/instructions/nettoolskit-rules.instructions.md`

### Database / ORM
- `.github/instructions/database.instructions.md`
- `.github/instructions/orm.instructions.md`
- `.github/instructions/database-configuration-operations.instructions.md`

### Frontend / Vue / Quasar
- `.github/instructions/frontend.instructions.md`
- `.github/instructions/vue-quasar.instructions.md`
- `.github/instructions/vue-quasar-architecture.instructions.md`
- `.github/instructions/ui-ux.instructions.md`

### Rust
- `.github/instructions/rust-code-organization.instructions.md`
- `.github/instructions/rust-testing.instructions.md`

### PowerShell / Scripts
- `.github/instructions/powershell-execution.instructions.md`
- `.github/instructions/powershell-script-creation.instructions.md`

### Infrastructure / DevOps / CI-CD
- `.github/instructions/ci-cd-devops.instructions.md`
- `.github/instructions/docker.instructions.md`
- `.github/instructions/k8s.instructions.md`
- `.github/instructions/workflow-generation.instructions.md`

### Security / Compliance / Privacy
- `.github/instructions/security-vulnerabilities.instructions.md`
- `.github/instructions/data-privacy-compliance.instructions.md`

### Observability / SRE / Reliability
- `.github/instructions/observability-sre.instructions.md`
- `.github/instructions/platform-reliability-resilience.instructions.md`

### Testing
- `.github/instructions/tdd-verification.instructions.md`
- `.github/instructions/e2e-testing.instructions.md`
- `.github/instructions/static-analysis-sonarqube.instructions.md`

### Documentation / README / Changelog
- `.github/instructions/readme.instructions.md`
- `.github/instructions/feedback-changelog.instructions.md`
- `.github/instructions/effort-estimation-ucp.instructions.md`

### VS Code / Workspace
- `.github/instructions/vscode-workspace-efficiency.instructions.md`
- `.github/instructions/workflow-optimization.instructions.md`

### Orchestration / Instructions Authoring
- `.github/instructions/super-agent.instructions.md`
- `.github/instructions/brainstorm-spec-workflow.instructions.md`
- `.github/instructions/subagent-planning-workflow.instructions.md`
- `.github/instructions/worktree-isolation.instructions.md`
- `.github/instructions/artifact-layout.instructions.md`
- `.github/instructions/authoritative-sources.instructions.md`
- `.github/instructions/copilot-instruction-creation.instructions.md`
- `.github/instructions/prompt-templates.instructions.md`

### Pull Requests
- `.github/instructions/pr.instructions.md`

## Claude-native execution

- Run as a `general-purpose` agent within the Super Agent pipeline.
- Use worktree isolation for risky or large-scope changes (`.github/instructions/worktree-isolation.instructions.md`).

## Execution workflow

1. Define scope, constraints, and impacted modules.
2. Implement the smallest safe change that satisfies the request.
3. Preserve layer boundaries and dependency direction.
4. Add or update tests for changed behavior.
5. Run targeted validation before claiming completion.

## Prompt accelerators

- `.github/prompts/create-dotnet-class.prompt.md`
- `.github/prompts/create-api-endpoint.prompt.md`
- `.github/prompts/create-ef-migration.prompt.md`
- `.github/prompts/create-vue-component.prompt.md`
- `.github/prompts/create-rust-module.prompt.md`
- `.github/prompts/create-docker-setup.prompt.md`
- `.github/prompts/create-powershell-script.prompt.md`
- `.github/prompts/generate-unit-tests.prompt.md`
- `.github/prompts/refactor-to-clean-architecture.prompt.md`
- `.github/prompts/generate-changelog.prompt.md`
- `.github/prompts/generate-pr-description.prompt.md`