---
applyTo: "**/*.{cs,ts,js,json,yml,yaml,md,toml}"
priority: high
---

# Observability and SRE Baseline
- Use this instruction when designing runtime telemetry, reliability operations, incident response, and service-level objectives.
- Treat observability as a product requirement; every critical user flow must be measurable end-to-end.

# SLO and Error Budget
- Define SLI and SLO per critical journey using explicit targets for availability, latency, and correctness.
- Track error budget consumption and use it to gate release risk and change velocity.
- Prefer a small set of business-aligned SLOs over large metric catalogs with low actionability.

# Telemetry Design
- Adopt OpenTelemetry standards for traces, metrics, and logs across services and async boundaries.
- Propagate correlation identifiers and trace context through HTTP, messaging, jobs, and batch pipelines.
- Emit structured logs with stable fields and severity semantics; avoid free-text only logging.
- Ensure every metric has clear unit, owner, and operational purpose.

# Metrics Quality
- Instrument golden signals first: latency, traffic, errors, saturation.
- Control cardinality for labels and dimensions to avoid storage and query cost explosions.
- Prefer histograms and percentile-friendly metrics for latency objectives.
- Separate technical metrics from product metrics and connect both through shared context fields.

# Alerting and Incident Response
- Use multi-window, multi-burn-rate alerting for SLO-backed incidents.
- Configure alerts to be actionable with runbook links, ownership, and expected first response.
- Avoid noisy threshold-only alerts without clear incident semantics.
- Define incident severity levels, communication channels, escalation paths, and handoff protocol.

# Dashboard and Runbook Standards
- Maintain service dashboards with request rates, error rates, percentile latencies, dependency health, and resource saturation.
- Keep runbooks versioned with deterministic diagnosis and mitigation steps.
- Include rollback strategy, feature-flag strategy, and verification checklist in runbooks.

# Health and Probes
- Separate readiness and liveness probes with explicit dependency semantics.
- Ensure readiness reflects real dependency availability and startup state.
- Keep liveness checks lightweight and isolated from downstream dependency failures when possible.

# Reliability Operations
- Track MTTR, MTTD, change failure rate, and deployment frequency as core operational KPIs.
- Require post-incident reviews with corrective actions, ownership, and due dates.
- Convert repeated incident classes into preventive engineering backlog items.

# Security and Compliance in Telemetry
- Never log secrets, credentials, tokens, or sensitive personal data.
- Apply data minimization and redaction policies to logs, traces, and error payloads.
- Define retention windows and access controls for telemetry stores.

# Verification and Release Gates
- Validate telemetry coverage for new endpoints, background jobs, and integration points.
- Require synthetic checks or smoke checks for critical public entrypoints.
- For high-risk changes, require observability evidence before and after rollout.