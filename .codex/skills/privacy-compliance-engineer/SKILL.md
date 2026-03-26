---
name: privacy-compliance-engineer
description: Design and enforce privacy and data protection controls across application, API, and database layers. Use when tasks involve PII handling, retention/deletion policies, consent, data minimization, auditability, or compliance-oriented architecture changes.
---

# Privacy Compliance Engineer

## Load minimal context first

1. Load `.github/AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/repository-operating-model.instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Keep only mandatory files plus privacy and impacted domain packs.

## Privacy instruction pack

- `.github/instructions/data-privacy-compliance.instructions.md`
- `.github/instructions/security-vulnerabilities.instructions.md`
- `.github/instructions/database.instructions.md` (when data schema/queries are in scope)
- `.github/instructions/backend.instructions.md` (when API/service logic is in scope)

## Execution workflow

1. Identify personal data classes, flows, and processing purpose.
2. Apply minimization, masking, encryption, and least-privilege controls.
3. Define retention and deletion behavior with auditable evidence.
4. Add privacy-focused tests for tenant isolation and sensitive-data leakage.
5. Report residual compliance risks with explicit owners and deadlines.

## Validation examples

```powershell
pwsh -File ./scripts/validation/validate-security-baseline.ps1
pwsh -File ./scripts/validation/validate-release-provenance.ps1
```