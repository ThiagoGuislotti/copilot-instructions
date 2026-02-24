---
description: Generate Rust module with proper tests/ directory structure and mandatory error_tests.rs
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Create Rust Module
Generate a Rust module following repository structure and testing requirements.

## Instructions
Create Rust module based on:
- [rust-code-organization.instructions.md](../.github/instructions/rust-code-organization.instructions.md)
- [rust-testing.instructions.md](../.github/instructions/rust-testing.instructions.md)

## Input Variables
- `${input:moduleName:Module name (e.g., parser, validator)}` - The module name
- `${input:moduleType:Module type (lib/bin/util)}` - Module category
- `${input:hasErrors:Defines error types? (yes/no)}` - Whether module defines custom errors
- `${input:isPublic:Public API? (yes/no)}` - Whether module is part of public API

## Directory Structure
```
src/
  ${moduleName}/
    mod.rs          # Module entry point and public API
    core.rs         # Core implementation
    types.rs        # Type definitions
    error.rs        # Error types (if hasErrors=yes)
    utils.rs        # Helper functions (optional)

tests/
  ${moduleName}/
    mod.rs          # Test module entry point
    test_suite.rs   # Main test suite with all test categories
    error_tests.rs  # Mandatory error tests
    unit_tests.rs   # Unit tests for core functionality
    integration_tests.rs  # Integration tests (if applicable)
```

## Source Module Structure

### 1. mod.rs - Module Entry Point
**Location:** `src/${moduleName}/mod.rs`

```rust
//! ${ModuleDescription}
//!
//! # Overview
//! ${detailedOverview}
//!
//! # Examples
//! ```
//! use crate::${moduleName}::${MainType};
//!
//! let instance = ${MainType}::new();
//! ```

${isPublic ? 'pub ' : ''}mod core;
${isPublic ? 'pub ' : ''}mod types;
${hasErrors === 'yes' ? (isPublic ? 'pub ' : '') + 'mod error;' : ''}
mod utils;

// Re-export public API
pub use core::{${mainFunctions}};
pub use types::{${mainTypes}};
${hasErrors === 'yes' ? 'pub use error::{' + errorTypes + '};' : ''}
```

### 2. types.rs - Type Definitions
**Location:** `src/${moduleName}/types.rs`

```rust
//! Type definitions for ${moduleName} module

use std::fmt;

/// ${TypeDescription}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ${MainType} {
    /// ${fieldDescription}
    pub field_name: String,
    // Additional fields
}

impl ${MainType} {
    /// Create a new ${MainType}
    ///
    /// # Arguments
    /// * `field_name` - ${fieldDescription}
    ///
    /// # Examples
    /// ```
    /// let instance = ${MainType}::new("value".to_string());
    /// ```
    pub fn new(field_name: String) -> Self {
        Self { field_name }
    }
}

impl fmt::Display for ${MainType} {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "${MainType}({})", self.field_name)
    }
}
```

### 3. error.rs - Error Types (if hasErrors=yes)
**Location:** `src/${moduleName}/error.rs`

```rust
//! Error types for ${moduleName} module

use std::fmt;
use std::error::Error;

/// Errors that can occur in ${moduleName}
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ${ModuleName}Error {
    /// Invalid input provided
    InvalidInput(String),
    /// Operation failed
    OperationFailed(String),
    /// Resource not found
    NotFound(String),
}

impl fmt::Display for ${ModuleName}Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidInput(msg) => write!(f, "Invalid input: {}", msg),
            Self::OperationFailed(msg) => write!(f, "Operation failed: {}", msg),
            Self::NotFound(msg) => write!(f, "Not found: {}", msg),
        }
    }
}

impl Error for ${ModuleName}Error {}

/// Result type for ${moduleName} operations
pub type ${ModuleName}Result<T> = Result<T, ${ModuleName}Error>;
```

### 4. core.rs - Core Implementation
**Location:** `src/${moduleName}/core.rs`

```rust
//! Core implementation for ${moduleName}

use super::types::${MainType};
${hasErrors === 'yes' ? 'use super::error::{' + ModuleName + 'Error, ' + ModuleName + 'Result};' : ''}

/// ${FunctionDescription}
///
/// # Arguments
/// * `input` - ${inputDescription}
///
/// # Returns
/// ${returnDescription}
///
/// # Errors
/// Returns error if ${errorCondition}
///
/// # Examples
/// ```
/// let result = ${functionName}("value");
/// assert!(result.is_ok());
/// ```
pub fn ${functionName}(input: &str) -> ${hasErrors === 'yes' ? ModuleName + 'Result<' + ReturnType + '>' : ReturnType} {
    // Validation
    if input.is_empty() {
        ${hasErrors === 'yes' ? 'return Err(' + ModuleName + 'Error::InvalidInput("input cannot be empty".to_string()));' : 'panic!("input cannot be empty");'}
    }

    // Implementation
    ${hasErrors === 'yes' ? 'Ok(' + implementationLogic + ')' : implementationLogic}
}
```

## Test Structure (Mandatory)

### 1. tests/mod.rs - Test Module Entry
**Location:** `tests/${moduleName}/mod.rs`

```rust
//! Test module for ${moduleName}
//!
//! Structure:
//! - test_suite.rs: Main test entry point with all categories
//! - error_tests.rs: Error handling tests (MANDATORY)
//! - unit_tests.rs: Unit tests for core functionality
//! - integration_tests.rs: Integration tests

