---
applyTo: "**/*.{cs,csproj,sln,slnf,props,targets}"
---

# Code Organization
- #region structure (Fields, Properties, Constructors, Methods)
- Use template .github/templates/dotnet-class-template.cs for classes
- Use template .github/templates/dotnet-interface-template.cs for interfaces
- Small focused methods
- Single responsibility classes
- Avoid god classes
- Ensure namespaces match folder structure exactly and no trailing empty line at EOF
```csharp
// follow .github/templates/dotnet-class-template.cs and .github/templates/dotnet-interface-template.cs when creating new types
// Replace placeholders, keep PascalCase naming, remove unused usings
namespace MyApp.Core;
public sealed class OrderService
{
    private readonly IRepository _repo;
    public OrderService(IRepository repo) { _repo = repo; }
    public Task<Order> GetAsync(Guid id) => _repo.FindAsync(id);
}
```

# Performance
- String interpolation vs concatenation
- StringBuilder in loops
- Span<T> for arrays
- ArrayPool for expensive objects
- ConfigureAwait(false) in libraries
- Minimal APIs
- Record types
```csharp
var msg = $"Hello {name}";
using var sb = new StringBuilder();
foreach (var p in parts) sb.Append(p);
```

# Async Patterns
- Consistent async/await
- ConfigureAwait(false) for libraries
- CancellationToken on methods
- Task.Run for CPU-intensive
- ValueTask for hot paths
- Avoid deadlocks
```csharp
public async Task<Order> GetAsync(Guid id, CancellationToken ct)
{
    return await db.FindAsync(id, ct).ConfigureAwait(false);
}
```

# Error Handling
- Structured exceptions
- ProblemDetails for HTTP APIs
- ILogger via DI
- Specific try/catch
- Fail-fast validation
- Correlation IDs
```csharp
catch (SqlException ex)
{
    logger.LogError(ex, "DB error {CorrelationId}", cid);
    return Results.Problem("Invalid request", 400, new { correlationId = cid });
}
```

# Testing Patterns
- AAA with minimal duplication
- Prefer test data builders, isolated mocks and deterministic assertions
- Unified templates to start fast and keep consistency: unit tests → .github/templates/dotnet-unit-test-template.cs (toggle xUnit or NUnit at the top)
- Integration tests → .github/templates/dotnet-integration-test-template.cs (NUnit)
- File layout: unit tests in tests/<Project>.UnitTests/Tests/*Tests.cs
- Integration tests in tests/<Project>.IntegrationTests/Tests/*Tests.cs
- Categories/output: organize by domain category (Requests, Stream, Notifications, Commands, Queries, Pipeline, Concurrency, etc.)
- For xUnit use ITestOutputHelper; for NUnit use TestContext
```csharp
[Fact]
public void Should_CreateOrder_When_RequestIsValid()
{
    // Arrange
    var service = new OrderService();
    // Act
    var result = service.Create("123");
    // Assert
    result.Should().NotBeNull();
}
```

# EF Core
- Fluent API configuration
- Scoped DbContext
- NoTracking for reads
- Explicit transactions
- Versioned migrations
- Explicit constraints
- Optimized indexes
```csharp
modelBuilder.Entity<Order>().HasIndex(x => x.Email).IsUnique();
ctx.Orders.AsNoTracking();
```

# MediatR
- CQRS command/query separation
- Pipeline behaviors for cross-cutting
- Request/response patterns
- Notifications
- DI registration
```csharp
record CreateOrderCommand(string CustomerId) : IRequest<Order>;
builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(Program).Assembly));
```

# Background Services
- BackgroundService base
- IHostedService
- Template .github/templates/background-service-template.cs
- Scoped services via IServiceProvider
- Respect CancellationToken
- Exception handling
- Health checks
```csharp
public class Worker : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken) { /* ... */ }
}
```

# Dependency Injection
- AddScoped for business logic
- AddSingleton for config
- AddTransient for stateless
- Avoid service locator
- Explicit registrations
- Interface abstractions
```csharp
services.AddScoped<IOrderService, OrderService>();
services.AddSingleton<AppConfig>();
services.AddTransient<IEmailSender, SmtpSender>();
```

# HTTP Client
- HttpClientFactory
- Typed/named clients
- Polly retries
- Timeouts
- Base address
- JSON serialization
```csharp
services.AddHttpClient<IWeatherClient, WeatherClient>().AddTransientHttpErrorPolicy(p => p.WaitAndRetryAsync(3));
```

# Configuration
- IOptions pattern
- Strongly typed
- Validation attributes
- IOptionsMonitor for runtime
- appsettings hierarchy
- Environment variables
- Secret management
```csharp
services.Configure<MyConfig>(configSection);
public class MyConfig { [Required] public string ApiKey { get; set; } }
```

# Security
- No hardcoded secrets
- Encrypt sensitive data
- HTTPS only
- CORS specific origins
- JWT validation
- Rate limiting
- Input sanitization
- SQL injection prevention
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
builder.Services.AddCors(o => o.WithOrigins("https://myapp.com"));
```

# Logging
- Structured logging
- Proper levels
- Correlation IDs
- Sensitive data filtering
- Minimal performance impact
- Async logging
- Centralized config
```csharp
logger.LogInformation("Order {OrderId} created {CorrelationId}", order.Id, cid);
```

# Metrics
- Custom metrics
- Performance counters
- Health endpoints
- Diagnostics
- APM integration
- Business metrics
- SLA monitoring
```csharp
app.UseEndpoints(e => { e.MapMetrics(); e.MapHealthChecks("/health/ready"); });
```

# Code Style
- Use .github/templates/dotnet-class-template.cs and .github/templates/dotnet-interface-template.cs as reference
- Nullable reference types enabled at project level
- Block-scoped namespaces
- Minimal/usings (prefer implicit usings where configured)
- Consistent naming (PascalCase for types/members, camelCase for locals/params)
- XML docs for public APIs
- EditorConfig compliance
```csharp
namespace NetToolsKit.Core
{
    public sealed class Utils { /* ... */ }
}
```

# XML Documentation
- Use .github/templates/dotnet-class-template.cs and .github/templates/dotnet-interface-template.cs as reference
- Summary for classes/methods/properties
- Param/returns/exception
- See cref
- Remarks/examples when useful
- Inheritdoc for overrides and interface implementations
- When a method implements an interface, prefer using <inheritdoc cref="IInterface.Method(Type, CancellationToken)"/> and add remarks “Implements interface method documentation”
```csharp
/// <inheritdoc cref="IOrderService.GetAsync"/>
public async Task<Order> GetAsync(Guid id, CancellationToken ct) { /* ... */ }
```