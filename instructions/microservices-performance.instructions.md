---
applyTo: "**/microservice*/**/*.{cs,ts,js,json,yml,yaml,config,dockerfile}"
priority: medium
---

# Service boundaries
- Single responsibility
- Domain-driven boundaries
- Database per service
- Prefer async communication
- Event-driven architecture
- Saga for distributed transactions
- API gateway as entry point
```yaml
routes:
  - path: /orders
    service: order-service
```

# Performance
- Configured connection pooling
- Consistent async/await
- Bulk operations
- Appropriate lazy loading
- Distributed cache (Redis)
- CDN for assets
- Compression enabled
```csharp
var cache = ConnectionMultiplexer.Connect("redis");
cache.GetDatabase().StringSet("key", value);
```

# Resource efficiency
- Minimal images
- Multi-stage builds
- Defined resource limits
- Accurate CPU/memory requests
- HPA/VPA
- Tuned probes
```yaml
resources:
  limits:
    cpu: "500m"
    memory: "512Mi"
  requests:
    cpu: "250m"
    memory: "256Mi"
```

# Communication
- gRPC for service-to-service
- REST for external APIs
- Message queues for async
- Circuit breaker
- Retries with exponential backoff
- Timeouts
- Idempotent operations
```csharp
.AddPolicyHandler(Policy.Handle<Exception>().WaitAndRetryAsync(3, retry => TimeSpan.FromSeconds(Math.Pow(2, retry))))
```

# Consistency
- Eventual consistency by default
- CQRS when applicable
- Event sourcing for audit
- Saga orchestration
- Compensation patterns
- Avoid distributed transactions
- Optimized read models
```csharp
public class OrderSaga { /* Orchestrate steps with compensation */ }
```

# Caching
- Application cache
- Distributed cache
- Cache-aside
- Write-through when needed
- Proper TTL
- Invalidation
- Warming
- Hierarchy
```csharp
var value = cache.Get("key") ?? LoadAndCache("key");
```

# Load balancing
- Round-robin default
- Health-based routing
- Session affinity when needed
- Geo routing
- A/B testing
- Canary
- Blue-green
```yaml
spec:
  template:
    metadata:
      labels:
        version: v2
  traffic: 10%
```

# Monitoring
- Structured logs
- Correlation IDs
- Metrics aggregation
- Tracing
- SLA monitoring
- Error rate
- Latency percentiles
- Resource utilization
```yaml
- job_name: 'service'
  metrics_path: /metrics
```

# Security performance
- JWT validation
- Optimized OAuth2 flows
- Per-service rate limiting
- API key caching
- Certificate rotation
- Secrets management
- Network policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

# Database
- Read replicas
- Pooling
- Query optimization
- Indexes
- Partitioning when needed
- Archiving
- DB monitoring
- Slow query detection
```sql
CREATE INDEX idx_orders_status ON orders(status);
```

# Messaging
- Batch processing
- Parallel consumers
- DLQ
- Deduplication
- Poison message handling
- Backpressure
- Consumer scaling
```yaml
deadLetterQueue: enabled
```

# Memory
- Object pooling
- Dispose patterns
- Weak refs
- GC tuning
- Profiling
- Leak detection
- Memory limits
- Streaming large data
```csharp
using var pooled = ArrayPool<byte>.Shared.Rent(1024);
```

# Network
- Connection reuse
- Compression
- Binary protocols
- Payload optimization
- Bandwidth monitoring
- Partition handling
- Edge caching
```http
Accept-Encoding: gzip
```

# Service discovery
- Health checks
- Graceful shutdown
- Registration
- Load balancer integration
- DNS discovery
- Service mesh when applicable
- Failover
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 80
```

# Deployment
- Rolling updates
- Zero-downtime
- Config management
- Environment parity
- IaC
- Automated rollbacks
- Deploy monitoring
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```