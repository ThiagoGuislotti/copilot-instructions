---
applyTo: "**/*.rs"
priority: high
---

# Rust Code Organization

## Core Principles
Mirror src/ structure in tests/ exactly; production code in src/, tests in tests/; no #[cfg(test)] blocks in production; follow Rust module conventions; **group related types by functionality** - multiple structs/traits per file is idiomatic Rust.

> **Rule:** Test file structure MUST mirror source file structure.
> **Rule:** Files are organized by **module/functionality**, NOT by type. A file named `config.rs` can contain `LinearConfig`, `BsgsConfig`, and related types.
> **Rule:** Only split into separate files when a file exceeds ~300-500 lines or when types have distinct responsibilities.

## Documentation Standards
Doc comments must be complete and self-explanatory; describe purpose, inputs, outputs, errors, side effects, and invariants; avoid restating identifiers.
- Provide a clear summary sentence for every public item; describe behavior and side effects.
- Document arguments, return values, and error conditions for public functions; include explicit Panics, Errors, and Safety sections when relevant.
- Enable the missing_docs lint with crate-level attribute #![warn(missing_docs)] in the crate root; fix warnings instead of suppressing.

## Standard Layout

```
crates/my-crate/
├── src/
│   ├── lib.rs
│   ├── core/
│   │   ├── mod.rs
│   │   └── parser.rs
│   └── error.rs
└── tests/
    ├── test_suite.rs        # REQUIRED entry point
    ├── error_tests.rs       # REQUIRED for all crates
    └── core/
        ├── mod.rs
        └── parser_tests.rs  # Mirrors src/core/parser.rs
```

**Naming:** `feature.rs` → `feature_tests.rs` | `module/` → `module/`

---
## File Rules

### Source Files (src/)
**NO #[cfg(test)] ALLOWED**

```rust
// ❌ WRONG
pub fn calculate(x: i32) -> i32 { x * 2 }

#[cfg(test)]
mod tests { /* ... */ }
```

```rust
// ✅ CORRECT
/// Calculate double
pub fn calculate(x: i32) -> i32 { x * 2 }
```

### Test Files (tests/)
```rust
// tests/core/parser_tests.rs
//! Tests for core::parser module

use my_crate::core::parser::{parse_config, ParseError};

#[test]
fn test_parse_config_valid() {
    assert!(parse_config("key=value").is_ok());
}
```

### Test Modules (tests/module/mod.rs)
```rust
// tests/core/mod.rs
pub mod config_tests;
pub mod parser_tests;
```

### Test Suite Entry (tests/test_suite.rs)
**REQUIRED**

```rust
//! [Crate] Test Suite Entry Point

mod error_tests;

mod core {
    pub mod config_tests;
    pub mod parser_tests;
}
```

## Module Organization Patterns

### Rust Idiomatic Module Organization

**Key Principle:** Rust organizes code by **functionality/domain**, not by type. This differs from Java/C# where each class has its own file.

**Rust Standard Library Examples:**
- `std::collections` has `HashMap`, `HashSet`, `BTreeMap` in related modules
- `std::io` has `Read`, `Write`, `BufReader`, `BufWriter` together
- `std::sync` groups `Arc`, `Mutex`, `RwLock` by domain

**When to Split Files:**
- File exceeds ~300-500 lines
- Types have distinct, unrelated responsibilities
- Complex implementations benefit from isolation

**When to Keep Together:**
- Types are used together (e.g., `Config` and `ConfigBuilder`)
- Types share the same domain (e.g., `LinearConfig`, `BsgsConfig`)
- Types are tightly coupled (e.g., `Algorithm` trait and `AlgorithmInfo`)

### Pattern 1: Simple Module

**Source:**
```
src/
└── formatter.rs          # Simple module
```

**Tests:**
```
tests/
├── test_suite.rs         # Entry point
└── formatter_tests.rs    # Direct test file
```

**test_suite.rs:**
```rust
mod formatter_tests;
```

### Pattern 2: Module with Submodules

