---
description: Analyze code and refactor to Clean Architecture with proper layer separation
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Refactor to Clean Architecture
Analyze existing code and refactor to Clean Architecture following SOLID principles.

## Instructions
Refactor code based on:
- [clean-architecture-code.instructions.md](../.github/instructions/clean-architecture-code.instructions.md)
- [backend.instructions.md](../.github/instructions/backend.instructions.md)
- [dotnet-csharp.instructions.md](../.github/instructions/dotnet-csharp.instructions.md)

## Input Variables
- `${input:targetPath:Path to code to refactor}` - File or directory path
- `${input:currentArchitecture:Current architecture (monolith/layered/mvc)}` - Current pattern
- `${input:hasTests:Has existing tests? (yes/no)}` - Test coverage status
- `${input:targetLayer:Target layer (domain/application/infrastructure/api)}` - Clean Architecture layer

## Clean Architecture Layers

### 1. Domain Layer (Core)
**Purpose:** Business entities, value objects, domain logic  
**Dependencies:** None (Pure business logic)  
**Location:** `src/ProjectName.Domain/`

```
Domain/
  Entities/           # Business entities with behavior
  ValueObjects/       # Immutable value types
  Enums/             # Domain enumerations
  Interfaces/        # Repository and service abstractions
  Exceptions/        # Domain-specific exceptions
  Events/            # Domain events
```

**Refactoring Steps:**
1. Identify business entities and extract to `Entities/`
2. Extract value objects (immutable types) to `ValueObjects/`
3. Move domain logic from services to entity methods
4. Define repository interfaces (no implementations)
5. Create domain-specific exceptions
6. Remove all infrastructure dependencies

**Example Entity:**
```csharp
namespace ProjectName.Domain.Entities;

/// <summary>
/// Represents a ${EntityName} in the business domain
/// </summary>
public sealed class ${EntityName}
{
    public int Id { get; private set; }
    public string Name { get; private set; }
    public DateTime CreatedAt { get; private set; }

    private ${EntityName}() { } // EF Core constructor

    public static ${EntityName} Create(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new DomainException("${EntityName} name cannot be empty");

        return new ${EntityName}
        {
            Name = name,
            CreatedAt = DateTime.UtcNow
        };
    }

    public void UpdateName(string newName)
    {
        if (string.IsNullOrWhiteSpace(newName))
            throw new DomainException("${EntityName} name cannot be empty");

        Name = newName;
    }
}
```

### 2. Application Layer (Use Cases)
**Purpose:** Application logic, CQRS commands/queries, DTOs  
**Dependencies:** Domain layer only  
**Location:** `src/ProjectName.Application/`

```
Application/
  Commands/          # CQRS commands with handlers
  Queries/           # CQRS queries with handlers
  Dtos/             # Data transfer objects
    Requests/       # Input DTOs
    Responses/      # Output DTOs
  Mapping/          # Entity ↔ DTO mappers
  Validation/       # Input validation (FluentValidation)
  Interfaces/       # Application service abstractions
  Exceptions/       # Application-specific exceptions
```

**Refactoring Steps:**
1. Extract API controllers logic to command/query handlers
2. Create DTOs for all API inputs/outputs
3. Implement request validators with FluentValidation
4. Add MediatR for CQRS pattern
5. Create mappers for Entity ↔ DTO conversions
6. Remove infrastructure dependencies from handlers

**Example Command + Handler:**
```csharp
// Command
public sealed record Create${EntityName}Command(Create${EntityName}Request Request) 
    : IRequest<Result<${EntityName}Response>>;

// Handler
public sealed class Create${EntityName}Handler 
    : IRequestHandler<Create${EntityName}Command, Result<${EntityName}Response>>
{
    private readonly I${EntityName}Repository _repository;

    public Create${EntityName}Handler(I${EntityName}Repository repository)
    {
        _repository = repository;
    }

    public async Task<Result<${EntityName}Response>> Handle(
        Create${EntityName}Command command,
        CancellationToken cancellationToken)
    {
        // Business logic using domain entities
        var entity = ${EntityName}.Create(command.Request.Name);
        await _repository.AddAsync(entity, cancellationToken);
        
        return Result<${EntityName}Response>.Success(new ${EntityName}Response
        {
            Id = entity.Id,
            Name = entity.Name
        });
    }
}
```

