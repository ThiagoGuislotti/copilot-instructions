---
description: Testing standards and best practices for NetToolsKit CLI
applyTo: '**/*.rs'
priority: high
---

# Testing Standards

All code must follow these testing standards to ensure quality and maintainability.

## Core Principles

1. **Test Coverage**: Every public API must have tests
2. **Test Organization**: Use dedicated test files, not just inline tests
3. **Test Naming**: Descriptive names following `test_[function]_[scenario]_[result]` pattern
4. **Documentation**: All test files must have file-level doc comments

## File Organization

**MANDATORY PATTERN**: All crates MUST use `test_suite.rs` as the entry point.

```
crates/my-crate/
├── src/
│   ├── lib.rs
│   ├── module.rs          # May have inline tests for private functions
│   └── error.rs
└── tests/
    ├── test_suite.rs      # REQUIRED: Main test entry point
    ├── error_tests.rs     # REQUIRED for all crates
    ├── module_tests.rs    # Unit tests for public API
    └── integration_tests.rs
```

### test_suite.rs Structure (REQUIRED)

Every crate MUST have `tests/test_suite.rs` as the single test entry point:

```rust
//! [Crate Name] Test Suite Entry Point
//!
//! Main test suite aggregator for [crate-name] crate.
//! All module tests are organized to mirror the src/ directory structure.

// Module-specific test suites
mod error_tests;
mod module_tests;
mod integration_tests;

// For subdirectories, use #[path] attribute:
#[path = "subdir/mod.rs"]
mod subdir;
```

**Critical Rules**:
1. ✅ **ALWAYS** use `test_suite.rs` as the entry point
2. ✅ Import all test modules in test_suite.rs
3. ✅ Mirror src/ structure in tests/
4. ✅ Use `#[path]` for subdirectories
5. ❌ **NEVER** use `lib.rs` in tests/
6. ❌ **NEVER** use individual test files without test_suite.rs
7. ❌ **NEVER** use Cargo.toml `[[test]]` sections (except for special cases)

## Required Test Files

### 1. error_tests.rs (MANDATORY)
Every crate MUST have `tests/error_tests.rs` testing:
- All error variants Display implementation
- All error variants Debug formatting
- All From<T> conversions
- Error propagation with `?` operator
- Result type alias (if exists)

**Template:** `.github/templates/rust-error-tests-template.rs`

### 2. integration_tests.rs (RECOMMENDED)
For crates with multi-component workflows:
- End-to-end workflows
- Component interaction
- Real dependency usage (filesystem, network)
- Idempotency tests

**Template:** `.github/templates/rust-integration-tests-template.rs`

### 3. [module]_tests.rs (REQUIRED)
One test file per public module testing:
- Constructor and initialization
- Happy path for all public functions
- Error cases
- Edge cases (empty, boundary, unicode, special chars)
- Trait implementations (Debug, Clone, PartialEq)

**Template:** `.github/templates/rust-unit-tests-template.rs`

### 4. Async Tests (when applicable)
For async code:
- Use `#[tokio::test]`
- Test success paths
- Test timeout scenarios
- Test cancellation
- Test concurrent execution

**Template:** `.github/templates/rust-async-tests-template.rs`

## Naming Conventions

### Test Functions
```rust
// ✅ GOOD - Descriptive and specific
#[test]
fn test_parse_valid_yaml_returns_manifest()
fn test_parse_empty_file_returns_error()

#[tokio::test]
async fn test_execute_command_with_timeout_succeeds()

// ❌ BAD - Vague or generic
#[test]
fn test_parse()
fn it_works()
```

### Pattern
```
test_[function_name]_[scenario]_[expected_result]
test_[operation]_[condition]
```

## Test Structure

### File Header
```rust
/// Tests for [Module] - [Purpose]
///
/// Validates [what this file tests in detail]

use crate::{Module, Types};
use std::...;
```

### Test Groups and AAA Pattern

**MANDATORY**: All tests MUST use AAA (Arrange, Act, Assert) pattern with Rust idiomatic style:

