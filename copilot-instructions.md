Language: EN for code/commits; pt-BR UI via i18n; EN database schema.

Hierarchy and scope:
- Global rules live here and are always applied.
- Domain instruction files extend these rules; do not duplicate globals.
- Prefer the most specific domain rule when conflicts occur.
- Map and reference new instruction files here.

CONTEXT SELECTION (hard rule):
- Always load these two files FIRST for any Copilot Chat session, patch proposal, PR summary, or code-gen in this repo:
  1. .github/copilot-instructions.md
  2. .github/AGENTS.md
- If context budget is limited, drop any other files before these. Do not answer without these two when the workspace is available.

Workflow (how to use):
- Start with AGENTS.md for solution-specific details (stack, folders, commands).
- Use this file for global rules and technology mappings.
- Follow domain-specific files in .github/instructions/*.md for technical details.

MANDATORY (always applied):
- .github/instructions/workflow-optimization.instructions.md
- .github/instructions/powershell-execution.instructions.md
- .github/instructions/feedback-changelog.instructions.md
- .github/AGENTS.md (agents and context policy)

MANDATORY (only for .github changes):
- .github/instructions/copilot-instruction-creation.instructions.md

DOMAIN INSTRUCTIONS (what to follow):
- C#/.NET: .github/instructions/dotnet-csharp.instructions.md (e.g., namespaces, sealed classes, XML docs).
- Architecture and backend: .github/instructions/clean-architecture-code.instructions.md; .github/instructions/backend.instructions.md (e.g., CQRS, mediator patterns).
- Frontend and UI/UX: .github/instructions/frontend.instructions.md; .github/instructions/vue-quasar.instructions.md; .github/instructions/ui-ux.instructions.md (e.g., i18n pt-BR, responsive design).
- Data/ORM/Databases: .github/instructions/orm.instructions.md; .github/instructions/database.instructions.md (e.g., EF Core, migrations).
- Microservices and performance: .github/instructions/microservices-performance.instructions.md (e.g., async patterns, caching).
- Infrastructure and DevOps: .github/instructions/docker.instructions.md; .github/instructions/k8s.instructions.md; .github/instructions/ci-cd-devops.instructions.md; .github/instructions/static-analysis-sonarqube.instructions.md (e.g., pipelines, security scans).
- E2E testing: .github/instructions/e2e-testing.instructions.md (e.g., Playwright, test categories).
- Documentation and processes: .github/instructions/readme.instructions.md; .github/instructions/pr.instructions.md; .github/instructions/prompt-templates.instructions.md; .github/instructions/effort-estimation-ucp.instructions.md (e.g., README creation with template, PR guidelines, changelog versioning).

TRANSPARENCY (pragmatic use):
- List applied instructions only when there are relevant actions (plans, command executions, patches/file changes).
- Use a short preamble to indicate key instructions before tool/command calls; omit in purely informational answers.
- For auditing, consolidate the full list of instructions in PR/commit body or CHANGELOG.md.
- When requested, include an Applied instructions section with the actually used set.

SECURITY:
- No secrets in repo; use User Secrets/Azure Key Vault; typed options via IOptions.

CHANGELOG:
- .github changes: versioned CHANGELOG.md
- Project changes: main CHANGELOG.md
- Process: .github/instructions/feedback-changelog.instructions.md
- Mandatory versioning: every CHANGELOG entry must include semantic version [X.Y.Z] and date YYYY-MM-DD; no [Unreleased] accumulation; immediate versioning on changes.