### 3. Infrastructure Layer (Implementation)
**Purpose:** External concerns (DB, files, APIs, caching)  
**Dependencies:** Domain, Application layers  
**Location:** `src/ProjectName.Infrastructure/`

```
Infrastructure/
  Persistence/       # EF Core DbContext, configurations
  Repositories/      # Repository implementations
  Services/          # External service integrations
  Caching/          # Caching implementations
  Messaging/        # Message queue implementations
  Storage/          # File storage implementations
```

**Refactoring Steps:**
1. Move EF Core DbContext to `Persistence/`
2. Move repository implementations to `Repositories/`
3. Extract external API clients to `Services/`
4. Configure entity mappings with Fluent API
5. Implement repository interfaces from Domain
6. Remove direct DB access from Application/API layers

**Example Repository:**
```csharp
namespace ProjectName.Infrastructure.Repositories;

public sealed class ${EntityName}Repository : I${EntityName}Repository
{
    private readonly ApplicationDbContext _context;

    public ${EntityName}Repository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<${EntityName}?> GetByIdAsync(int id, CancellationToken cancellationToken)
    {
        return await _context.${EntityName}s
            .AsNoTracking()
            .FirstOrDefaultAsync(e => e.Id == id, cancellationToken);
    }

    public async Task AddAsync(${EntityName} entity, CancellationToken cancellationToken)
    {
        await _context.${EntityName}s.AddAsync(entity, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
    }
}
```

### 4. API/Presentation Layer (Entry Point)
**Purpose:** HTTP endpoints, authentication, Swagger  
**Dependencies:** Application layer (uses commands/queries via MediatR)  
**Location:** `src/ProjectName.Api/`

```
Api/
  Controllers/       # Thin controllers (delegate to MediatR)
  Middleware/        # Exception handling, logging
  Filters/          # Action filters, authorization
  Configuration/    # Startup configuration
  Properties/       # Launch settings
```

**Refactoring Steps:**
1. Thin down controllers - only routing and delegation
2. Move business logic to Application handlers
3. Add middleware for exception handling
4. Configure dependency injection in Program.cs
5. Add Swagger/OpenAPI documentation
6. Remove direct repository/DbContext access

**Example Controller:**
```csharp
[ApiController]
[Route("api/[controller]")]
public sealed class ${EntityName}Controller : ControllerBase
{
    private readonly IMediator _mediator;

    public ${EntityName}Controller(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
    [ProducesResponseType(typeof(${EntityName}Response), StatusCodes.Status201Created)]
    public async Task<ActionResult<${EntityName}Response>> Create(
        [FromBody] Create${EntityName}Request request,
        CancellationToken cancellationToken)
    {
        var command = new Create${EntityName}Command(request);
        var result = await _mediator.Send(command, cancellationToken);
        
        return result.IsSuccess 
            ? CreatedAtAction(nameof(GetById), new { id = result.Value.Id }, result.Value)
            : BadRequest(result.Error);
    }
}
```

## Refactoring Process

### Phase 1: Analysis
1. Identify current architecture patterns
2. Map dependencies between components
3. Locate business logic scattered across layers
4. Document data flow and external dependencies
5. Assess test coverage and quality

### Phase 2: Domain Extraction
1. Create Domain project
2. Extract business entities with behavior
3. Move value objects and enums
4. Define repository interfaces
5. Remove infrastructure dependencies
6. Add domain exceptions

### Phase 3: Application Layer
1. Create Application project
2. Add MediatR for CQRS
3. Create commands/queries for use cases
4. Extract handlers from controllers/services
5. Create DTOs for API contracts
6. Add FluentValidation for requests
7. Implement mappers (Entity ↔ DTO)

### Phase 4: Infrastructure Separation
1. Create Infrastructure project
2. Move EF Core DbContext
3. Implement repositories
4. Configure entity mappings
5. Extract external service clients
6. Add caching/messaging implementations

