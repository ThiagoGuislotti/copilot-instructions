---
applyTo: "**/*.{cs,http,json,yml,yaml,ts,js,sql,md}"
priority: high
---

# API High Performance and Security Baseline
- Use this instruction for API design and implementation with strict focus on throughput, low latency, and abuse-resistant security.
- Prefer deterministic behavior under load and explicit protection against abusive traffic patterns.

# Performance Objectives
- Define explicit API performance targets per endpoint class; include p95 and p99 latency objectives and throughput targets.
- Set endpoint-level budgets for CPU time, query cost, payload size, and downstream call count.
- Measure performance with representative data volumes and realistic concurrency.

# Request and Response Efficiency
- Keep payloads minimal; avoid over-fetching and unnecessary nested graphs.
- Enforce pagination, filtering, sorting, and projection for collection endpoints.
- Use compression when payload size justifies cost; validate client compatibility.
- Prefer streaming for large result sets and long-running exports.

# Database and Query Performance
- Use parameterized queries and indexed access paths for critical endpoints.
- Eliminate N+1 query patterns and unbounded scans on hot paths.
- Define query timeout budgets and cancellation propagation.
- Use read replicas, cache layers, or precomputed views for read-heavy workloads when justified.

# Caching Strategy
- Apply cache-control semantics for safe cacheable responses.
- Use cache-aside or response caching for high-read endpoints with explicit invalidation policy.
- Define TTL based on data volatility and business correctness requirements.

# Rate Limiting and Abuse Protection
- Enforce rate limits by endpoint sensitivity, identity, tenant, and IP context.
- Use token bucket or sliding window policies with deterministic retry semantics.
- Return consistent throttling responses with Retry-After and quota metadata when applicable.
- Add request size limits, header limits, and body depth limits to reduce DoS risk.

# Authentication and Authorization
- Require strong authentication and validate token issuer, audience, expiry, and scopes.
- Enforce object-level and function-level authorization on every protected endpoint.
- Apply least-privilege access by role, policy, and tenant boundary.

# Input Validation and Output Safety
- Validate and normalize all untrusted input with schema and semantic rules.
- Reject unknown or unsafe fields for mutation endpoints when strict contracts are expected.
- Return errors using RFC 7807 ProblemDetails with traceable correlation identifiers.
- Avoid returning internal exception details or sensitive metadata.

# Resilience Patterns for APIs
- Set explicit timeouts per dependency and per request class.
- Use bounded retries with jitter for transient failures only.
- Apply circuit breaker and bulkhead isolation for unstable dependencies.
- Use idempotency keys for non-idempotent operations that can be retried by clients.

# Observability for API Performance and Security
- Emit endpoint metrics for request rate, status code class, p95/p99 latency, and throttling events.
- Track auth failures, authorization denials, and abuse-control triggers as first-class security metrics.
- Correlate logs, traces, and metrics with request identifiers and tenant/user context where permitted.

# Testing and Validation
- Include load tests and stress tests for critical endpoints before release.
- Add negative tests for rate limit behavior, payload limits, and authz bypass attempts.
- Validate OpenAPI contract compatibility and breaking-change policy in CI.
- Run dependency vulnerability gate before build/package using shared security scripts.