---
description: Generate comprehensive unit tests following repository standards and AAA pattern
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Generate Unit Tests
Generate comprehensive unit tests for .NET classes following this repository's testing standards.

## Instructions
Generate unit tests based on:
- [dotnet-unit-test-template.cs](../templates/dotnet-unit-test-template.cs)
- [dotnet-csharp.instructions.md](../instructions/dotnet-csharp.instructions.md)
- Testing best practices for Clean Architecture

Requirements:
1. Follow AAA (Arrange, Act, Assert) pattern
2. Use proper test categorization with `[Trait("Category", "Unit")]`
3. Use appropriate mocking frameworks (NSubstitute preferred)
4. Follow proper test naming conventions
5. Include comprehensive scenario coverage

## Input Variables
- `${input:className:Class under test}` - The class being tested
- `${input:testFramework:Testing framework (xUnit/NUnit)}` - Framework to use
- `${selection}` - Selected code to test

## Test Structure Requirements

### Framework Support
- xUnit: Use `[Fact]`, `[Theory]`, `ITestOutputHelper`
- NUnit: Use `[Test]`, `[TestCase]`, `TestContext`
- Toggle with `#define UNIT_XUNIT` or `#define UNIT_NUNIT`

### Test Organization
```csharp
#region Test Methods - [MethodUnderTest] Valid Cases
#region Test Methods - [MethodUnderTest] Invalid Cases
#region Test Methods - [MethodUnderTest] Edge Cases
#region Test Methods - [MethodUnderTest] Exception Cases
```

### AAA Pattern
- Arrange: Set up test data and dependencies
- Act: Execute the method under test
- Assert: Verify expected outcomes using FluentAssertions

### Coverage Areas
- Valid inputs: Test successful execution paths
- Invalid inputs: Test validation and error handling
- Edge cases: Boundary conditions and special scenarios
- Exception scenarios: Test error handling

## Code Quality
- Use meaningful test names: `MethodName_Scenario_ExpectedResult`
- Include appropriate `[Category]` or `[Trait]` attributes
- Use test data builders for complex objects
- Mock external dependencies appropriately
- Ensure tests are deterministic and fast

Generate comprehensive, maintainable tests that provide confidence in the code's correctness.