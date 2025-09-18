---
description: Create a new .NET class following repository templates and conventions
mode: edit
tools: ['codebase', 'readFile']
---

# Create .NET Class

Generate a new .NET class following the repository's established patterns and Clean Architecture principles.

## Instructions

Create a new C# class based on:
- [dotnet-class-template.cs](../templates/dotnet-class-template.cs)
- [dotnet-csharp.instructions.md](../instructions/dotnet-csharp.instructions.md)
- [clean-architecture-code.instructions.md](../instructions/clean-architecture-code.instructions.md)

## Input Variables
- `${input:className:Class name (PascalCase)}` - The class name
- `${input:namespace:Namespace}` - Project namespace
- `${input:interface:Interface name (optional)}` - Implemented interface
- `${input:layer:Architecture layer (Domain/Application/Infrastructure)}` - Which layer this belongs to

## Requirements

### Structure
- Use `#region` organization (Fields, Properties, Constructors, Methods)
- Follow PascalCase for public members, camelCase for parameters
- Include XML documentation for public APIs
- Ensure namespace matches folder structure

### Architecture Compliance
- Domain: Pure business logic, no external dependencies
- Application: Orchestrates use cases, depends only on Domain
- Infrastructure: External concerns, implements Domain interfaces

### Code Quality
- Use appropriate async/await patterns
- Include proper error handling
- Follow dependency injection patterns
- Add CancellationToken parameters for async methods

## Template Usage
Replace placeholders in the template:
- `[ClassName]` → `${className}`
- `[Namespace]` → `${namespace}`
- `[InterfaceName]` → `${interface}` (if provided)
- Add constructor injection for dependencies
- Include appropriate XML documentation

Generate clean, production-ready code that follows all established conventions.