**Source:**
```
src/
└── rendering/
    ├── mod.rs            # Module root
    ├── colors.rs
    └── style.rs
```

**Tests:**
```
tests/
├── test_suite.rs
└── rendering/
    ├── mod.rs            # Test module root
    ├── colors_tests.rs
    └── style_tests.rs
```

**test_suite.rs:**
```rust
mod rendering {
    pub mod colors_tests;
    pub mod style_tests;
}
```

**tests/rendering/mod.rs:**
```rust
//! Rendering module test suite

pub mod colors_tests;
pub mod style_tests;
```

### Deep Hierarchy
```
src/ui/core/colors.rs → tests/ui/core/colors_tests.rs

test_suite.rs:
mod ui { pub mod core { pub mod colors_tests; } }
```

---
## Code Organization: Modules by Functionality

### Rule: Group Related Types by Domain/Functionality

**Rationale:** Unlike Java/C# (1 class = 1 file), Rust organizes by **module/functionality**. The file name represents the domain, and can contain multiple related types.

**Rust Conventions:**
- `algorithm.rs` can contain `Algorithm` trait + `AlgorithmInfo` struct
- `config.rs` can contain `Config`, `LinearConfig`, `BsgsConfig`
- `result.rs` can contain `SearchResult`, `FoundState`, related types

**File Naming:**
- Name files by **domain/purpose**: `config.rs`, `algorithm.rs`, `result.rs`
- NOT by type name: ~~`search_result.rs`~~, ~~`algorithm_trait.rs`~~, ~~`linear_config.rs`~~

**Benefits:**
- Reduces file proliferation
- Related code stays together
- Easier navigation by concept
- Matches Rust std library patterns

### Pattern: Domain-Based Organization

**Recommended Structure (✅):**
```
src/algorithms/
├── mod.rs              # Re-exports
├── common/
│   ├── mod.rs
│   ├── algorithm.rs    # Algorithm trait + AlgorithmInfo
│   ├── config.rs       # CommonConfig + AlgorithmConfig trait
│   ├── result.rs       # SearchResult struct
│   └── found_state.rs  # FoundState (atomic state)
├── linear/
│   ├── mod.rs
│   ├── algorithm.rs    # LinearAlgorithm
│   └── config.rs       # LinearConfig
└── bsgs/
    ├── mod.rs
    ├── algorithm.rs    # BsgsAlgorithm
    └── config.rs       # BsgsConfig
```

