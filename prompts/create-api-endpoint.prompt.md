---
description: Generate complete API endpoint with CQRS pattern (Controller + Command/Query + Handler)
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Create API Endpoint (CQRS)
Generate a complete API endpoint following Clean Architecture and CQRS pattern with MediatR.

## Instructions
Create API endpoint based on:
- [backend.instructions.md](../.github/instructions/backend.instructions.md)
- [clean-architecture-code.instructions.md](../.github/instructions/clean-architecture-code.instructions.md)
- [dotnet-csharp.instructions.md](../.github/instructions/dotnet-csharp.instructions.md)

## Input Variables
- `${input:endpointName:Endpoint name (e.g., CreateOrder)}` - The operation name
- `${input:operationType:Operation type (Command/Query)}` - CQRS operation type
- `${input:httpMethod:HTTP method (POST/GET/PUT/DELETE)}` - REST verb
- `${input:routeTemplate:Route template (e.g., api/orders)}` - API route
- `${input:requiresAuth:Requires authentication? (yes/no)}` - Auth requirement

## Architecture Layers

### 1. API Layer - Controller
**Location:** `src/ProjectName.Api/Controllers/${EntityName}Controller.cs`

```csharp
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ProjectName.Api.Controllers;

/// <summary>
/// API endpoints for ${EntityName} operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
${requiresAuth ? '[Authorize]' : ''}
public sealed class ${EntityName}Controller : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<${EntityName}Controller> _logger;

    public ${EntityName}Controller(IMediator mediator, ILogger<${EntityName}Controller> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    /// <summary>
    /// ${description}
    /// </summary>
    [Http${httpMethod}("${routeTemplate}")]
    [ProducesResponseType(typeof(${ResponseType}), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<${ResponseType}>> ${endpointName}(
        [FromBody] ${RequestType} request,
        CancellationToken cancellationToken)
    {
        try
        {
            var command = new ${endpointName}Command(request);
            var result = await _mediator.Send(command, cancellationToken);
            
            return result.IsSuccess 
                ? Ok(result.Value) 
                : BadRequest(new ProblemDetails { Detail = result.Error });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing {Operation}", nameof(${endpointName}));
            return StatusCode(500, new ProblemDetails { Detail = "An error occurred processing your request" });
        }
    }
}
```

### 2. Application Layer - Command/Query
**Location:** `src/ProjectName.Application/${Feature}/Commands/${endpointName}Command.cs`

```csharp
using MediatR;
using ProjectName.Application.Common;

namespace ProjectName.Application.${Feature}.Commands;

/// <summary>
/// ${operationType} to ${description}
/// </summary>
public sealed record ${endpointName}Command(${RequestType} Request) : IRequest<Result<${ResponseType}>>;
```

### 3. Application Layer - Handler
**Location:** `src/ProjectName.Application/${Feature}/Handlers/${endpointName}Handler.cs`

```csharp
using MediatR;
using Microsoft.Extensions.Logging;
using ProjectName.Domain.Interfaces;
using ProjectName.Application.Common;

namespace ProjectName.Application.${Feature}.Handlers;

/// <summary>
/// Handler for ${endpointName}Command
/// </summary>
public sealed class ${endpointName}Handler : IRequestHandler<${endpointName}Command, Result<${ResponseType}>>
{
    private readonly I${EntityName}Repository _repository;
    private readonly ILogger<${endpointName}Handler> _logger;

    public ${endpointName}Handler(
        I${EntityName}Repository repository,
        ILogger<${endpointName}Handler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<Result<${ResponseType}>> Handle(
        ${endpointName}Command command,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Executing {Command}", nameof(${endpointName}Command));

            // Validation
            var validationResult = ValidateCommand(command);
            if (validationResult.IsFailure)
                return Result<${ResponseType}>.Failure(validationResult.Error);

            // Business logic
            var entity = MapToEntity(command.Request);
            
            // Repository operation
            await _repository.${RepositoryMethod}(entity, cancellationToken);

            // Map to response
            var response = MapToResponse(entity);

            return Result<${ResponseType}>.Success(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling {Command}", nameof(${endpointName}Command));
            return Result<${ResponseType}>.Failure("An error occurred processing the request");
        }
    }

    private static Result ValidateCommand(${endpointName}Command command)
    {
        // Add validation logic
        if (string.IsNullOrWhiteSpace(command.Request.PropertyName))
            return Result.Failure("PropertyName is required");

        return Result.Success();
    }

    private static ${EntityName} MapToEntity(${RequestType} request)
    {
        // Mapping logic
        return new ${EntityName}
        {
            // Properties
        };
    }

    private static ${ResponseType} MapToResponse(${EntityName} entity)
    {
        // Mapping logic
        return new ${ResponseType}
        {
            // Properties
        };
    }
}
```

### 4. Application Layer - DTOs
**Location:** `src/ProjectName.Application/${Feature}/Dtos/`

```csharp
namespace ProjectName.Application.${Feature}.Dtos;

/// <summary>
/// Request DTO for ${endpointName}
/// </summary>
public sealed record ${RequestType}
{
    public string PropertyName { get; init; } = string.Empty;
    // Additional properties
}

/// <summary>
/// Response DTO for ${endpointName}
/// </summary>
public sealed record ${ResponseType}
{
    public int Id { get; init; }
    public string PropertyName { get; init; } = string.Empty;
    // Additional properties
}
```

### 5. Application Layer - Validator (Optional)
**Location:** `src/ProjectName.Application/${Feature}/Validators/${endpointName}Validator.cs`

```csharp
using FluentValidation;

namespace ProjectName.Application.${Feature}.Validators;

public sealed class ${endpointName}Validator : AbstractValidator<${endpointName}Command>
{
    public ${endpointName}Validator()
    {
        RuleFor(x => x.Request.PropertyName)
            .NotEmpty().WithMessage("PropertyName is required")
            .MaximumLength(200).WithMessage("PropertyName must not exceed 200 characters");
    }
}
```

## OpenAPI Documentation
Add Swagger annotations to controller:
```csharp
[SwaggerOperation(
    Summary = "${summary}",
    Description = "${detailedDescription}",
    Tags = new[] { "${EntityName}" }
)]
[SwaggerResponse(200, "Success", typeof(${ResponseType}))]
[SwaggerResponse(400, "Bad Request", typeof(ProblemDetails))]
[SwaggerResponse(401, "Unauthorized")]
[SwaggerResponse(500, "Internal Server Error", typeof(ProblemDetails))]
```

## Dependency Injection Registration
Add to `Program.cs` or `ServiceExtensions.cs`:
```csharp
services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));
services.AddScoped<I${EntityName}Repository, ${EntityName}Repository>();
services.AddValidatorsFromAssemblyContaining<${endpointName}Validator>();
```

## Testing Checklist
- [ ] Unit tests for handler logic
- [ ] Validation tests for all edge cases
- [ ] Integration tests for full endpoint
- [ ] OpenAPI documentation generated correctly
- [ ] Authentication/authorization enforced if required

Generate complete CQRS endpoint following all Clean Architecture principles.