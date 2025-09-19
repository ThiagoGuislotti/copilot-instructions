---
applyTo: ".github/instructions/*"
---

# Instruction Creation Standards

## Content Format
- Prefer plain text over complex formatting
- Allow bullet lists when they improve clarity (e.g., references, checklists)
- Use markdown headings strategically with hierarchy (# always, ## sparingly, ### last resort)
- Do not use inline code backticks for paths, types or commands
- Header must follow template exactly
- Semicolon-separated single-line paragraphs are preferred
- Actionable information only
- Pattern [area].instructions.md
- Examples inline prefixed with "Example:"
```markdown
# Main Section
- Bullet point example
- Another point with technical detail

## Subsection (use sparingly)
Technical content with code blocks when needed
```

## Heading Hierarchy
- Use # for primary sections to provide clear document structure
- Use ## sparingly for important subsections that need emphasis
- Use ### only as last resort for detailed breakdowns
- Avoid deeper nesting
- Ensure logical information hierarchy
- Maintain consistent formatting across all instruction files
```markdown
# Primary Section (always use)
Content for main topics

## Secondary Section (use sparingly)
Content for important subdivisions

### Tertiary Section (last resort)
Content for detailed breakdowns
```

## Code Examples
- Use code blocks for examples to illustrate technical guidance
- Specify language when possible (e.g., ```yaml, ```dockerfile, ```csharp)
- Keep examples concise and actionable
- Prefer real-world examples over placeholders
- Ensure examples are self-contained and runnable where possible

## Content Structure
- One paragraph per line for readability
- Internal blank lines allowed to separate rule groups
- When using lists put one item per line
- End file on last content character with no trailing blank line
- English only for consistency
- Precise technical terms over generic language
- Avoid filler words and redundancy
- Context before objective in explanations
- Measurable acceptance criteria when applicable
```markdown
Example paragraph structure:
Single line with specific technical guidance; semicolon separators for related concepts.

Next paragraph covers different aspect.
- Bullet point for specific requirement
- Another bullet with measurable criteria
```

# Instruction Content Requirements

## Essential Elements
- Include a concise project overview (elevator pitch)
- Identify the tech stack (backend, frontend, database, APIs and testing suites)
- Spell out coding guidelines such as naming conventions, formatting and test requirements
- Describe the project folder structure and note important subdirectories
- List available resources like scripts, build or test tools and MCP servers
- Ensure each instruction is self contained and broadly applicable
- Avoid overly restrictive or stylistic mandates
- Revisit and improve the instructions as the project evolves
- An imperfect file is better than none
```csharp
// Example of technical guidance with code context
public class OrderService : IOrderService
{
    // Follow repository patterns and dependency injection
    private readonly IOrderRepository _repository;

    public async Task<Order> CreateAsync(CreateOrderDto dto)
    {
        // Business validation in domain layer
        var order = Order.Create(dto);
        return await _repository.SaveAsync(order);
    }
}
```

# Critical Formatting Rules

## File Endings
- Enforce EOF rule (no trailing blank line/newline)
- Allow bullet lists as stated above
- Use markdown headings strategically (# for main sections, ## for subsections, ### for detailed breakdowns)
- Never use inline code backticks for paths, types or commands
```markdown
Correct: The OrderService class in Domain layer
Incorrect: The `OrderService` class in `Domain` layer
```

# Logical Structure and Organization

## Information Hierarchy
- Group related concepts together
- Descending order of importance
- Frequent patterns first
- Document edge cases after common scenarios
- Note interoperability and dependency chains
- Ensure clear separation between different topics
```markdown
# Most Important Topic First
Core concepts that apply broadly

## Secondary Important Topic
Specialized scenarios and patterns

### Edge Cases and Exceptions
Detailed breakdowns for complex situations
```

# File Management and Naming

## ApplyTo Globs
- Prefer specific folders and extensions over broad wildcards
- Avoid **/* unless orchestrator with explicit rationale
- Prefer src/area/**/*.ext for targeted coverage
- Validate coverage with validate-instructions.ps1
- Target real folders to optimize tokens
- Ensure patterns match actual project structure
```yaml
# Good examples
applyTo: "**/*.{cs,csproj}"
applyTo: "src/Domain/**/*.cs"
applyTo: "modules/Authentication/**/*.ts"

# Avoid overly broad
applyTo: "**/*"
```

## Naming Conventions
- File name must be area.instructions.md
- Area must be specific and match project structure
- Update mapping in README.md when adding new files
- Add reference in copilot-instructions.md
- Use descriptive names that clearly indicate scope
```markdown
Examples:
- clean-architecture-code.instructions.md
- dotnet-csharp.instructions.md
- microservices-performance.instructions.md
```

# Duplication and Inheritance Rules

## Avoiding Redundancy
- Never repeat global rules from copilot-instructions.md
- Centralize globals in copilot-instructions.md only
- Use explicit inheritance when applicable
- Ensure specialization without overlap
- Check for conflicts before adding new rules
- Domain-specific instructions should extend, not duplicate
```markdown
# Good: Domain-specific extension
Follow Clean Architecture patterns; use aggregate roots for consistency boundaries

# Bad: Duplicating global rule
Follow Clean Architecture patterns; always include AGENTS.md in context
```

# Maintenance and Evolution

## Versioning and Updates
- Create versioned CHANGELOG entry for significant changes
- Use git tags copilot-vX.Y.Z for major instruction updates
- Collect feedback from actual usage patterns
- Perform periodic reviews of instruction effectiveness
- Deprecate obsolete rules gradually with migration guidance
- Document impact on existing workflows
```bash
# Example versioning
git tag copilot-v1.2.0
git push origin copilot-v1.2.0
```

## Quality Assurance
- Validate with real use cases before finalizing
- Measure before/after metrics when possible
- Collect developer feedback through surveys or discussions
- Ensure coverage of critical scenarios
- Address knowledge gaps identified in practice
- Adjust based on data rather than assumptions
- Document lessons learned for future improvements
```markdown
Example metrics to track:
- Code review feedback frequency
- Build failure rates
- Developer question patterns
- Time to onboard new team members
```

# System Integration

## File References
- Update copilot-instructions.md with new instruction reference
- In copilot-instructions.md prefer bullet lists for readability
- Never wrap paths or types in backticks in instruction files
- Verify the inheritance hierarchy remains logical
- Confirm no conflicts with existing instructions
- Test integration with existing workflows
```markdown
# Update pattern in copilot-instructions.md
- New area: .github/instructions/new-area.instructions.md (description, examples)
```

## GitHub Changes Protocol
- Any change under .github requires a versioned CHANGELOG entry
- Document impact and usage examples
- Use github-change-checklist-template.md for verification
- Ensure backward compatibility when possible
- Communicate breaking changes clearly
```markdown
CHANGELOG format:
[1.2.0] - 2025-09-18
### Added
- New instruction-creation standards with code examples
- Heading hierarchy guidelines for better structure
```