---
applyTo: "**/{db,database,data,migrations,sql,prisma}*/**/*.{sql,psql,pgsql,mysql,db,prisma,json,yaml,yml}"
---
Schema design: tables/columns/indexes/constraints in EN; PascalCase for tables; camelCase for columns; pk_ for primary keys; fk_ for foreign keys; ix_ for indexes; ck_ for checks; uq_ for unique; triggers with tr_ prefix.
Example: Tables Orders, OrderItems; columns orderId, createdAt; constraints pk_Orders, fk_OrderItems_OrderId; indexes ix_Orders_CreatedAt, uq_Users_Email; check ck_Orders_Amount_Positive

Normalization: 1NF atomic columns; 2NF full functional dependency; 3NF no transitive dependency; BCNF when applicable; controlled denormalization only for critical performance with justification.
Cartesian explosion: avoid JOINs without proper predicates; prefer EXISTS over IN with subqueries; filter before JOIN using CTEs/subqueries; verify cardinality estimates; test with large datasets; inspect execution plans.
Parameter sniffing: OPTION(OPTIMIZE FOR UNKNOWN) when applicable; properly typed parameters; avoid dynamic SQL when possible; stored procedures with RECOMPILE when needed; plan guides for specific cases; forced parameterization in controlled scenarios.
Query performance: avoid SELECT *; appropriate indexes; SARGABLE predicates (avoid functions in WHERE); LIMIT/TOP for large datasets; up-to-date statistics; plan analysis; avoid N+1; keyset (seek) pagination for large lists.
Example: WHERE createdAt >= @from AND createdAt < @to (no functions on column); SELECT TOP (@size) ... WHERE (createdAt,@id) > (@lastCreatedAt,@lastId) ORDER BY createdAt,id (keyset)

Indexes: clustered on most queried keys; non-clustered for FKs and filter columns; composite with most selective first; include columns for covering indexes; proper fill factor; maintenance plans; avoid over-indexing; drop unused.
Example: CREATE INDEX ix_Orders_CustomerId_CreatedAt ON Orders(CustomerId, CreatedAt) INCLUDE (Status, TotalAmount); drop ix_Orders_Temp if unused per stats

Transactions: ACID; proper isolation levels (READ COMMITTED default); timeouts; deadlock handling with exponential backoff; rollback on exceptions; avoid nested transactions; idempotency for reprocess; forward-only migrations with reentrant scripts.
Example: Retry on deadlock with exponential backoff (max 3); keep transactions short; migrations add columns with default then backfill in batches; scripts re-entrant

Security: parameterized queries always; SQL injection prevention; least privilege; sensitive data encryption; audit trails on critical ops; secure connection strings; secrets outside repo; encryption in transit/at rest.
Example: Use parameterized Dapper/EF queries; store secrets in Key Vault/AWS Secrets Manager; enforce TLS; restrict DB user to required schemas only

Concurrency: optimistic locking with rowversion/timestamp; pessimistic only when needed; retry policies for deadlocks; connection pooling; async when possible; avoid hot partitions.
Example: Use rowversion in update WHERE clause; shard by CustomerId to avoid hot partitions; configure pool size and command timeouts

ORM mapping: mindful of N+1; batch ops for bulk; projection queries for readonly; optimized change tracking; managed connection lifecycle; Include() for controlled eager loading.
Example: Project to DTOs in queries (Select new { ... }) instead of returning entities; use AsNoTracking for read-only; Include only required navigation properties

Data types: appropriate types; proper decimal precision; unicode considerations; date/time zones; large objects handling; computed columns when appropriate; surrogate keys (BIGINT/UUID) preferred.
Example: decimal(18,2) for currency; datetimeoffset for timestamps; nvarchar for user text; use BIGINT for high-volume surrogate keys

Monitoring: enable slow query logs; index usage stats; analyze wait stats; identify blocking; configure performance counters; alerts on critical thresholds; metrics latency/throughput/connections/locks.
Example: Alert when P95 latency > target; review sys.dm_db_index_usage_stats for unused indexes; analyze wait stats for CXPACKET/LATCH contention

Backup/Recovery: automated backups; point-in-time tested; DR procedures documented; RTO/RPO defined; backup verification; periodic restore tests.
Example: Nightly full + hourly log backups; quarterly restore drill; document RTO 2h/RPO 15m with evidence

Testing: integration tests on real DB; Testcontainers for isolation; automated test data generation; schema comparison in CI/CD; performance regression tests; rollback scenarios tested; minimal deterministic datasets.
Example: Integration test seeds fixtures via Testcontainers; compare schemas via CI; assert query plans stable and latency within budget

NoSQL/Document: access-pattern modeling with careful denormalization; well-chosen partition keys; TTL when applicable; queries designed for 1-2 calls per flow; secondary index costs known; eventual vs strong consistency with SLA; idempotent ops; minimal ACL per collection/bucket.
Example: Partition by tenantId; store read-optimized summary doc; TTL for ephemeral events; prefer single-partition queries; implement idempotent upserts