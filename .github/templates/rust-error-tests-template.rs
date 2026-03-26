/// Tests for [ModuleName]Error enum and error handling
///
/// Validates error type conversions, Display implementations,
/// Debug formatting, and error propagation patterns.
///
/// USAGE:
/// 1. Replace [ModuleName] with your module name (e.g., Command, Manifest, Template)
/// 2. Replace [crate_name] with your crate name (e.g., nettoolskit_commands)
/// 3. Add/remove error variants as needed
/// 4. Update error messages to match your implementation
/// 5. Add specific conversion tests for your error sources

use [crate_name]::{[ModuleName]Error, [ModuleName]Result};
use std::io;

// ============================================================================
// Display Tests - Validate error messages shown to users
// ============================================================================

#[test]
fn test_error_display_variant_one() {
    let error = [ModuleName]Error::VariantOne("test detail".to_string());
    let msg = error.to_string();

    assert!(msg.contains("expected message"));
    assert!(msg.contains("test detail"));
}

#[test]
fn test_error_display_variant_two() {
    let error = [ModuleName]Error::VariantTwo {
        field: "value".to_string(),
    };

    assert_eq!(error.to_string(), "expected message: value");
}

#[test]
fn test_error_display_variant_three() {
    let error = [ModuleName]Error::VariantThree;

    assert_eq!(error.to_string(), "expected message");
}

// ============================================================================
// Debug Tests - Validate debug formatting
// ============================================================================

#[test]
fn test_error_debug_format() {
    let error = [ModuleName]Error::VariantOne("test".to_string());
    let debug_str = format!("{:?}", error);

    assert!(debug_str.contains("VariantOne"));
    assert!(debug_str.contains("test"));
}

#[test]
fn test_error_debug_all_variants() {
    let errors = vec![
        [ModuleName]Error::VariantOne("a".into()),
        [ModuleName]Error::VariantTwo { field: "b".into() },
        [ModuleName]Error::VariantThree,
    ];

    for error in errors {
        let debug = format!("{:?}", error);
        assert!(!debug.is_empty());
    }
}

// ============================================================================
// Conversion Tests - Validate From<T> implementations
// ============================================================================

#[test]
fn test_error_from_string() {
    let error: [ModuleName]Error = "test error".to_string().into();

    assert!(matches!(error, [ModuleName]Error::VariantOne(_)));
    assert_eq!(error.to_string(), "expected: test error");
}

#[test]
fn test_error_from_str() {
    let error: [ModuleName]Error = "test error".into();

    assert!(matches!(error, [ModuleName]Error::VariantOne(_)));
}

#[test]
fn test_error_from_io_error() {
    let io_error = io::Error::new(io::ErrorKind::NotFound, "file not found");
    let error = [ModuleName]Error::from(io_error);

    assert!(matches!(error, [ModuleName]Error::IoError(_)));
    assert!(error.to_string().contains("file not found"));
}

#[test]
fn test_error_from_custom_error() {
    // Add conversions for domain-specific error types
    // Example:
    // let parse_error = ParseError::new("invalid");
    // let error = [ModuleName]Error::from(parse_error);
    // assert!(matches!(error, [ModuleName]Error::ParseError(_)));
}

// ============================================================================
// Propagation Tests - Validate error propagation with ?
// ============================================================================

#[test]
fn test_error_propagation() {
    fn failing_function() -> [ModuleName]Result<()> {
        Err([ModuleName]Error::VariantOne("test".to_string()))
    }

    fn calling_function() -> [ModuleName]Result<()> {
        failing_function()?;
        Ok(())
    }

    let result = calling_function();
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        [ModuleName]Error::VariantOne(_)
    ));
}

#[test]
fn test_error_propagation_chain() {
    fn level_3() -> [ModuleName]Result<String> {
        Err([ModuleName]Error::VariantThree)
    }

    fn level_2() -> [ModuleName]Result<String> {
        level_3()
    }

    fn level_1() -> [ModuleName]Result<String> {
        level_2()
    }

    let result = level_1();
    assert!(result.is_err());
}

// ============================================================================
// Result Type Alias Tests
// ============================================================================

#[test]
fn test_result_type_alias_ok() {
    fn returns_result() -> [ModuleName]Result<String> {
        Ok("success".to_string())
    }

    let result = returns_result();
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "success");
}

#[test]
fn test_result_type_alias_err() {
    fn returns_error() -> [ModuleName]Result<String> {
        Err([ModuleName]Error::VariantOne("fail".into()))
    }

    let result = returns_error();
    assert!(result.is_err());
}

// ============================================================================
// Error Source Tests (if using std::error::Error trait)
// ============================================================================

#[test]
fn test_error_source() {
    let io_error = io::Error::new(io::ErrorKind::NotFound, "not found");
    let error = [ModuleName]Error::from(io_error);

    // If your error implements std::error::Error with source()
    // use std::error::Error as StdError;
    // assert!(error.source().is_some());
}

// ============================================================================
// Error Context Tests (if using error context/wrapping)
// ============================================================================

#[test]
fn test_error_with_context() {
    // If you have context wrapping like anyhow or similar
    // let error = [ModuleName]Error::VariantOne("base error".into())
    //     .context("additional context");
    // assert!(error.to_string().contains("additional context"));
}

// ============================================================================
// Custom Tests - Add domain-specific error scenarios
// ============================================================================

// Add tests specific to your error types here
// Examples:
// - Validation errors with field details
// - Network errors with retry info
// - Parse errors with line/column numbers
// - Business logic errors with codes