---
applyTo: "**/*.{cs,csproj,sln,slnf,props,targets}"
---
Code organization: #region structure (Fields, Properties, Constructors, Methods); use template .github/templates/dotnet-class-template.cs for classes; use template .github/templates/dotnet-interface-template.cs for interfaces; small focused methods; single responsibility classes; avoid god classes; ensure namespaces match folder structure exactly and no trailing empty line at EOF.
Example: follow .github/templates/dotnet-class-template.cs and .github/templates/dotnet-interface-template.cs when creating new types; replace placeholders, keep PascalCase naming, remove unused usings

Performance: string interpolation vs concatenation; StringBuilder in loops; Span<T> for arrays; ArrayPool for expensive objects; ConfigureAwait(false) in libraries; minimal APIs; record types.
Example: var msg = $"Hello {name}"; using var sb = new StringBuilder(); foreach → sb.Append(); use Span<byte> for parsing; ConfigureAwait(false) in class libraries

Async patterns: consistent async/await; ConfigureAwait(false) for libraries; CancellationToken on methods; Task.Run for CPU-intensive; ValueTask for hot paths; avoid deadlocks.
Example: public async Task<Order> GetAsync(Guid id, CancellationToken ct) { return await db.FindAsync(id, ct).ConfigureAwait(false); }

Error handling: structured exceptions; ProblemDetails for HTTP APIs; ILogger via DI; specific try/catch; fail-fast validation; correlation IDs.
Example: return Results.Problem(title:"Invalid request", statusCode:400, extensions:new{correlationId=cid}); catch (SqlException ex) { logger.LogError(ex, "DB error {CorrelationId}", cid); }

Testing patterns: AAA with minimal duplication; prefer test data builders, isolated mocks and deterministic assertions; use unified templates to start fast and keep consistency: unit tests → .github/templates/dotnet-unit-test-template.cs (toggle xUnit or NUnit at the top); integration tests → .github/templates/dotnet-integration-test-template.cs (NUnit). File layout: unit tests in tests/<Project>.UnitTests/Tests/*Tests.cs; integration tests in tests/<Project>.IntegrationTests/Tests/*Tests.cs. Categories/output: organize by domain category (Requests, Stream, Notifications, Commands, Queries, Pipeline, Concurrency, etc.); for xUnit use ITestOutputHelper; for NUnit use TestContext.
Example: for new tests, copy dotnet-unit-test-template.cs (or dotnet-integration-test-template.cs), replace placeholders, set the framework symbol (UNIT_XUNIT or UNIT_NUNIT) when applicable, and keep AAA sections concise to avoid code repetition.

EF Core: Fluent API configuration; scoped DbContext; NoTracking for reads; explicit transactions; versioned migrations; explicit constraints; optimized indexes.
Example: modelBuilder.Entity<Order>().HasIndex(x => x.Email).IsUnique(); using var ctx = new DbContext(options); ctx.Orders.AsNoTracking()

MediatR: CQRS command/query separation; pipeline behaviors for cross-cutting; request/response patterns; notifications; DI registration.
Example: record CreateOrderCommand(string CustomerId) : IRequest<Order>; builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(Program).Assembly))

Background Services: BackgroundService base; IHostedService; template .github/templates/background-service-template.cs; scoped services via IServiceProvider; respect CancellationToken; exception handling; health checks.
Example: implement new workers using .github/templates/background-service-template.cs

Dependency injection: AddScoped for business logic; AddSingleton for config; AddTransient for stateless; avoid service locator; explicit registrations; interface abstractions.
Example: services.AddScoped<IOrderService, OrderService>(); services.AddSingleton<AppConfig>(); services.AddTransient<IEmailSender, SmtpSender>()

HTTP Client: HttpClientFactory; typed/named clients; Polly retries; timeouts; base address; JSON serialization.
Example: services.AddHttpClient<IWeatherClient, WeatherClient>().AddTransientHttpErrorPolicy(p => p.WaitAndRetryAsync(3))

Configuration: IOptions pattern; strongly typed; validation attributes; IOptionsMonitor for runtime; appsettings hierarchy; environment variables; secret management.
Example: services.Configure<MyConfig>(configSection); public class MyConfig { [Required] public string ApiKey { get; set; } }

Security: no hardcoded secrets; encrypt sensitive data; HTTPS only; CORS specific origins; JWT validation; rate limiting; input sanitization; SQL injection prevention
Example: builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(); builder.Services.AddCors(o => o.WithOrigins("https://myapp.com"))

Logging: structured logging; proper levels; correlation IDs; sensitive data filtering; minimal performance impact; async logging; centralized config.
Example: logger.LogInformation("Order {OrderId} created {CorrelationId}", order.Id, cid)

Metrics: custom metrics; performance counters; health endpoints; diagnostics; APM integration; business metrics; SLA monitoring.
Example: app.UseEndpoints(e => { e.MapMetrics(); e.MapHealthChecks("/health/ready"); })

Code style: nullable reference types; file-scoped namespaces; minimal usings; consistent naming; XML docs for public APIs; EditorConfig compliance.
Example: namespace NetToolsKit.Core; public sealed class Utils { … } with Nullable enabled

XML docs C#: use .github/templates/dotnet-class-template.cs and .github/templates/dotnet-interface-template.cs as reference; summary for classes/methods/properties; param/returns/exception; see cref; remarks/examples when useful; inheritdoc for overrides and interface implementations. When a method implements an interface, prefer using <inheritdoc cref="IInterface.Method(Type, CancellationToken)"/> and add remarks “Implements interface method documentation”.
Example: keep method docs concise and rely on inheritdoc when implementing interface members; use the class/interface templates as a baseline and adjust placeholders.