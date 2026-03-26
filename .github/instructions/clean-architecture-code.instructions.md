---
applyTo: "**/*.{cs,ts,js,go,rs,java,py}"
priority: high
---

# Clean Architecture principles
- Domain-driven design with domain at the center
- Application layer coordinates use cases
- Infrastructure isolated from domain
- Presentation depends only on application
- Strict dependency inversion
- Business rules in domain without external dependencies
```csharp
// Domain: entities, value objects, domain services, interfaces
// Application: use cases, application services, DTOs, ports
// Infrastructure: repositories, external services, frameworks
// Presentation: controllers, views, CLI, APIs
```

# SOLID principles
- Strict Single Responsibility
- Open/Closed via abstractions
- Liskov Substitution respected
- Interface Segregation with focused contracts
- Dependency Inversion with stable abstractions
```csharp
// Interface with single method for segregation
public interface IOrderValidator { bool IsValid(Order order); }
```

# Domain modeling
- Entities with identity
- Immutable value objects
- Aggregates as consistency boundaries
- Domain events for communication
- Consistent ubiquitous language
- Business rules encapsulated
```csharp
public class Order : AggregateRoot
{
    public Guid Id { get; private set; }
    // Value Object
    public Money Amount { get; private set; }
    // Domain Event
    public void RaiseEvent(OrderCreatedEvent e) { /* ... */ }
}
```

# Use case design
- Application services coordinate
- Command/query separation
- Input/output DTOs
- Validation in application layer
- Authorization separated from business logic
- Clear transactional boundaries
```csharp
public class CreateOrderUseCase
{
    public async Task Execute(CreateOrderDto dto) { /* validate, authorize, transact */ }
}
```

# Dependency management
- Abstractions in domain
- Implementations in infrastructure
- Dependency injection container
- Externalized configuration
- Environment-specific settings
- Feature toggles when appropriate
```csharp
// DI
services.AddScoped<IOrderRepository, SqlOrderRepository>();
```

# Testing strategy
- Isolated unit tests for domain
- Integration tests for infrastructure
- Acceptance tests for use cases
- Test doubles for dependencies
- Consistent AAA pattern
- Deterministic tests
```csharp
[Fact]
public void Should_CreateOrder()
{
    // Arrange
    var mockRepo = new Mock<IOrderRepository>();
    // Act
    var result = useCase.Execute(dto);
    // Assert
    Assert.NotNull(result);
}
```

# Error handling
- Domain exceptions for business rules
- Application exceptions for coordination
- Wrap infrastructure exceptions
- Consistent error codes
- Structured logging
- Correlation IDs for tracing
```csharp
throw new DomainException("Invalid order status");
logger.LogError("Error {CorrelationId}", correlationId);
```

# Data flow
- Commands modify state
- Queries return read models
- Events communicate changes
- Saga for distributed transactions
- Eventual consistency acceptable
- Idempotency ensured
```csharp
public class GetOrderQuery { public OrderDto Execute(Guid id) { /* ... */ } }
```

# Code organization
- Feature-based folders when appropriate
- Shared kernel for common concepts
- Well-defined bounded contexts
- Anti-corruption layers for external systems
- Hexagonal architecture principles
```csharp
// Features/Orders/Domain/Order.cs
// Features/Orders/Application/CreateOrderUseCase.cs
// SharedKernel/ValueObjects/Money.cs
```

# Performance
- Lazy loading when appropriate
- Caching in infrastructure
- Bulk operations
- Async/await for I/O
- Mindful memory usage
- Regular profiling
```csharp
var cached = cache.GetOrCreate("key", entry => { /* load */ });
```

# Security
- Separate authentication from authorization
- Encryption in infrastructure
- Input sanitization
- Output encoding
- Audit logging
- Least privilege
```csharp
[Authorize(Roles = "Admin")]
public IActionResult AdminAction() { /* ... */ }
```