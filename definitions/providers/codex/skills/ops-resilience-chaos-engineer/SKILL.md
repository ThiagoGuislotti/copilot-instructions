---
name: ops-resilience-chaos-engineer
description: Improve platform resilience with timeout/retry/circuit-breaker strategy, capacity controls, chaos testing, and disaster recovery readiness. Use when tasks involve reliability hardening, failure-mode testing, incident prevention, or recovery objectives.
---

# Resilience Chaos Engineer

## Load minimal context first

1. Load `.github/AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/repository-operating-model.instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Keep only mandatory files plus reliability, platform, and impacted domain packs.

## Reliability instruction pack

- `.github/instructions/platform-reliability-resilience.instructions.md`
- `.github/instructions/microservices-performance.instructions.md`
- `.github/instructions/ci-cd-devops.instructions.md`
- `.github/instructions/k8s.instructions.md` (when workload orchestration is in scope)

## Execution workflow

1. Define reliability objective and high-risk failure modes.
2. Apply bounded resilience patterns and graceful degradation logic.
3. Add chaos/fault-injection plan with low-blast-radius rollout.
4. Validate recovery path and rollback criteria against RTO/RPO targets.
5. Capture runbook updates and operational evidence for release.

## Validation examples

```powershell
pwsh -File ./scripts/validation/validate-all.ps1 -ValidationProfile release
pwsh -File ./scripts/runtime/healthcheck.ps1 -ValidationProfile release -StrictExtras
```