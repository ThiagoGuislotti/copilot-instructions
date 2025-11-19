//! [Crate Name] Test Suite Entry Point
//!
//! Main test suite aggregator for [crate-name] crate.
//! All module tests are organized to mirror the src/ directory structure.
//!
//! ## Structure
//! - error_tests: Error type tests (Display, Debug, From conversions)
//! - [module]_tests: Unit tests for each public module
//! - integration_tests: End-to-end workflow tests
//!
//! ## Usage
//! Run all tests: `cargo test --package [crate-name]`
//! Run specific module: `cargo test --package [crate-name] [module]_tests`

// Core module tests
mod error_tests;

// Feature module tests (add one per src/ module)
// mod [module]_tests;

// Integration tests
// mod integration_tests;

// For subdirectories in tests/, use #[path] attribute:
// #[path = "subdir/mod.rs"]
// mod subdir;