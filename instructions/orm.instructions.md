---
applyTo: "**/*{Repository,Context,Entity,Mapping}*.{cs,ts,js,java,py,go,rs}"
---
Domain: business rules in domain (not in repositories); POCO classes without infra deps; invariants in constructor/factories; restricted setters; singular descriptive names (e.g., Invoice); Guid or long IDs; consider value objects (e.g., Cnpj, Email) and owned types.
Example: Value object Email with validation; Aggregate Order exposes AddItem() enforcing invariants; entity IDs as Guid; no EF attributes in Domain

Mapping: centralized mapping (per entity/aggregate); avoid persistence annotations in domain; no lazy loading; prefer projections and explicit loading; concurrency control; soft-delete only with clear requirement; explicit constraints/indexes; auditing outside domain.
Example: Fluent mapping class OrderMapping configures keys/indexes and relationships; Use HasIndex(o => new { o.CustomerId, o.CreatedAt }).IncludeProperties(...); disable lazy loading; add rowversion for concurrency

Repositories/use cases: repositories per aggregate; no business rules in repositories; UoW/transactions in use case; for read-heavy paths use projections and optimized queries when sensible.
Example: IOrderRepository.GetRecentAsync returns DTOs via projection; Application UseCase wraps Save changes in a transaction with retry on deadlock; batch operations use bulk APIs

Queries/DTOs: never return entities to the API; map to DTOs; paginate large lists; safe sortable filters.
Example: Query projects to OrderListItemDto { Id, Number, Total, CreatedAt }; keyset pagination using (CreatedAt,Id); allow sort by CreatedAt only

Security/observability: no secrets in connection strings; minimal DB roles; structured logs with correlationId; metrics for pool/timeout/retries.
Example: Connection string from secure vault; DbContext logs include correlationId; metrics: connection pool usage, command timeouts, retries count