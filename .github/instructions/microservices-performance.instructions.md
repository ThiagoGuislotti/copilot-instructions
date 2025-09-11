---
applyTo: "**/microservice*/**/*.{cs,ts,js,json,yml,yaml,config,dockerfile}"
---
Service boundaries: single responsibility; domain‑driven boundaries; database per service; prefer async communication; event‑driven architecture; saga for distributed transactions; API gateway as entry point.
Performance: configured connection pooling; consistent async/await; bulk operations; appropriate lazy loading; distributed cache (Redis); CDN for assets; compression enabled.
Resource efficiency: minimal images; multi‑stage builds; defined resource limits; accurate CPU/memory requests; HPA/VPA; tuned probes.
Communication: gRPC for service‑to‑service; REST for external APIs; message queues for async; circuit breaker; retries with exponential backoff; timeouts; idempotent operations.
Consistency: eventual consistency by default; CQRS when applicable; event sourcing for audit; saga orchestration; compensation patterns; avoid distributed transactions; optimized read models.
Caching: application cache; distributed cache; cache‑aside; write‑through when needed; proper TTL; invalidation; warming; hierarchy.
Load balancing: round‑robin default; health‑based routing; session affinity when needed; geo routing; A/B testing; canary; blue‑green.
Monitoring: structured logs; correlation IDs; metrics aggregation; tracing; SLA monitoring; error rate; latency percentiles; resource utilization.
Security performance: JWT validation; optimized OAuth2 flows; per‑service rate limiting; API key caching; certificate rotation; secrets management; network policies.
Database: read replicas; pooling; query optimization; indexes; partitioning when needed; archiving; DB monitoring; slow query detection.
Messaging: batch processing; parallel consumers; DLQ; deduplication; poison message handling; backpressure; consumer scaling.
Memory: object pooling; dispose patterns; weak refs; GC tuning; profiling; leak detection; memory limits; streaming large data.
Network: connection reuse; compression; binary protocols; payload optimization; bandwidth monitoring; partition handling; edge caching.
Service discovery: health checks; graceful shutdown; registration; load balancer integration; DNS discovery; service mesh when applicable; failover.
Deployment: rolling updates; zero‑downtime; config management; environment parity; IaC; automated rollbacks; deploy monitoring.