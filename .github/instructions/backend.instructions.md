---
applyTo: "**/*.{cs,js,ts,py,java,go,rs}"
---
Clean: pure Domain rules; Application orchestrates; Infrastructure adapts; API exposes; simplicity first; avoid over-engineering.
Example: Domain → OrderService validates business rules; Application → OrderHandler orchestrates; Infrastructure → OrderRepository persists; API → OrdersController exposes endpoint

CQRS: separate read/write; cohesive handlers; idempotency when needed; apply only when complexity justifies.
Example: Command → CreateOrderHandler; Query → GetOrderByIdHandler

Events: domain/integration events + Outbox; idempotent consumers; DLQ for queues; avoid unnecessary event sourcing.
Example: OrderCreatedEvent stored in Outbox; Consumer with retry + DLQ

Contracts/Errors: versioned REST; consistent paging/filters; RFC 7807 (ProblemDetails) with correlationId.
Example: GET /v1/orders?page=1&pageSize=20 → {"type":"about:blank","title":"Invalid request","status":400,"detail":"name is required","instance":"/v1/orders","extensions":{"correlationId":"<uuid>"}}

Resilience: HTTP with timeout, retry (jitter), circuit breaker, bulkhead; always CancellationToken (or equivalent); implement gradually as needed.
Example: HttpClientFactory with Polly AddTransientHttpErrorPolicy → WaitAndRetryAsync with jitter

Data: transactions per use case; repositories via interfaces; projections; indexes/constraints; cache with clear invalidation.
Example: IOrderRepository.SaveAsync() with TransactionScope; unique index on Email; Redis cache with explicit expiration

Security: input validation; JWT/OIDC; policies/roles; minimal CORS; secrets in secure store.
Example: [Authorize(Policy="Admin")] on Controller; secret loaded from AWS Secrets Manager or Azure Key Vault

Observability: OpenTelemetry (traces/metrics/logs); structured logs; health checks; readiness/liveness probes.
Example: ActivitySource for OrderService; HealthCheck endpoints "/health/ready" and "/health/live"

Performance: async all the way; pooling; batch/bulk where it fits; bounded I/O concurrency; optimize only identified bottlenecks.
Example: await dbContext.Orders.ToListAsync(); SqlBulkCopy for batch import

API: rate limiting/quotas on sensitive endpoints.
Example: Response headers → X-RateLimit-Limit:100; X-RateLimit-Remaining:42; Retry-After:30

Testing: domain (unit), integrations (DB/HTTP), contract (OpenAPI/Pact), critical E2E; Testcontainers/localstack.
Example: xUnit for domain logic; Pact tests against partner API; Testcontainers for local SQL Server

CI/CD: build/test/scan (SAST/secrets); immutable artifacts; automatable migrations; feature flags.
Example: pipeline → dotnet build; dotnet test; trivy scan; generate immutable Docker image; apply EF Core migrations automatically on deploy

Anti-patterns: avoid complex patterns without justification; YAGNI; start simple and evolve; refactor when real pain emerges.
Example: do not implement Event Sourcing if simple CRUD suffices; introduce only when a real requirement emerges