---
applyTo: "**/README.md"
priority: medium
---

# Template Usage
ALWAYS use template .github/templates/readme-template.md as base for standard structure.

# Required Structure
Introduction, Table of Contents, Installation, Quick Start, Usage Examples, API Reference, Build and Tests, Contributing, Dependencies, References.

# Introduction
Problem solved, context, technical approach; key features with checkmarks.

```markdown
## Features

- ✅ Dynamic query building with LINQ expressions
- ✅ Type-safe filtering and sorting
- ✅ Extensible validator framework
- ✅ Multi-target .NET 8.0 and .NET 9.0 support
```

# Table of Contents
Links to all main sections.

# Installation
.NET CLI commands and PackageReference.
```bash
dotnet add package NetToolsKit.DynamicQuery
```

# Quick Start
Minimal example in 3–5 lines.
```csharp
var query = QueryBuilder.Create<User>()
    .Where(u => u.Age > 18)
    .OrderBy(u => u.Name);
```

# Usage Examples
Typical and advanced cases with full code.

# API Reference
Key signatures, parameters and returns.

# Build and Tests
```bash
dotnet build
dotnet test --filter "Category=Unit"
dotnet format
```

# Contributing
Git flow, guidelines, semantic commits.

# Dependencies
Separate runtime and development.

# References
Technical links, issues, changelog.

# Format
Sections with separators (---); fenced code blocks; checkmarks for features; keep concise and practical.