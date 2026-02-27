# Global Instructions

Language: pt-BR for chat; EN for code/commits/docs/UI/database; pt-BR i18n output.

# Language Policy
- Chat/Conversation: pt-BR (Portuguese) - all responses to user in chat
- Code/Commits/Docs: EN (English) - all technical content
- UI: EN (English) keys/structure; pt-BR translations via i18n for end users
- Database: EN (English) - schema, table names, column names

# Hierarchy and Scope
- Global rules live here and are always applied.
- Domain instruction files extend these rules; do not duplicate globals.
- Prefer the most specific domain rule when conflicts occur.
- Map and reference new instruction files here.

# Context Selection

## Hard rule
- Always load `AGENTS.md` first, then this file.
- If the workspace is available, do not proceed unless both files are loaded.

# Static RAGs Routing
Preferred default workflow: **Route → Execute** (always route first to generate a minimal Context Pack).

Use static routing when you want consistent instruction selection without running any external service.

Flow (two-stage):
1) Route: Use instruction-routing.catalog.yml + prompts/route-instructions.prompt.md to produce a Context Pack (mandatory + minimal domain files).
2) Execute: Perform the actual task using ONLY the Context Pack files as context.

Rules:
- Always include mandatory context (AGENTS.md + this file) and mandatory instruction files.
- Prefer 2–5 domain instruction files per task.
- If ambiguous, ask up to 3 clarifying questions before executing.

## Decision Quickstart (Instruction Hierarchy)

Follow this order of operations on every task:

1) Read the user request and identify the target area
- `.github/**` (policies, prompts, instructions)
- Code workspace (C#, Rust, TS/JS, etc.)
- Build/CI/CD/infra (pipelines, Docker, Kubernetes)

2) Apply instructions in this precedence order
- User prompt (explicit constraints)
- `AGENTS.md` + this file
- Domain instruction files under `instructions/` (pick by language/folder)
- Any additional, file-scoped instructions (e.g., `instructions/copilot-instruction-creation.instructions.md` when editing `instructions/*`)

3) Resolve conflicts
- More specific scope wins (narrower `applyTo` beats broader)
- Prefer safer/minimal changes when ambiguous, and ask 1–3 clarifying questions if needed

# Workflow

## How to use
- Start with AGENTS.md for solution-specific details (stack, folders, commands).
- Use this file for global rules and technology mappings.
- Follow domain-specific files in instructions/*.md for technical details.

# Mandatory Instructions

## Always Applied
- AGENTS.md (agents and context policy)
- instructions/workflow-optimization.instructions.md
- instructions/powershell-execution.instructions.md
- instructions/feedback-changelog.instructions.md

## Only for .github Changes
- instructions/copilot-instruction-creation.instructions.md

# Domain Instructions

## Development
- C#/.NET: instructions/dotnet-csharp.instructions.md (e.g., namespaces, sealed classes, XML docs).
- Architecture and backend: instructions/clean-architecture-code.instructions.md; instructions/backend.instructions.md (e.g., CQRS, mediator patterns).
- Frontend and UI/UX: instructions/frontend.instructions.md; instructions/vue-quasar.instructions.md; instructions/vue-quasar-architecture.instructions.md; instructions/ui-ux.instructions.md (e.g., i18n pt-BR, responsive design, feature-first Clean Architecture).

## Data and Infrastructure
- Data/ORM/Databases: instructions/orm.instructions.md; instructions/database.instructions.md (e.g., EF Core, migrations).
- Microservices and performance: instructions/microservices-performance.instructions.md (e.g., async patterns, caching).
- Infrastructure and DevOps: instructions/docker.instructions.md; instructions/k8s.instructions.md; instructions/ci-cd-devops.instructions.md; instructions/static-analysis-sonarqube.instructions.md (e.g., pipelines, security scans).
- Security and vulnerabilities: instructions/security-vulnerabilities.instructions.md (e.g., OWASP/NIST-aligned controls for API, frontend, backend, database).
- Dependency vulnerability automation scripts (shared runtime): ~/.codex/shared-scripts/security/Invoke-PreBuildSecurityGate.ps1; ~/.codex/shared-scripts/security/Invoke-VulnerabilityAudit.ps1; ~/.codex/shared-scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1; ~/.codex/shared-scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1.
- PowerShell script authoring: instructions/powershell-script-creation.instructions.md (e.g., script skeleton, root detection, mutation safety, exit codes).

## Testing and Documentation
- Rust organization and testing: instructions/rust-code-organization.instructions.md (e.g., mirror src/ structure, no inline tests, test_suite.rs entry point); instructions/rust-testing.instructions.md (e.g., error_tests.rs mandatory, coverage requirements, templates).
- E2E testing: instructions/e2e-testing.instructions.md (e.g., Playwright, test categories).
- Documentation and processes: instructions/readme.instructions.md; instructions/pr.instructions.md; instructions/prompt-templates.instructions.md; instructions/effort-estimation-ucp.instructions.md (e.g., README creation with template, PR guidelines, changelog versioning).

# Transparency

## Pragmatic use
- List applied instructions only when there are relevant actions (plans, command executions, patches/file changes).
- Use a short preamble to indicate key instructions before tool/command calls; omit in purely informational answers.
- For auditing, consolidate the full list of instructions in PR/commit body or CHANGELOG.md.
- When requested, include an Applied instructions section with the actually used set.

# Security
- No secrets in repo; use User Secrets/Azure Key Vault; typed options via IOptions.

# Changelog
- Single source: root CHANGELOG.md for .github and project changes
- Process: instructions/feedback-changelog.instructions.md
- Mandatory versioning: every CHANGELOG entry must include semantic version [X.Y.Z] and date YYYY-MM-DD; no [Unreleased] accumulation; immediate versioning on changes.
- Release tagging for rollback: after commit, create and push matching tag `copilot-vX.Y.Z` (for example: `git tag -a copilot-v1.1.3 -m "copilot instructions 1.1.3"` and `git push origin copilot-v1.1.3`).

# STYLE (EOF and whitespace)
- Do not leave a trailing blank line at the end of files.
- For files under `instructions/*.md` and Copilot/Codex instruction outputs: do NOT include a final newline (consistent with AGENTS.md).
- For other files, follow `.editorconfig` rules (final newline usually enforced); always avoid trailing whitespace.