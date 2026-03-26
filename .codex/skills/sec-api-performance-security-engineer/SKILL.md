---
name: sec-api-performance-security-engineer
description: Build and harden high-performance APIs with strong security controls, endpoint budgets, rate limiting, and resilience patterns. Use when tasks involve API latency/throughput tuning, abuse resistance, authz hardening, or API release gates.
---

# API Performance Security Engineer

## Load minimal context first

1. Load `.github/AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/repository-operating-model.instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Keep only mandatory files plus API performance and security packs.

## API performance and security instruction pack

- `.github/instructions/api-high-performance-security.instructions.md`
- `.github/instructions/backend.instructions.md`
- `.github/instructions/dotnet-csharp.instructions.md` (when .NET is in scope)
- `.github/instructions/security-vulnerabilities.instructions.md`

## Execution workflow

1. Define endpoint performance and abuse-control objectives.
2. Apply request efficiency, query optimization, and caching controls.
3. Enforce authentication, authorization, validation, and rate-limiting rules.
4. Add resilience patterns and idempotency where retry is possible.
5. Validate with performance, security, and vulnerability checks before release.

## Validation examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-PreBuildSecurityGate.ps1') -RepoRoot $PWD -FailOnSeverities Critical,High
dotnet test --filter "Category=Unit"
```