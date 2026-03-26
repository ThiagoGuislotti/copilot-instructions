---
applyTo: "**/*{Repository,Context,Entity,Mapping}*.{cs,ts,js,java,py,go,rs}"
priority: medium
---

# Domain
- Business rules in domain (not in repositories)
- POCO classes without infra deps
- Invariants in constructor/factories
- Restricted setters
- Singular descriptive names (e.g., Invoice)
- Guid or long IDs
- Consider value objects (e.g., Cnpj, Email) and owned types
```csharp
// Value object Email with validation
// Aggregate Order exposes AddItem() enforcing invariants
// Entity IDs as Guid
// No EF attributes in Domain
```

# Mapping
- Centralized mapping (per entity/aggregate)
- Avoid persistence annotations in domain
- No lazy loading
- Prefer projections and explicit loading
- Concurrency control
- Soft-delete only with clear requirement
- Explicit constraints/indexes
- Auditing outside domain
```csharp
// Fluent mapping class OrderMapping configures keys/indexes and relationships
// Use HasIndex(o => new { o.CustomerId, o.CreatedAt }).IncludeProperties(...)
```

# Repositories/use cases
- Repositories per aggregate
- No business rules in repositories
- UoW/transactions in use case
- For read-heavy paths use projections and optimized queries when sensible
```csharp
// IOrderRepository.GetRecentAsync returns DTOs via projection
// Application UseCase wraps Save changes in a transaction with retry on deadlock
// Batch operations use bulk APIs
```

# Queries/DTOs
- Never return entities to the API
- Map to DTOs
- Paginate large lists
- Safe sortable filters
```csharp
// Query projects to OrderListItemDto { Id, Number, Total, CreatedAt }
// Keyset pagination using (CreatedAt,Id)
// Allow sort by CreatedAt only
```

# Security/observability
- No secrets in connection strings
- Minimal DB roles
- Structured logs with correlationId
- Metrics for pool/timeout/retries
```csharp
// Connection string from secure vault
// DbContext logs include correlationId
// Metrics: connection pool usage, command timeouts, retries count
```