```rust
// Happy Path Tests

#[test]
fn test_function_success() {
    // Arrange
    // Setup: prepare test data, mocks, and initial state
    let input = "test";
    let expected = "expected_result";

    // Act
    // Execute: run the code under test
    let result = function(input);

    // Assert
    // Verify: check the results match expectations
    assert_eq!(result, expected);
}

// Error Handling Tests

#[test]
fn test_function_invalid_input() {
    // Arrange
    let invalid_input = "";

    // Act
    let result = function(invalid_input);

    // Assert
    // Critical: must return specific error type
    assert!(result.is_err());
    assert!(matches!(result.unwrap_err(), Error::InvalidInput));
}

// Edge Cases

#[test]
fn test_function_boundary_condition() {
    // Arrange
    // Critical: test maximum allowed value
    let boundary_value = usize::MAX;

    // Act
    let result = function(boundary_value);

    // Assert
    assert!(result.is_ok());
}
```

**AAA Pattern Rules**:
1. **Arrange**: Setup all test data, mocks, and preconditions
2. **Act**: Execute ONE operation (the code being tested)
3. **Assert**: Verify ONE logical concept (may have multiple assert statements)
4. **Comments**: Add explanatory comment below AAA marker ONLY when:
   - Critical business logic requires explanation
   - Complex setup needs clarification
   - Non-obvious assertion logic
   - Security or data integrity concerns

**Style Guidelines**:
- ✅ Use simple comment separators (e.g., `// Happy Path Tests`)
- ❌ NO decorative separators (e.g., `// ============`)
- ✅ Blank line between AAA sections for readability
- ✅ One blank line between tests
- ✅ Group related tests under descriptive section comments

## Critical Test Coverage

### Error Types (100% Required)
```rust
#[test]
fn test_error_display_[variant]() {
    // Arrange
    let error = Error::Variant("detail".to_string());

    // Act
    let display = error.to_string();

    // Assert
    assert_eq!(display, "expected message");
}

#[test]
fn test_error_from_[source_type]() {
    // Arrange
    let source = SourceError::new();

    // Act
    let error = Error::from(source);

    // Assert
    assert!(matches!(error, Error::Variant(_)));
}

#[test]
fn test_error_propagation() {
    // Arrange
    fn fail() -> Result<()> {
        Err(Error::Variant("test".to_string()))
    }

    // Act
    let result = fail();

    // Assert
    assert!(result.is_err());
}
```

### Async Operations
```rust
#[tokio::test]
async fn test_async_operation_success() {
    // Act
    let result = async_function().await;

    // Assert
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_async_operation_timeout() {
    // Arrange
    use tokio::time::{timeout, Duration};

    // Act
    let result = timeout(
        Duration::from_millis(10),
        slow_operation()
    ).await;

    assert!(result.is_err());
}

#[tokio::test]
async fn test_async_operation_cancellation() {
    let token = CancellationToken::new();
    token.cancel();

    let result = token.with_cancellation(operation()).await;
    assert!(result.is_err());
}
```

### Integration Tests
```rust
#[tokio::test]
async fn test_end_to_end_workflow() {
    // Arrange
    let temp_dir = TempDir::new().unwrap();
    let input = create_test_data();

    // Act
    let result = execute_workflow(&temp_dir, input).await;

    // Assert
    assert!(result.is_ok());
    verify_output(&temp_dir);
}
```

## Coverage Targets

| Test Type | Target | Priority |
|-----------|--------|----------|
| Error tests | 100% error types | CRITICAL |
| Happy path | 100% public API | HIGH |
| Error cases | 80%+ error paths | HIGH |
| Edge cases | 70%+ boundaries | MEDIUM |
| Integration | Key workflows | MEDIUM |

## Pre-Commit Checklist

Before committing code:
- [ ] All new public functions have tests
- [ ] Error types have complete test coverage
- [ ] Test names are descriptive
- [ ] File-level doc comments exist
- [ ] All tests pass: `cargo test`
- [ ] No `#[ignore]` without documented reason
- [ ] Temporary files cleaned up (use TempDir)

## Common Patterns

### Testing with Temp Files
```rust
use tempfile::TempDir;

#[test]
fn test_with_filesystem() {
    let temp_dir = TempDir::new().unwrap();
    let file_path = temp_dir.path().join("test.txt");

    // Test code using file_path

    // temp_dir automatically cleaned up on drop
}
```

