# POML Templates and Fixtures

Standardized POML (Prompt Orchestration Markup Language) templates for versioning and managing prompts as code. Provides reusable prompt components with testing fixtures, style definitions, and integration patterns for .NET applications.

## Features

✅ **Prompts as Code:** Version control, review, and CI/CD integration
✅ **Reusable Styles:** Centralized tone, language, and guardrails
✅ **Type-Safe Schemas:** Validated inputs and outputs
✅ **Regression Testing:** Automated fixtures for quality assurance
✅ **Multi-Technique Support:** CoT, SoT, ToT, Self-Consistency
✅ **.NET Integration:** Direct rendering service and CLI options

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Available Templates](#available-templates)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Integration Options](#integration-options)
- [Quality Guidelines](#quality-guidelines)
- [References](#references)

---

## Installation

No installation required. This is a documentation and template directory within the repository.

For POML rendering integration:

```bash
# Option 1: Use existing POML service
# Add HTTP client to call rendering endpoint

# Option 2: Install POML CLI (if using build-time rendering)
npm install -g @microsoft/poml-cli
```

---

## Quick Start

Create a new POML template:

```xml
<prompt>
  <meta version="1.0.0" owner="team" llm="gpt-4" temperature="0.2" />
  <role>Technical writer creating API documentation.</role>
  <task>Generate OpenAPI spec from code comments.</task>
  <constraints>
    <item>Valid OpenAPI 3.0 format</item>
    <item>Include all public endpoints</item>
  </constraints>
  <output format="json">{"openapi": "3.0.0", "paths": {}}</output>
</prompt>
```

Use in .NET application:

```csharp
var render = await http.PostAsJsonAsync("/render",
    new { template = "api-doc.poml", vars = inputData });
var messages = await render.Content.ReadFromJsonAsync<List<Message>>();
var result = await llm.CreateAsync(messages);
```

---

## Directory Structure

```
poml/
├── prompt-engineering-poml.md       # Complete POML and techniques guide
├── styles/
│   └── enterprise.poml              # Enterprise style (tone, guardrails)
├── templates/
│   ├── changelog-entry.poml         # CHANGELOG generator
│   └── unit-test-generator.poml     # Unit test generator
└── fixtures/
    └── [template-name]/
        ├── input.json               # Test input data
        └── expected.json            # Expected output
```

### Components

**Templates:** Reusable prompt definitions with metadata, constraints, and examples
**Styles:** Centralized tone, language settings, and refusal patterns
**Fixtures:** Test cases for regression validation

---

## Available Templates

### changelog-entry.poml

Generate semantic versioning compliant CHANGELOG entries.

**Input:**
```json
{
  "version": "1.2.0",
  "gitDiff": "+ Added feature\n~ Changed behavior\n* Fixed bug",
  "existingChangelog": "## [1.1.0] - 2025-11-01\n..."
}
```

**Output:** Markdown with categorized changes (Added, Changed, Fixed, etc.)

**Features:**
- Keep a Changelog 1.1.0 format
- Semantic Versioning 2.0.0 compliance
- ISO 8601 date formatting
- Automatic categorization

### unit-test-generator.poml

Generate comprehensive xUnit/NUnit unit tests following AAA pattern.

**Input:**
```json
{
  "classUnderTest": "OrderService",
  "testFramework": "xUnit",
  "sourceCode": "public decimal CalculateTotal(Order order) { ... }",
  "dependencies": ["IOrderRepository", "ILogger<OrderService>"]
}
```

**Output:** Complete C# test class with valid/invalid/edge cases

**Features:**
- AAA (Arrange-Act-Assert) pattern
- FluentAssertions usage
- NSubstitute mocking
- Comprehensive coverage (valid, invalid, edge, exception scenarios)

---

## Usage Examples

### Creating a Custom Template

```xml
<prompt>
  <meta version="1.0.0" owner="qa-team" llm="gpt-4" temperature="0.3" />

  <use style="./styles/enterprise.poml" />

  <role>QA engineer creating test scenarios.</role>

  <task>Generate test cases from user story acceptance criteria.</task>

  <context>
    <documents>
      <variable name="userStory" type="string" required="true" />
      <variable name="acceptanceCriteria" type="array" required="true" />
    </documents>
  </context>

  <constraints>
    <item>BDD format (Given-When-Then)</item>
    <item>Cover happy path and edge cases</item>
    <item>Include data-driven scenarios</item>
  </constraints>

  <output format="markdown">
Feature: {{featureName}}
Scenario: {{scenarioName}}
  Given {{precondition}}
  When {{action}}
  Then {{expectedResult}}
  </output>
</prompt>
```

### Using Reusable Styles

```xml
<!-- Define style once -->
<style name="enterprise">
  <tone>Professional, concise, objective</tone>
  <guardrails>
    <refusal>I cannot assist with that request.</refusal>
  </guardrails>
</style>

<!-- Reference in multiple templates -->
<prompt>
  <use style="./styles/enterprise.poml" />
  <!-- ... rest of template -->
</prompt>
```

### Advanced: Chain of Thought Pattern

```xml
<prompt>
  <role>Problem solver using step-by-step reasoning.</role>
  <task>Analyze API design trade-offs and recommend approach.</task>
  <constraints>
    <item>Reason through 3-6 steps</item>
    <item>Score each option 0-10</item>
    <item>Provide confidence level</item>
  </constraints>
  <output format="json">
{
  "steps": ["Step 1: ...", "Step 2: ..."],
  "recommendation": "REST API",
  "score": 8,
  "confidence": 0.85
}
  </output>
</prompt>
```

---

## Testing

### Regression Test Structure

```csharp
[Theory]
[MemberData(nameof(GetPromptFixtures))]
public async Task Template_WithFixture_ProducesExpectedOutput(
    string templatePath, FixtureData fixture)
{
    // Arrange
    var renderer = new PomlRenderer();

    // Act
    var result = await renderer.RenderAsync(templatePath, fixture.Input);

    // Assert
    var normalized = JsonNormalizer.Normalize(result);
    normalized.Should().BeEquivalentTo(fixture.Expected);
}
```

### Creating Test Fixtures

```
fixtures/
└── changelog-entry/
    ├── basic-fix/
    │   ├── input.json          # {"version": "0.1.5", "gitDiff": "..."}
    │   └── expected.md         # ## [0.1.5] - 2025-11-15\n### Fixed\n...
    └── multi-category/
        ├── input.json
        └── expected.md
```

**Run tests:**
```bash
dotnet test --filter "Category=PromptRegression"
```

---

## Integration Options

### Option A: HTTP Rendering Service

```csharp
public class PromptService
{
    private readonly HttpClient _http;

    public async Task<string> RenderPromptAsync(string template, object vars)
    {
        var response = await _http.PostAsJsonAsync("/render",
            new { template, vars });

        var messages = await response.Content
            .ReadFromJsonAsync<List<Message>>();

        return await _llm.CreateCompletionAsync(messages);
    }
}
```

### Option B: Build-Time CLI

```powershell
# Install POML CLI
npm install -g @microsoft/poml-cli

# Render templates at build time
poml-cli render ./prompts/poml/templates/*.poml `
    --output ./dist/prompts `
    --validate

# Include in build script
dotnet build && poml-cli render ...
```

---

## Quality Guidelines

### Template Creation Checklist

- [ ] `<meta>` includes version, owner, updated, LLM settings
- [ ] `<role>` and `<task>` are clear and specific
- [ ] `<constraints>` define explicit limits
- [ ] `<output>` has concrete schema (JSON/Markdown)
- [ ] Included ≥2 `<example>` (happy path + edge case)
- [ ] Test fixtures created in `fixtures/[template-name]/`
- [ ] Reusable style referenced via `<use style>`
- [ ] Documentation updated

### Versioning Strategy

Each template maintains history in `<meta>` block:

```xml
<meta
  version="1.0.0"
  owner="devops-team"
  updated="2025-11-15"
  changelog="Added support for Security category"
  llm="gpt-4"
  temperature="0.2"
  maxTokens="1000"
  costTarget="0.01"
  latencyTarget="3s"
/>
```

### Anti-Patterns to Avoid

❌ Generic templates mixing multiple tasks
❌ Outputs without defined schema
❌ Irrelevant context or data excess
❌ Absence of test fixtures
❌ Untracked changes (no version/changelog)
❌ Prompts without clear constraints

✅ One template = one measurable objective
✅ Validatable output schema
✅ Minimum necessary context
✅ Fixtures covering main cases
✅ Detailed changelog in meta
✅ Explicit and testable constraints

---

## References

### Documentation

- [Complete POML Guide](./prompt-engineering-poml.md) - Comprehensive guide with CoT, SoT, ToT, Self-Consistency
- [Prompt Templates Instructions](../../instructions/prompt-templates.instructions.md) - Repository prompt engineering standards
- [Microsoft POML Repository](https://github.com/microsoft/poml) - Official POML specification

### Standards

- [Keep a Changelog 1.1.0](https://keepachangelog.com/) - Changelog format standard
- [Semantic Versioning 2.0.0](https://semver.org/) - Version numbering convention

### Research Papers

- Wei et al. (2022). *Chain-of-Thought Prompting* (arXiv:2201.11903)
- Wang et al. (2023). *Self-Consistency* (arXiv:2203.11171)
- Yao et al. (2023). *Tree of Thoughts* (arXiv:2305.10601)

---

## License

This directory follows the repository's main license. See [LICENSE](../../../LICENSE) for details.
