---
applyTo: ".github/**"
---

# Pull Request Goals
Pull Request goals: clear title with concise scope; English language for title/description; reference related issues (e.g., Fixes #123); small, focused changes; align with repository guidelines.

# Structure
Title [type: scope] short summary; Description with Context | Changes | Rationale | Risks | Testing | Docs | Breaking Changes | Migration; include Applied instructions section listing the instruction files actually followed.

# Title Format
- Use imperative mood
- Keep <= 72 chars
- Include area prefix when helpful (e.g., Core, Tools, Samples)
- Avoid redundant words
- Prefer clarity over cleverness
```markdown
[fix: backend] Add exponential retry with jitter to HttpClientFactory
[feat: database] Add keyset pagination and missing indexes
[chore: infra] Harden Dockerfile and add readiness probe
```

# Description Content
Context (what/why); Changes (what changed at code/infra level); Rationale (why this approach); Risks (impact/mitigations); Testing (how validated: unit/integration/E2E); Docs (README/CHANGELOG updated); Breaking Changes (yes/no and details); Migration (steps if any).
```markdown
Context: users face transient 502/504
Changes: add Polly WaitAndRetry with jitter to HttpClientFactory
Rationale: improve resilience per backend.instructions.md
Risks: excessive retries mitigated by maxAttempts=3 and timeout
Testing: unit tests added + integration smoke
Docs: CHANGELOG updated
Breaking Changes: no
Migration: none
```

# Applied Instructions
List paths like .github/instructions/backend.instructions.md; .github/instructions/dotnet-csharp.instructions.md; summarize how each was applied; include any deviations and justification.
```markdown
Applied instructions:
- .github/instructions/backend.instructions.md
- .github/instructions/dotnet-csharp.instructions.md
- .github/instructions/ci-cd-devops.instructions.md
Applied: resilience (retry/jitter), CancellationToken, tests and pipeline gates
Deviations: none
```

# Quality Checklist
- Build and tests pass
- Lints/formatting clean
- Security checks considered
- No secrets in diff
- Performance implications reviewed
- Consistent namespaces and folder structure
- UTF-8 without BOM
- No trailing blank line at EOF in modified files

# Review Etiquette
Request specific reviewers; be responsive to feedback; keep discussion focused on scope; update PR incrementally; squash or tidy commits if noise is high; maintain clear commit messages in English.

# Labels and Metadata
Add labels (area, type, priority); link to milestone if applicable; ensure CI status visible; attach artifacts when useful (screenshots, metrics, logs).
```markdown
Labels: area-backend; type-fix; priority-medium
Reviewers: alice,bob
Milestone: 2025-Q1
CI: green
Artifacts: test results attached
```