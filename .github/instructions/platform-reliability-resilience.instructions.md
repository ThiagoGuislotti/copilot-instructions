---
applyTo: "**/*.{cs,ts,js,json,yml,yaml,toml,md,ps1}"
priority: high
---

# Platform Reliability and Resilience Baseline
- Use this instruction for reliability architecture, resilience patterns, failure testing, and disaster readiness.
- Design for graceful degradation under dependency failure and traffic volatility.

# Reliability Objectives
- Define reliability targets with explicit availability and recovery objectives.
- Track error budget consumption and prioritize reliability work when budget burn is high.
- Set recovery objectives for business-critical services and supporting dependencies.

# Resilience Patterns
- Apply explicit timeout budgets for all outbound calls and long-running operations.
- Use retry with jitter only for transient failure classes and bounded retry counts.
- Isolate unstable dependencies with circuit breakers, bulkheads, and concurrency limits.
- Implement backpressure and load-shedding to protect core system health under overload.
- Prefer idempotent operations and deduplication for retried workflows.

# Graceful Degradation
- Define fallback behavior per dependency when upstream/downstream systems are degraded.
- Keep core user journeys available by reducing non-critical features during incidents.
- Expose degraded-mode indicators for operators and clients when behavior changes.

# Capacity and Scaling
- Model peak load, sustained load, and burst load with explicit headroom policy.
- Define autoscaling policies with saturation signals and cooldown safeguards.
- Validate queue depth, worker concurrency, and drain times for asynchronous pipelines.

# Chaos Engineering and Fault Injection
- Run controlled fault-injection experiments for critical dependency and network failure modes.
- Start with low blast-radius experiments and progressive coverage expansion.
- Convert failed experiments into backlog actions with owner and due date.
- Keep experiment hypotheses and success criteria explicit and measurable.

# Disaster Recovery and Continuity
- Define RTO and RPO per critical service and data domain.
- Test backup restore, failover, and rollback procedures on a fixed schedule.
- Validate runbooks in realistic environments, not only tabletop reviews.
- Keep dependency maps updated for recovery orchestration.

# Deployment Safety
- Use progressive delivery strategies such as canary, blue-green, or phased rollout.
- Gate rollout with health, error, and latency signals tied to rollback rules.
- Automate rollback for severe regressions when signal confidence is high.

# Observability for Reliability
- Instrument request outcomes, retries, breaker states, queue backlog, and saturation.
- Maintain dashboards and alerts aligned to reliability objectives and on-call workflows.
- Ensure every critical alert points to an actionable runbook.

# Operational Readiness
- Maintain incident command protocol and role assignments.
- Record post-incident corrective actions and verify closure with evidence.
- Track recurring failure patterns and eliminate single points of failure.