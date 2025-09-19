---
applyTo: ".github/**"
---

Pull Request goals: clear title with concise scope; English language for title/description; reference related issues (e.g., Fixes #123); small, focused changes; align with repository guidelines.

Structure: Title [type: scope] short summary; Description with Context | Changes | Rationale | Risks | Testing | Docs | Breaking Changes | Migration; include Applied instructions section listing the instruction files actually followed.

Title: use imperative mood; keep <= 72 chars; include area prefix when helpful (e.g., Core, Tools, Samples); avoid redundant words; prefer clarity over cleverness.
Example: Title [fix: backend] Add exponential retry with jitter to HttpClientFactory
Example: Title [feat: database] Add keyset pagination and missing indexes
Example: Title [chore: infra] Harden Dockerfile and add readiness probe

Description content: Context (what/why); Changes (what changed at code/infra level); Rationale (why this approach); Risks (impact/mitigations); Testing (how validated: unit/integration/E2E); Docs (README/CHANGELOG updated); Breaking Changes (yes/no and details); Migration (steps if any).
Example: Description Context: users face transient 502/504; Changes: add Polly WaitAndRetry with jitter to HttpClientFactory; Rationale: improve resilience per backend.instructions.md; Risks: excessive retries mitigated by maxAttempts=3 and timeout; Testing: unit tests added + integration smoke; Docs: CHANGELOG updated; Breaking Changes: no; Migration: none
Example: Description (Database/ORM) Context: slow list endpoint due to N+1 and table scans; Changes: switch to projection DTOs, add ix_Orders_CreatedAt, keyset pagination; Rationale: follow orm.instructions.md and database.instructions.md (SARGABLE, indexes, DTOs); Risks: index maintenance; Testing: integration tests + performance baseline; Docs: CHANGELOG; Breaking Changes: no; Migration: create index script
Example: Description (Infra) Context: pods restart due to missing probes and container runs as root; Changes: add readiness/liveness/startup probes, set runAsNonRoot, limit resources; Rationale: follow k8s.instructions.md; Testing: deploy to staging with health checks; Docs: CHANGELOG; Breaking Changes: no; Migration: apply manifests

Applied instructions: list paths like .github/instructions/backend.instructions.md; .github/instructions/dotnet-csharp.instructions.md; summarize how each was applied; include any deviations and justification.
Example: Applied instructions .github/instructions/backend.instructions.md; .github/instructions/dotnet-csharp.instructions.md; .github/instructions/ci-cd-devops.instructions.md; Applied: resilience (retry/jitter), CancellationToken, tests and pipeline gates; Deviations: none
Example: Applied instructions (Database/ORM) .github/instructions/orm.instructions.md; .github/instructions/database.instructions.md; .github/instructions/microservices-performance.instructions.md; Applied: projection DTOs, SARGABLE queries, composite index, keyset pagination; Deviations: none
Example: Applied instructions (Infra) .github/instructions/docker.instructions.md; .github/instructions/k8s.instructions.md; .github/instructions/ci-cd-devops.instructions.md; .github/instructions/static-analysis-sonarqube.instructions.md; Applied: non-root Docker image, probes, resource limits, pipeline stage checks, quality gate; Deviations: none

Quality checklist: build and tests pass; lints/formatting clean; security checks considered; no secrets in diff; performance implications reviewed; consistent namespaces and folder structure; UTF-8 without BOM; no trailing blank line at EOF in modified files.
Example: Quality checklist Build/tests pass; lint/format clean; no secrets; performance OK; namespaces/folders consistent; UTF-8 without BOM; no trailing blank line in modified files

Review etiquette: request specific reviewers; be responsive to feedback; keep discussion focused on scope; update PR incrementally; squash or tidy commits if noise is high; maintain clear commit messages in English.

Labels and metadata: add labels (area, type, priority); link to milestone if applicable; ensure CI status visible; attach artifacts when useful (screenshots, metrics, logs).
Example: Labels and metadata Labels: area-backend; type-fix; priority-medium; Reviewers: alice,bob; Milestone: 2025-Q1; CI: green; Artifacts: test results attached