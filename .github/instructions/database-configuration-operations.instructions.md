---
applyTo: "**/*{database,db,connection,appsettings,migration,infrastructure}*.{cs,sql,json,yaml,yml,env,md}"
priority: high
---

# Database Configuration and Operations Baseline
- Use this instruction when configuring runtime database access, connection settings, failover, or operational database policies.
- Prioritize secure-by-default settings, deterministic performance, and recoverability under real production load.

# Environment and Configuration Source of Truth
- Keep database settings environment-specific and externalized (local, staging, production).
- Maintain a single typed configuration contract for each service; avoid ad-hoc config reads.
- Keep configuration keys stable across environments; only values change.
- Do not hardcode connection strings, passwords, certificates, or provider credentials.

# Connection String and Secret Management
- Store credentials in managed secret stores; inject at runtime with least privilege.
- Enforce TLS/SSL in all non-local environments.
- Disable trust-on-first-use defaults; require explicit certificate validation where supported.
- Include application/service name in connection metadata for traceability.
- Separate read/write/admin credentials and rotate each on independent schedules.

# Provider Baselines
- SQL Server baseline:
  - `Encrypt=True`
  - `TrustServerCertificate=False`
  - `MultiSubnetFailover=True` when applicable
  - Explicit `Connect Timeout` and command timeout defaults
- PostgreSQL baseline:
  - `SSL Mode=Require` (or stronger policy)
  - `Trust Server Certificate=false` outside controlled local development
  - Explicit `Timeout`, `Command Timeout`, and `Keepalive`
- MySQL baseline:
  - `SslMode=Required`
  - Explicit `ConnectionTimeout` and `DefaultCommandTimeout`
  - Explicit character set/collation strategy where relevant

# Pooling and Timeout Policy
- Enable pooling with explicit min/max bounds; never rely on unknown runtime defaults in production.
- Define `MinPoolSize` and `MaxPoolSize` per service profile and expected concurrency.
- Set command timeout by endpoint/query class, not a single global extreme value.
- Bound concurrent database calls at application layer to avoid pool starvation.
- Fail fast on acquisition timeouts and surface clear diagnostics.

# Resilience, Failover, and Replicas
- Configure retry with jitter only for transient and idempotent operations.
- Keep retry counts bounded and aligned with total timeout budgets.
- Use read replicas only for read paths that tolerate replica lag.
- Define explicit failover behavior (automatic/manual), owner, and runbook steps.
- Test failover paths periodically with production-like traffic patterns.

# Migrations and Zero-Downtime Change Policy
- Apply expand/migrate/contract for breaking schema evolution.
- Keep migrations forward-only and idempotent where deployment model requires re-entry.
- Gate destructive operations (drop/rename/type narrowing) behind phased rollout and compatibility checks.
- Validate migration runtime on realistic datasets before production.
- Record rollback/mitigation strategy per migration set.

# Backup, Restore, and DR Operations
- Define backup cadence per criticality tier and validate encryption at rest/in transit.
- Test point-in-time recovery on a fixed schedule with evidence retention.
- Define and monitor RTO/RPO objectives per service.
- Verify restore procedures include replicas, dependent jobs, and secret/key recovery paths.
- Keep disaster recovery runbooks versioned and reachable during incidents.

# Multi-Tenant and Data Isolation Configuration
- Define tenant isolation model explicitly (database-per-tenant, schema-per-tenant, shared schema with policy controls).
- Enforce tenant scoping at query, repository, and API authorization layers.
- Prevent cross-tenant joins/exports unless explicitly authorized and audited.
- Validate tenant isolation with automated integration tests.

# Observability and Operational Alerts
- Emit metrics for pool usage, connection wait, timeout rate, retry rate, deadlocks, and replication lag.
- Define actionable alert thresholds and ownership for each metric.
- Correlate database telemetry with request/trace identifiers.
- Track slow queries with normalized signatures and regression history.

# Validation Checklist for Delivery
- Connection security is enforced and secrets are externalized.
- Pool/timeouts are explicitly configured and load-tested.
- Failover/replica behavior is documented and tested.
- Migration strategy is zero-downtime compatible for the current release model.
- Backup/restore evidence satisfies defined RTO/RPO.
- Observability dashboards and alerts are active for DB runtime signals.