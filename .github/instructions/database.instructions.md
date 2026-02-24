---
applyTo: "**/{db,database,data,migrations,sql,prisma}*/**/*.{sql,psql,pgsql,mysql,db,prisma,json,yaml,yml}"
priority: medium
---

# Schema design
- Tables/columns/indexes/constraints in EN
- PascalCase for tables
- camelCase for columns
- pk_ for primary keys
- fk_ for foreign keys
- ix_ for indexes
- ck_ for checks
- uq_ for unique
- Triggers with tr_ prefix
```sql
CREATE TABLE Orders (
    orderId BIGINT PRIMARY KEY,
    createdAt DATETIME
);
ALTER TABLE Orders ADD CONSTRAINT pk_Orders PRIMARY KEY (orderId);
CREATE INDEX ix_Orders_CreatedAt ON Orders(createdAt);
```

# Normalization
- 1NF atomic columns
- 2NF full functional dependency
- 3NF no transitive dependency
- BCNF when applicable
- Controlled denormalization only for critical performance with justification
```sql
-- 3NF - Separate Addresses from Users to avoid transitive dependency
```

# Cartesian explosion
- Avoid JOINs without proper predicates
- Prefer EXISTS over IN with subqueries
- Filter before JOIN using CTEs/subqueries
- Verify cardinality estimates
- Test with large datasets
- Inspect execution plans
```sql
WITH Filtered AS (SELECT * FROM Orders WHERE status = 'Active')
SELECT * FROM Filtered JOIN Customers ON Filtered.customerId = Customers.id;
```

# Parameter sniffing
- OPTION(OPTIMIZE FOR UNKNOWN) when applicable
- Properly typed parameters
- Avoid dynamic SQL when possible
- Stored procedures with RECOMPILE when needed
- Plan guides for specific cases
- Forced parameterization in controlled scenarios
```sql
SELECT * FROM Orders WHERE status = @status OPTION (OPTIMIZE FOR UNKNOWN);
```

# Query performance
- Avoid SELECT *
- Appropriate indexes
- SARGABLE predicates (avoid functions in WHERE)
- LIMIT/TOP for large datasets
- Up-to-date statistics
- Plan analysis
- Avoid N+1
- Keyset (seek) pagination for large lists
```sql
SELECT TOP (@size) * FROM Orders
WHERE (createdAt, id) > (@lastCreatedAt, @lastId)
ORDER BY createdAt, id; -- Keyset pagination
```

# Indexes
- Clustered on most queried keys
- Non-clustered for FKs and filter columns
- Composite with most selective first
- Include columns for covering indexes
- Proper fill factor
- Maintenance plans
- Avoid over-indexing
- Drop unused
```sql
CREATE INDEX ix_Orders_CustomerId_CreatedAt ON Orders(CustomerId, CreatedAt) INCLUDE (Status, TotalAmount);
-- Drop ix_Orders_Temp if unused per stats
```

# Transactions
- ACID
- Proper isolation levels (READ COMMITTED default)
- Timeouts
- Deadlock handling with exponential backoff
- Rollback on exceptions
- Avoid nested transactions
- Idempotency for reprocess
- Forward-only migrations with reentrant scripts
```sql
BEGIN TRANSACTION;
-- Code
COMMIT;
-- Retry on deadlock with exponential backoff (max 3)
-- Migrations add columns with default then backfill in batches; scripts re-entrant
```

# Security
- Parameterized queries always
- SQL injection prevention
- Least privilege
- Sensitive data encryption
- Audit trails on critical ops
- Secure connection strings
- Secrets outside repo
- Encryption in transit/at rest
```sql
-- Use parameterized Dapper/EF queries
-- Store secrets in Key Vault/AWS Secrets Manager
-- Enforce TLS; restrict DB user to required schemas only
```

# Concurrency
- Optimistic locking with rowversion/timestamp
- Pessimistic only when needed
- Retry policies for deadlocks
- Connection pooling
- Async when possible
- Avoid hot partitions
```sql
UPDATE Orders SET status = 'Processed'
WHERE id = @id AND rowversion = @originalRowversion;
-- Shard by CustomerId to avoid hot partitions
```

# ORM mapping
- Mindful of N+1
- Batch ops for bulk
- Projection queries for readonly
- Optimized change tracking
- Managed connection lifecycle
- Include() for controlled eager loading
```csharp
// Project to DTOs in queries (Select new { ... }) instead of returning entities
// Use AsNoTracking for read-only
// Include only required navigation properties
```

# Data types
- Appropriate types
- Proper decimal precision
- Unicode considerations
- Date/time zones
- Large objects handling
- Computed columns when appropriate
- Surrogate keys (BIGINT/UUID) preferred
```sql
decimal(18,2) for currency; datetimeoffset for timestamps; nvarchar for user text; BIGINT for high-volume surrogate keys
```

# Monitoring
- Enable slow query logs
- Index usage stats
- Analyze wait stats
- Identify blocking
- Configure performance counters
- Alerts on critical thresholds
- Metrics latency/throughput/connections/locks
```sql
-- Alert when P95 latency > target
-- Review sys.dm_db_index_usage_stats for unused indexes
-- Analyze wait stats for CXPACKET/LATCH contention
```

Backup/Recovery:
- Automated backups
- Point-in-time tested
- DR procedures documented
- RTO/RPO defined
- Backup verification
- Periodic restore tests
```sql
-- Nightly full + hourly log backups
-- Quarterly restore drill
-- Document RTO 2h/RPO 15m with evidence
```

# Testing
- Integration tests on real DB
- Testcontainers for isolation
- Automated test data generation
- Schema comparison in CI/CD
- Performance regression tests
- Rollback scenarios tested
- Minimal deterministic datasets
```sql
-- Integration test seeds fixtures via Testcontainers
-- Compare schemas via CI
-- Assert query plans stable and latency within budget
```

# NoSQL/Document
- Access-pattern modeling with careful denormalization
- Well-chosen partition keys
- TTL when applicable
- Queries designed for 1-2 calls per flow
- Secondary index costs known
- Eventual vs strong consistency with SLA
- Idempotent ops
- Minimal ACL per collection/bucket
```sql
-- Partition by tenantId
-- Store read-optimized summary doc
-- TTL for ephemeral events
-- Prefer single-partition queries
-- Implement idempotent upserts
```