**NOT Recommended (❌ - Java/C# style):**
```
src/algorithms/
├── algorithm_trait.rs
├── algorithm_info.rs
├── common_config.rs
├── algorithm_config_trait.rs
├── search_result.rs
├── found_state.rs
├── linear_algorithm.rs
├── linear_config.rs
├── bsgs_algorithm.rs
└── bsgs_config.rs
```

### When to Keep Together vs Separate

**Keep Together (in same file):**
- ✅ Related types in same domain (Config variants)
- ✅ Trait + metadata struct (Algorithm + AlgorithmInfo)
- ✅ Enum + impl block (single responsibility)
- ✅ Struct + builder pattern
- ✅ Types that are always used together

**Separate Files:**
- ❌ File exceeds 300-500 lines
- ❌ Types have completely unrelated concerns
- ❌ Types need different dependencies/imports
- ❌ Distinct testing requirements

---
## Test Template

```rust
//! Tests for [module::path]
//!
//! Basic | Edge cases | Errors

use crate_name::module::Item;

// ============================================================================
// Basic Tests
// ============================================================================

#[test]
fn test_item_creation_valid() {
    assert!(Item::new("valid").is_ok());
}

// ============================================================================
// Edge Cases
// ============================================================================

#[test]
fn test_item_empty_input() {
    assert!(Item::new("").is_err());
}

// ============================================================================
// Errors
// ============================================================================

#[test]
fn test_item_invalid_format() {
    assert!(matches!(Item::new("@"), Err(ItemError::InvalidFormat)));
}
```

## Migration Guidelines

### When Moving Tests from src/ to tests/

1. **Create mirror structure:**
   ```bash
   # For src/core/parser.rs
   mkdir -p tests/core
   touch tests/core/parser_tests.rs
   ```

2. **Move test code:**
   - Copy tests from `#[cfg(test)] mod tests`
   - Rename to descriptive test names
   - Update imports (use `crate_name::` not `super::`)

3. **Update module declarations:**
   - Add to `tests/core/mod.rs`
   - Add to `tests/test_suite.rs`

4. **Remove from source:**
   - Delete entire `#[cfg(test)]` block
   - Clean up any test-only helper functions

### Example Migration

**Before (src/parser.rs):**
```rust
pub fn parse(input: &str) -> Result<Config> {
    // implementation
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        assert!(parse("test").is_ok());
    }
}
```

**After (src/parser.rs):**
```rust
pub fn parse(input: &str) -> Result<Config> {
    // implementation
}
// No test code here!
```

**After (tests/parser_tests.rs):**
```rust
//! Tests for parser module

use my_crate::parser::parse;

#[test]
fn test_parse_valid_input_succeeds() {
    let result = parse("test");
    assert!(result.is_ok());
}

#[test]
fn test_parse_invalid_input_returns_error() {
    let result = parse("");
    assert!(result.is_err());
}
```

---
## Best Practices

**Naming:** `test_[function]_[scenario]_[result]` ✅ | `test1`, `it_works` ❌
**Isolation:** Each test independent; no shared state
**Grouping:** Use `// ======== Section ========` comments
**Helpers:** `tests/helpers/mod.rs` for shared utilities

```rust
// tests/helpers/mod.rs
pub fn create_test_config() -> Config { /* ... */ }
pub fn assert_error_contains(result: Result<()>, msg: &str) { /* ... */ }
```

**Common Patterns:**
```rust
#[tokio::test]
async fn test_async() { assert!(op().await.is_ok()); }

#[test]
fn test_error() { assert!(matches!(fail(), Err(MyError::Specific))); }

#[test]
#[should_panic(expected = "msg")]
fn test_panic() { panics(""); }
```

---
## Mandatory Requirements

### Error Tests
Every crate MUST have `tests/error_tests.rs`:
```rust
//! Error type tests

use my_crate::Error;

#[test]
fn test_error_display() {
    let msg = format!("{}", Error::InvalidInput("x".into()));
    assert!(msg.contains("Invalid"));
}

#[test]
fn test_error_source() {
    assert!(Error::Io(io_err).source().is_some());
}
```

### Code Review Checklist
- [ ] No `#[cfg(test)]` in src/
- [ ] tests/ mirrors src/ exactly
- [ ] Files named `*_tests.rs`
- [ ] `test_suite.rs` exists
- [ ] `error_tests.rs` exists
- [ ] Tests have file-level docs
- [ ] Descriptive test names
- [ ] Tests isolated

### CI/CD Integration
```yaml
- run: cargo test --all-features
- run: ! grep -r "#\[cfg(test)\]" crates/*/src/
```

---
## Summary
1. Mirror src/ → tests/
2. No #[cfg(test)] in production
3. test_suite.rs entry point
4. [source]_tests.rs naming
5. Document all tests
6. error_tests.rs mandatory

## Integration with CI/CD

Tests are automatically run in CI pipeline:

```yaml
- name: Run tests
  run: cargo test --all-features

- name: Check test organization
  run: |
    # Verify no #[cfg(test)] in src/
    ! grep -r "#\[cfg(test)\]" crates/*/src/

    # Verify test_suite.rs exists
    find crates/*/tests -name "test_suite.rs" | wc -l
```

## Summary

**Golden Rules:**
1. 📂 Mirror src/ structure in tests/
2. 🚫 Never use `#[cfg(test)]` in production files
3. 📝 Always create `test_suite.rs` as entry point
4. ✅ Name tests: `[source]_tests.rs`
5. 📚 Document all test files
6. 🎯 Test files MUST mirror module hierarchy exactly