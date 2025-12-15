---
applyTo: "**/*.{cs,csproj,sln,slnf,props,targets}"
priority: high
---

# Code Organization
- #region structure and order (top to bottom):
    - `#region Constants` - const fields
    - `#region Static Variables` - static fields
    - `#region Static Properties` - static properties
    - `#region Variables` - instance fields
    - `#region Protected Properties` - protected properties
    - `#region Public Properties` - public properties
    - `#region Internal Properties` - internal properties
    - `#region Constructors` - constructors
    - `#region Public Methods/Operators` - public methods and operators
    - `#region Protected Methods/Operators` - protected methods and operators
    - `#region Internal Methods/Operators` - internal methods and operators
    - `#region Private Methods/Operators` - private methods and operators
- Do not create empty regions. Only wrap members when there is at least one concrete member inside the region. If a type has no public methods, do not emit `#region Public Methods/Operators` at all.
- #region formatting: NO blank line after `#region Description` and NO blank line before `#endregion`. Implementation starts immediately after the region marker and ends immediately before endregion.
- #region spacing: ALWAYS add ONE blank line between `#endregion` and the next `#region`. Never place them adjacent without separation.
- ALWAYS use template .github/templates/dotnet-class-template.cs for classes
- ALWAYS use template .github/templates/dotnet-interface-template.cs for interfaces
- Small focused methods
- Single responsibility classes
- Avoid god classes
- Ensure namespaces match folder structure exactly and no trailing empty line at EOF
```csharp
// follow .github/templates/dotnet-class-template.cs and .github/templates/dotnet-interface-template.cs when creating new types
// Replace placeholders, keep PascalCase naming, remove unused usings
namespace MyApp.Core
{
    public sealed class OrderService
    {
        private readonly IRepository _repo;
        public OrderService(IRepository repo) { _repo = repo; }
        public Task<Order> GetAsync(Guid id) => _repo.FindAsync(id);
    }
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
namespace MyApp.Services
{
    public async Task<Order> GetAsync(Guid id, CancellationToken ct)
    {
        return await db.FindAsync(id, ct).ConfigureAwait(false);
    }
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
- ALWAYS use templates to start fast and keep consistency:
    - Unit tests: ALWAYS use template .github/templates/dotnet-unit-test-template.cs
    - Integration tests: ALWAYS use template .github/templates/dotnet-integration-test-template.cs
- File layout: unit tests in tests/<Project>.UnitTests/Tests/*Tests.cs
- Integration tests in tests/<Project>.IntegrationTests/Tests/*Tests.cs
- Categories/output: organize by domain category (Requests, Stream, Notifications, Commands, Queries, Pipeline, Concurrency, etc.)
- For xUnit use ITestOutputHelper; for NUnit use TestContext
- ALWAYS use standard assertions: NUnit (Assert.That, Assert.Throws) or xUnit (Assert.Equal, Assert.True)
- NO XML summaries on test methods
- Integration tests require: [TestFixture], [RequiresThread], [SetCulture("pt-BR")], [Category("...")]

## Test File Region Structure
- Test files MUST follow the region structure from templates (different from production code):
    - `#region Nested types` - DTOs, stubs, test-specific types
    - `#region Variables` - private fields, dependencies, test data
    - `#region SetUp Methods` - [SetUp], [TearDown], [OneTimeSetUp], [OneTimeTearDown]
    - `#region Test Methods - [MethodUnderTest]` - group tests by the method being tested
    - `#region Test Methods - [MethodUnderTest] Valid Cases` - happy path tests
    - `#region Test Methods - [MethodUnderTest] Invalid Cases` - validation/error tests
    - `#region Test Methods - [MethodUnderTest] Edge Cases` - boundary/edge case tests
    - `#region Test Methods - [MethodUnderTest] Exception Cases` - exception handling tests
    - `#region Private Methods/Operators` - helper methods for test setup
- Replace `[MethodUnderTest]` with the actual method name being tested (e.g., `#region Test Methods - CreateOffset`)
- Do NOT use generic region names like `#region CanHandle Tests` or `#region RoundTrip Tests`
- Combine related test cases under the same method region with appropriate suffixes (Valid/Invalid/Edge/Exception Cases)
```csharp
[TestFixture]
[Category("Unit")]
public sealed class OrderServiceTests
{
    #region Variables
    private OrderService _sut;
    private Mock<IRepository> _mockRepo;
    #endregion
    #region SetUp Methods
    [SetUp]
    public void SetUp()
    {
        _mockRepo = new Mock<IRepository>();
        _sut = new OrderService(_mockRepo.Object);
    }
    #endregion
    #region Test Methods - Create Valid Cases
    [Test]
    public void Create_ValidRequest_ReturnsOrder()
    {
        // Arrange
        var request = new CreateOrderRequest { Id = "123" };
        // Act
        var result = _sut.Create(request);
        // Assert
        Assert.That(result, Is.Not.Null);
    }
    #endregion
    #region Test Methods - Create Invalid Cases
    [Test]
    public void Create_NullRequest_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.Throws<ArgumentNullException>(() => _sut.Create(null));
    }
    #endregion
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
- New file header template for project descriptions (csproj <Description>): keep it short in EN with:
    - One-line intro stating purpose
    - 2–4 bullet Features lines
    - One-line conclusion starting with "Ideal for ..."
    Example:
    "MyLib provides X for Y. Features: • A • B • C. Ideal for Z."
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

# Multi-targeting (.NET 8/9) and conditional directives
- Goal: keep code simple and compatible, using conditional directives only when unavoidable.
- “Minimal #if” pattern:
    - Prefer a single class/file and isolate `#if NET9_0_OR_GREATER` only in:
        - specific usings (e.g., Microsoft.AspNetCore.OpenApi)
        - method signatures (e.g., parameters that use .NET 9 types like `Action<OpenApiOptions>?`)
        - body snippets that rely on .NET 9-only APIs (e.g., `services.AddOpenApi(...)`)
    - Avoid wrapping the entire file with `#if` when possible.
    - When a method cannot exist on older TFMs, keep a “cold plate” signature (object-shaped parameters) or throw NotSupportedException, and register an ApiCompat suppression when needed.
- When wrapping the entire class:
    - If the type implements interfaces/uses contexts that exist only on .NET 9 (e.g., `IOpenApiDocumentTransformer`, `IOpenApiOperationTransformer`, `IOpenApiSchemaTransformer`), keep the `#if` across the whole file to avoid breaking the .NET 8 build.
    - Optional: add a comment at the top of the file explaining the reason (to prevent accidental removals later).
    - Do not create conditional empty regions. If the whole block is conditional and there are no members on the older TFM, omit the region for that TFM.
- Advanced alternatives (use sparingly):
    - Split files per TFM (e.g., `ServiceCollectionExtensions.Net9.cs`) and include via conditions in the `.csproj`. Use only if the local `#if` complexity starts to grow.
- Documentation guidelines:
    - Do not use conditional directives inside XML comments (this causes errors). Use neutral descriptions instead (“supported only on .NET 9+”).
    - If a feature exists only on .NET 9+, document it in the summary and add TFM-conditional tests, avoiding asserts that fail on earlier TFMs.