mod test_suite;
mod error_tests;
mod unit_tests;
${hasIntegration ? 'mod integration_tests;' : ''}
```

### 2. tests/test_suite.rs - Test Categories
**Location:** `tests/${moduleName}/test_suite.rs`

```rust
//! Main test suite for ${moduleName}
//!
//! Test Categories:
//! 1. Unit Tests - Core functionality
//! 2. Error Tests - Error handling (MANDATORY)
//! 3. Integration Tests - Full workflow
//! 4. Edge Cases - Boundary conditions

#[cfg(test)]
mod test_categories {
    use super::*;

    /// Run all unit tests
    #[test]
    fn run_unit_tests() {
        crate::${moduleName}::unit_tests::run_all_unit_tests();
    }

    /// Run all error tests (MANDATORY)
    #[test]
    fn run_error_tests() {
        crate::${moduleName}::error_tests::run_all_error_tests();
    }

    ${hasIntegration ? '#[test]\nfn run_integration_tests() {\n    crate::' + moduleName + '::integration_tests::run_all_integration_tests();\n}' : ''}
}
```

### 3. tests/error_tests.rs - Error Tests (MANDATORY)
**Location:** `tests/${moduleName}/error_tests.rs`

```rust
//! Error handling tests for ${moduleName}
//!
//! MANDATORY: All modules with error types MUST have comprehensive error tests

use ${cratePrefix}::${moduleName}::error::${ModuleName}Error;
use ${cratePrefix}::${moduleName}::core::${functionName};

/// Run all error tests
pub fn run_all_error_tests() {
    test_invalid_input_error();
    test_operation_failed_error();
    test_not_found_error();
    test_error_display();
}

#[test]
fn test_invalid_input_error() {
    let result = ${functionName}("");
    assert!(result.is_err());
    
    if let Err(${ModuleName}Error::InvalidInput(msg)) = result {
        assert!(msg.contains("cannot be empty"));
    } else {
        panic!("Expected InvalidInput error");
    }
}

#[test]
fn test_operation_failed_error() {
    // Test operation failure scenarios
    let result = ${functionName}("invalid_value");
    assert!(result.is_err());
}

#[test]
fn test_not_found_error() {
    // Test not found scenarios
    let result = ${functionName}("nonexistent");
    assert!(result.is_err());
}

#[test]
fn test_error_display() {
    let error = ${ModuleName}Error::InvalidInput("test".to_string());
    let display_str = format!("{}", error);
    assert!(display_str.contains("Invalid input"));
    assert!(display_str.contains("test"));
}

#[test]
fn test_error_debug() {
    let error = ${ModuleName}Error::InvalidInput("test".to_string());
    let debug_str = format!("{:?}", error);
    assert!(debug_str.contains("InvalidInput"));
}
```

### 4. tests/unit_tests.rs - Unit Tests
**Location:** `tests/${moduleName}/unit_tests.rs`

```rust
//! Unit tests for ${moduleName} core functionality

use ${cratePrefix}::${moduleName}::types::${MainType};
use ${cratePrefix}::${moduleName}::core::${functionName};

/// Run all unit tests
pub fn run_all_unit_tests() {
    test_${functionName}_valid_input();
    test_${functionName}_edge_cases();
    test_${MainType}_creation();
    test_${MainType}_methods();
}

#[test]
fn test_${functionName}_valid_input() {
    let result = ${functionName}("valid_input");
    assert!(result.is_ok());
}

#[test]
fn test_${functionName}_edge_cases() {
    // Test boundary conditions
    let result = ${functionName}("x");
    assert!(result.is_ok());
}

#[test]
fn test_${MainType}_creation() {
    let instance = ${MainType}::new("test".to_string());
    assert_eq!(instance.field_name, "test");
}

#[test]
fn test_${MainType}_methods() {
    let instance = ${MainType}::new("test".to_string());
    let display_str = format!("{}", instance);
    assert!(display_str.contains("test"));
}
```

## Coverage Requirements
From rust-testing.instructions.md:
- All modules with error types MUST have error_tests.rs
- Test coverage minimum 80%
- Error paths MUST be tested
- All public functions MUST have tests
- Edge cases and boundary conditions MUST be tested

## Quality Checklist
- [ ] Module structure mirrors src/ in tests/
- [ ] error_tests.rs created (if hasErrors=yes)
- [ ] test_suite.rs entry point with categories
- [ ] All public functions have doc comments with examples
- [ ] Error types implement Display and Error traits
- [ ] Unit tests cover happy path and edge cases
- [ ] Error tests cover all error variants
- [ ] Integration tests cover full workflows (if applicable)
- [ ] Code coverage >= 80%

Generate complete Rust module following repository structure and testing requirements.