### Testing Error Messages
```rust
#[test]
fn test_error_message_contains_detail() {
    let error = process_invalid_input("bad");

    assert!(error.is_err());
    let err_msg = error.unwrap_err().to_string();
    assert!(err_msg.contains("bad"));
    assert!(err_msg.contains("invalid"));
}
```

### Testing Trait Implementations
```rust
#[test]
fn test_debug_implementation() {
    let instance = MyStruct::new("test");
    let debug = format!("{:?}", instance);

    assert!(debug.contains("MyStruct"));
    assert!(debug.contains("test"));
}

#[test]
fn test_clone_implementation() {
    let original = MyStruct::new("test");
    let cloned = original.clone();

    assert_eq!(original.field(), cloned.field());
}
```

## Anti-Patterns to Avoid

### ❌ Don't: Vague test names
```rust
#[test]
fn test_something() { } // What does it test?
```

### ❌ Don't: Missing error tests
```rust
// Only testing happy path
#[test]
fn test_parse() {
    assert!(parse("valid").is_ok());
}
// Where are the error tests?
```

### ❌ Don't: No cleanup
```rust
#[test]
fn test_file() {
    std::fs::write("test.txt", "data").unwrap();
    // File left behind! Use TempDir
}
```

### ❌ Don't: Testing private implementation details
```rust
#[test]
fn test_internal_field_value() {
    // Testing internal state that could change
}
```

### ✅ Do: Test public behavior
```rust
#[test]
fn test_public_api_contract() {
    // Testing observable behavior
}
```

## Critical: Cargo test discovery rules

**WARNING**: Cargo treats ANY `.rs` file in `tests/` as an independent integration test binary!

### ❌ WRONG - Cargo runs each file independently
```
tests/
├── error_tests.rs    # ❌ Treated as separate test binary
├── module_tests.rs   # ❌ Treated as separate test binary
└── common/
    └── mod.rs        # ✅ OK - subdirectory not treated as test
```

### ✅ CORRECT - Use test_suite.rs as entry point
```
tests/
├── test_suite.rs     # ✅ ONLY test binary
├── common/
│   └── mod.rs        # ✅ Helper module
└── modules/
    ├── errors.rs     # ✅ Imported by test_suite.rs
    └── module.rs     # ✅ Imported by test_suite.rs
```

**Key Rules**:
1. Only `test_suite.rs` should be at tests/ root level
2. All other `.rs` files MUST be in subdirectories
3. Use `pub mod` in test_suite.rs for subdirectories
4. Never use `[[test]]` sections in Cargo.toml (except special cases)
5. Files in subdirectories are treated as modules, not test binaries

## Verification Checklist

Before completing ANY test-related work, verify:

- [ ] `tests/test_suite.rs` exists and is the ONLY .rs file at root level
- [ ] All test modules are in `tests/modules/` or similar subdirectory
- [ ] test_suite.rs imports ALL test modules (no orphaned files)
- [ ] Shared utilities in `tests/common/` or similar
- [ ] No `[[test]]` sections in Cargo.toml
- [ ] Run `cargo test --package <crate>` to confirm all tests execute
- [ ] Verify test count matches expected (no missing tests)

## Resources

- **Templates:** `.github/templates/*_template.rs`
- **Full Guide:** `tools/nettoolskit-cli/docs/test-templates.md`
- **Standards Analysis:** `tools/nettoolskit-cli/docs/test-standards-analysis.md`
- **Rust Book Testing:** https://doc.rust-lang.org/book/ch11-00-testing.html
- **Tokio Testing:** https://tokio.rs/tokio/topics/testing

## Enforcement

These standards are:
- ✅ Enforced in PR reviews
- ✅ Validated by CI/CD
- ✅ Required for all new code
- ✅ Applied to refactored code

Non-compliance blocks merge.

## Questions?

Refer to:
1. Templates in `.github/templates/`
2. Full documentation in `tools/nettoolskit-cli/docs/`
3. Existing tests in `crates/commands/tests/` (best practices)