### Phase 5: API Simplification
1. Thin down controllers
2. Remove business logic
3. Delegate to MediatR handlers
4. Add exception middleware
5. Configure DI in Program.cs
6. Update Swagger documentation

### Phase 6: Testing Refactor
1. Update unit tests for domain entities
2. Add handler tests with mocks
3. Create integration tests for repositories
4. Add API integration tests
5. Verify test coverage >= 80%

## Dependency Injection Configuration

### Program.cs
```csharp
var builder = WebApplication.CreateBuilder(args);

// Application services
builder.Services.AddMediatR(cfg => 
    cfg.RegisterServicesFromAssembly(typeof(Application.AssemblyMarker).Assembly));
builder.Services.AddValidatorsFromAssembly(typeof(Application.AssemblyMarker).Assembly);

// Infrastructure services
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<I${EntityName}Repository, ${EntityName}Repository>();

// API services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Middleware pipeline
app.UseExceptionHandler("/error");
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

## Quality Checklist
- [ ] Domain layer has no external dependencies
- [ ] Application layer depends only on Domain
- [ ] Infrastructure implements interfaces from Domain
- [ ] API controllers are thin (delegate to MediatR)
- [ ] Business logic in domain entities/handlers
- [ ] Repository pattern for data access
- [ ] CQRS with commands and queries
- [ ] DTOs for API contracts (no entities exposed)
- [ ] FluentValidation for input validation
- [ ] Exception handling middleware
- [ ] Dependency injection properly configured
- [ ] Tests updated for new structure
- [ ] Test coverage >= 80%
- [ ] No circular dependencies
- [ ] SOLID principles followed

## Common Refactoring Patterns

### Move Business Logic to Domain
**Before:** Logic in controller or service
```csharp
public async Task<IActionResult> UpdatePrice(int id, decimal newPrice)
{
    var product = await _context.Products.FindAsync(id);
    if (newPrice <= 0) return BadRequest("Invalid price");
    if (newPrice > product.MaxPrice) return BadRequest("Price too high");
    product.Price = newPrice;
    await _context.SaveChangesAsync();
    return Ok();
}
```

**After:** Logic in entity
```csharp
// Domain Entity
public void UpdatePrice(decimal newPrice)
{
    if (newPrice <= 0)
        throw new DomainException("Price must be positive");
    if (newPrice > MaxPrice)
        throw new DomainException($"Price cannot exceed {MaxPrice}");
    Price = newPrice;
}

// Controller
var command = new UpdateProductPriceCommand(id, request.NewPrice);
var result = await _mediator.Send(command);
return result.IsSuccess ? Ok() : BadRequest(result.Error);
```

### Extract to CQRS Handler
**Before:** Controller with business logic
```csharp
[HttpGet("{id}")]
public async Task<IActionResult> Get(int id)
{
    var entity = await _context.Entities
        .Include(e => e.Related)
        .FirstOrDefaultAsync(e => e.Id == id);
    
    if (entity == null) return NotFound();
    
    var dto = new EntityDto
    {
        Id = entity.Id,
        Name = entity.Name,
        // Complex mapping...
    };
    
    return Ok(dto);
}
```

**After:** Query handler
```csharp
// Query
public sealed record GetEntityQuery(int Id) : IRequest<Result<EntityResponse>>;

// Handler
public sealed class GetEntityHandler : IRequestHandler<GetEntityQuery, Result<EntityResponse>>
{
    private readonly IEntityRepository _repository;
    
    public async Task<Result<EntityResponse>> Handle(
        GetEntityQuery query,
        CancellationToken cancellationToken)
    {
        var entity = await _repository.GetByIdAsync(query.Id, cancellationToken);
        if (entity == null)
            return Result<EntityResponse>.Failure("Entity not found");
        
        return Result<EntityResponse>.Success(EntityMapper.ToResponse(entity));
    }
}

// Controller
[HttpGet("{id}")]
public async Task<ActionResult<EntityResponse>> Get(int id)
{
    var query = new GetEntityQuery(id);
    var result = await _mediator.Send(query);
    return result.IsSuccess ? Ok(result.Value) : NotFound();
}
```

Generate refactoring plan and execute transformation to Clean Architecture.