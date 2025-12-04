---
applyTo: "**/*.{cs,js,ts,py,java,go,rs}"
priority: medium
---

# Clean Architecture
- Pure Domain rules
- Application orchestrates
- Infrastructure adapts
- API exposes
- Simplicity first
- Avoid over-engineering
```csharp
// Domain → OrderService validates business rules
// Application → OrderHandler orchestrates
// Infrastructure → OrderRepository persists
// API → OrdersController exposes endpoint
```

# CQRS
- Separate read/write
- Cohesive handlers
- Idempotency when needed
- Apply only when complexity justifies
```csharp
// Command → CreateOrderHandler
// Query → GetOrderByIdHandler
```

# Events
- Domain/integration events + Outbox
- Idempotent consumers
- DLQ for queues
- Avoid unnecessary event sourcing
```csharp
// OrderCreatedEvent stored in Outbox
// Consumer with retry + DLQ
```

# Contracts/Errors
- Versioned REST
- Consistent paging/filters
- RFC 7807 (ProblemDetails) with correlationId
```json
{
  "type": "about:blank",
  "title": "Invalid request",
  "status": 400,
  "detail": "name is required",
  "instance": "/v1/orders",
  "extensions": { "correlationId": "<uuid>" }
}
```

# Resilience
- HTTP with timeout, retry (jitter), circuit breaker, bulkhead
- Always CancellationToken (or equivalent)
- Implement gradually as needed
```csharp
// HttpClientFactory with Polly AddTransientHttpErrorPolicy → WaitAndRetryAsync with jitter
```

# Data
- Transactions per use case
- Repositories via interfaces
- Projections
- Indexes/constraints
- Cache with clear invalidation
```csharp
// IOrderRepository.SaveAsync() with TransactionScope
// Unique index on Email
// Redis cache with explicit expiration
```

# Security
- Input validation
- JWT/OIDC
- Policies/roles
- Minimal CORS
- Secrets in secure store
```csharp
// [Authorize(Policy="Admin")] on Controller
// Secret loaded from AWS Secrets Manager or Azure Key Vault
```

# Observability
- OpenTelemetry (traces/metrics/logs)
- Structured logs
- Health checks
- Readiness/liveness probes
```csharp
// ActivitySource for OrderService
// HealthCheck endpoints "/health/ready" and "/health/live"
```

# Performance
- Async all the way
- Pooling
- Batch/bulk where it fits
- Bounded I/O concurrency
- Optimize only identified bottlenecks
```csharp
// await dbContext.Orders.ToListAsync()
// SqlBulkCopy for batch import
```

# API
- Rate limiting/quotas on sensitive endpoints
```http
X-RateLimit-Limit:100
X-RateLimit-Remaining:42
Retry-After:30
```

# Testing
- Domain (unit)
- Integrations (DB/HTTP)
- Contract (OpenAPI/Pact)
- Critical E2E
- Testcontainers/localstack
```csharp
// xUnit for domain logic
// Pact tests against partner API
// Testcontainers for local SQL Server
```

# CI/CD
- Build/test/scan (SAST/secrets)
- Immutable artifacts
- Automatable migrations
- Feature flags
```yaml
# Pipeline → dotnet build; dotnet test; trivy scan
# Generate immutable Docker image
# Apply EF Core migrations automatically on deploy
```

# Anti-patterns
- Avoid complex patterns without justification
- YAGNI
- Start simple and evolve
- Refactor when real pain emerges
```csharp
// Do not implement Event Sourcing if simple CRUD suffices
// Introduce only when a real requirement emerges
```