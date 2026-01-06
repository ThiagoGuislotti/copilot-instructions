---
applyTo: "**/*.rs"
priority: high
---

# Rust Code Organization

## Core Principles
Mirror src/ structure in tests/ exactly; production code in src/, tests in tests/; no #[cfg(test)] blocks in production; follow Rust module conventions; **1 trait = 1 file, 1 struct = 1 file** for better maintainability and scalability.

> **Rule:** Test file structure MUST mirror source file structure.
> **Rule:** Each trait and struct should have its own file (unless trivially small < 20 lines).

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
```## Module Organization Patterns

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
## Code Organization: Traits and Structs

### Rule: 1 Trait = 1 File, 1 Struct = 1 File

**Rationale:** Inspired by .NET/C# conventions (1 class = 1 file), Rust code should follow:
- **1 trait = 1 file** (unless trivially small < 20 lines)
- **1 struct = 1 file** (unless trivially small < 20 lines)
- Group related items in a module with `mod.rs` for re-exports

**Benefits:**
- Easy to locate code
- Clear separation of concerns
- Scalable as code grows
- Better git history tracking
- Easier code review

### Pattern: Trait Organization

**Before (traits in lib.rs - ❌ NOT RECOMMENDED):**
```
src/
└── lib.rs  # Contains MenuEntry + CommandEntry + MenuProvider
```

**After (separated - ✅ RECOMMENDED):**
```
src/
├── lib.rs  # Re-exports only
└── menu/
    ├── mod.rs              # Module aggregator
    ├── menu_entry.rs       # MenuEntry trait
    ├── command_entry.rs    # CommandEntry trait
    └── menu_provider.rs    # MenuProvider trait
```

**mod.rs:**
```rust
//! Menu system traits and utilities

mod command_entry;
mod menu_entry;
mod menu_provider;

pub use command_entry::CommandEntry;
pub use menu_entry::MenuEntry;
pub use menu_provider::MenuProvider;
```

**lib.rs:**
```rust
pub mod menu;

// Re-export commonly used items
pub use menu::{CommandEntry, MenuEntry, MenuProvider};
```

### Pattern: Struct Organization

**Simple struct (< 20 lines) - OK to keep in module:**
```rust
// src/config.rs
pub struct Config {
    pub name: String,
    pub value: i32,
}
```

**Complex struct with many methods - Separate file:**
```
src/models/
├── mod.rs
├── user.rs          # User struct
├── session.rs       # Session struct
└── permission.rs    # Permission struct
```

### When to Keep Together vs Separate

**Keep Together (in same file):**
- ✅ Tightly coupled types (< 100 total lines)
- ✅ Enum + impl block (single responsibility)
- ✅ Struct + builder pattern in same file
- ✅ Type aliases and small utility traits

**Separate Files:**
- ❌ Multiple unrelated traits (even if small)
- ❌ Large trait with many methods (> 50 lines)
- ❌ Struct with extensive impl blocks (> 100 lines)
- ❌ Types likely to grow over time

### Example: Before and After

**Before (menu.rs - 150 lines):**
```rust
pub trait MenuEntry { /* ... */ }
pub trait CommandEntry { /* ... */ }
pub trait MenuProvider { /* ... */ }

pub struct MenuConfig { /* ... */ }
impl MenuConfig { /* ... */ }

pub fn render_menu() { /* ... */ }
```

**After (organized):**
```
menu/
├── mod.rs
├── menu_entry.rs      # MenuEntry trait
├── command_entry.rs   # CommandEntry trait
├── menu_provider.rs   # MenuProvider trait
├── config.rs          # MenuConfig struct + impl
└── renderer.rs        # render_menu function
```

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
