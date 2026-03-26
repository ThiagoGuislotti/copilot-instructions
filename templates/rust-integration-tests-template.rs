/// Integration tests for [ModuleName]
///
/// Tests end-to-end workflows, component interaction,
/// and system behavior with real dependencies.
///
/// USAGE:
/// 1. Replace [ModuleName] with your module name
/// 2. Replace [crate_name] with your crate name
/// 3. Add actual integration scenarios for your domain
/// 4. Use real dependencies (filesystem, network, etc.)
/// 5. Ensure proper cleanup with TempDir and Drop guards

use [crate_name]::{[ModuleName], [ModuleName]Error, [ModuleName]Result};
use std::path::{Path, PathBuf};
use tempfile::TempDir;

// ============================================================================
// Setup & Teardown Helpers
// ============================================================================

/// Creates a temporary test environment
fn setup_test_environment() -> TempDir {
    let temp_dir = TempDir::new().unwrap();

    // Create test directory structure
    std::fs::create_dir_all(temp_dir.path().join("data")).unwrap();
    std::fs::create_dir_all(temp_dir.path().join("output")).unwrap();

    // Create test files
    std::fs::write(
        temp_dir.path().join("config.toml"),
        "key = \"value\"\n"
    ).unwrap();

    temp_dir
}

/// Creates test input data
fn create_test_input() -> TestInput {
    TestInput {
        field: "test value".to_string(),
        count: 42,
        enabled: true,
    }
}

/// Verifies expected output
fn verify_output(dir: &Path, expected: &str) {
    let output_file = dir.join("output").join("result.txt");
    assert!(output_file.exists(), "Output file should exist");

    let content = std::fs::read_to_string(output_file).unwrap();
    assert!(content.contains(expected), "Output should contain: {}", expected);
}

// ============================================================================
// Happy Path Integration Tests
// ============================================================================

#[tokio::test]
async fn test_end_to_end_workflow_success() {
    // Arrange
    let temp_dir = setup_test_environment();
    let input = create_test_input();

    // Act
    let result = execute_full_workflow(temp_dir.path(), input).await;

    // Assert
    assert!(result.is_ok(), "Workflow should succeed");
    verify_output(temp_dir.path(), "expected output");
}

#[tokio::test]
async fn test_multi_step_workflow() {
    let temp_dir = setup_test_environment();

    // Step 1: Initialize
    let init_result = initialize_system(temp_dir.path()).await;
    assert!(init_result.is_ok(), "Initialization should succeed");

    // Step 2: Process data
    let input_file = temp_dir.path().join("data").join("input.json");
    std::fs::write(&input_file, r#"{"key": "value"}"#).unwrap();

    let process_result = process_data(&input_file).await;
    assert!(process_result.is_ok(), "Processing should succeed");

    // Step 3: Generate output
    let output_result = generate_output(temp_dir.path()).await;
    assert!(output_result.is_ok(), "Output generation should succeed");

    // Step 4: Verify complete state
    assert!(temp_dir.path().join("output").exists());
    let output_files: Vec<_> = std::fs::read_dir(temp_dir.path().join("output"))
        .unwrap()
        .collect();
    assert!(output_files.len() > 0, "Should have output files");
}

#[tokio::test]
async fn test_workflow_with_real_files() {
    let temp_dir = setup_test_environment();

    // Create real input file
    let input_path = temp_dir.path().join("input.txt");
    std::fs::write(&input_path, "test content\nline 2\n").unwrap();

    // Process with real filesystem
    let result = process_file(&input_path).await;

    assert!(result.is_ok());

    // Verify output file was created
    let output_path = temp_dir.path().join("output").join("processed.txt");
    assert!(output_path.exists());

    let output = std::fs::read_to_string(output_path).unwrap();
    assert!(output.contains("test content"));
}

// ============================================================================
// Error Scenario Integration Tests
// ============================================================================

#[tokio::test]
async fn test_workflow_with_invalid_input() {
    let temp_dir = setup_test_environment();

    let invalid_input = TestInput {
        field: String::new(), // Invalid empty field
        count: -1,            // Invalid negative
        enabled: false,
    };

    let result = execute_full_workflow(temp_dir.path(), invalid_input).await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(error.to_string().contains("invalid"));
}

#[tokio::test]
async fn test_workflow_with_missing_dependency() {
    let temp_dir = setup_test_environment();

    // Don't create required config file
    std::fs::remove_file(temp_dir.path().join("config.toml")).unwrap();

    let result = execute_workflow_requiring_config(temp_dir.path()).await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(error.to_string().contains("config") || error.to_string().contains("not found"));
}

#[tokio::test]
async fn test_workflow_with_permission_error() {
    let temp_dir = setup_test_environment();
    let readonly_file = temp_dir.path().join("readonly.txt");

    std::fs::write(&readonly_file, "content").unwrap();

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = std::fs::metadata(&readonly_file).unwrap().permissions();
        perms.set_mode(0o444); // Read-only
        std::fs::set_permissions(&readonly_file, perms).unwrap();
    }

    let result = write_to_file(&readonly_file, "new content").await;

    #[cfg(unix)]
    assert!(result.is_err());
}

#[tokio::test]
async fn test_workflow_partial_failure_recovery() {
    let temp_dir = setup_test_environment();

    // Step 1 succeeds
    let step1 = step1_operation(temp_dir.path()).await;
    assert!(step1.is_ok());

    // Step 2 fails
    let step2 = step2_operation_that_fails(temp_dir.path()).await;
    assert!(step2.is_err());

    // Verify step 1 results still exist (no rollback)
    // OR verify rollback happened if that's the design
    assert!(temp_dir.path().join("step1_marker").exists());
}

// ============================================================================
// Idempotency Tests
// ============================================================================

#[tokio::test]
async fn test_workflow_idempotency() {
    let temp_dir = setup_test_environment();
    let input = create_test_input();

    // Execute first time
    let result1 = execute_full_workflow(temp_dir.path(), input.clone()).await;
    assert!(result1.is_ok());
    let output1 = result1.unwrap();

    // Execute second time with same input
    let result2 = execute_full_workflow(temp_dir.path(), input).await;
    assert!(result2.is_ok());
    let output2 = result2.unwrap();

    // Results should be identical
    assert_eq!(output1, output2);
}

#[tokio::test]
async fn test_operation_can_run_multiple_times() {
    let temp_dir = setup_test_environment();

    for i in 0..3 {
        let result = create_resource(temp_dir.path(), &format!("resource-{}", i)).await;
        assert!(result.is_ok(), "Iteration {} should succeed", i);
    }

    // Verify all resources created
    let resources: Vec<_> = std::fs::read_dir(temp_dir.path())
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().starts_with("resource-"))
        .collect();

    assert_eq!(resources.len(), 3);
}

// ============================================================================
// Component Interaction Tests
// ============================================================================

#[tokio::test]
async fn test_component_a_with_component_b() {
    let component_a = ComponentA::new("test");
    let component_b = ComponentB::new();

    let result = component_a.interact_with(&component_b).await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "expected result");
}

#[tokio::test]
async fn test_pipeline_of_components() {
    let input = "initial data";

    // Component chain: A -> B -> C
    let result_a = ComponentA::process(input).await.unwrap();
    let result_b = ComponentB::process(&result_a).await.unwrap();
    let result_c = ComponentC::process(&result_b).await.unwrap();

    assert_eq!(result_c, "final processed data");
}

#[tokio::test]
async fn test_components_share_state() {
    use std::sync::Arc;
    use tokio::sync::RwLock;

    let shared_state = Arc::new(RwLock::new(Vec::new()));

    let component_a = ComponentA::with_state(shared_state.clone());
    let component_b = ComponentB::with_state(shared_state.clone());

    component_a.add_item("item1").await.unwrap();
    component_b.add_item("item2").await.unwrap();

    let state = shared_state.read().await;
    assert_eq!(state.len(), 2);
    assert!(state.contains(&"item1".to_string()));
    assert!(state.contains(&"item2".to_string()));
}

// ============================================================================
// Real Dependency Tests
// ============================================================================

#[tokio::test]
async fn test_with_real_file_system() {
    let temp_dir = setup_test_environment();
    let file_path = temp_dir.path().join("test.txt");

    // Write through system
    write_file(&file_path, "test content").await.unwrap();

    // Read through system
    let content = read_file(&file_path).await.unwrap();

    assert_eq!(content, "test content");
}

#[tokio::test]
async fn test_with_real_directory_operations() {
    let temp_dir = setup_test_environment();

    // Create nested directories
    let nested = temp_dir.path().join("a").join("b").join("c");
    create_directories(&nested).await.unwrap();

    assert!(nested.exists());
    assert!(nested.is_dir());
}

#[tokio::test]
async fn test_with_file_watching() {
    // If your system watches files
    let temp_dir = setup_test_environment();
    let watch_file = temp_dir.path().join("watched.txt");

    let (tx, mut rx) = tokio::sync::mpsc::channel(10);

    // Start watcher
    let watcher_handle = tokio::spawn({
        let watch_file = watch_file.clone();
        async move {
            watch_file_changes(&watch_file, tx).await
        }
    });

    // Modify file
    std::fs::write(&watch_file, "change 1").unwrap();

    // Should receive notification
    let notification = tokio::time::timeout(
        Duration::from_secs(1),
        rx.recv()
    ).await;

    assert!(notification.is_ok());

    watcher_handle.abort();
}

// ============================================================================
// Performance/Load Tests
// ============================================================================

#[tokio::test]
async fn test_handles_large_file() {
    let temp_dir = setup_test_environment();
    let large_file = temp_dir.path().join("large.txt");

    // Create 10MB file
    let content = "x".repeat(10 * 1024 * 1024);
    std::fs::write(&large_file, content).unwrap();

    let start = std::time::Instant::now();
    let result = process_file(&large_file).await;
    let elapsed = start.elapsed();

    assert!(result.is_ok());
    assert!(elapsed < Duration::from_secs(5), "Should process in reasonable time");
}

#[tokio::test]
async fn test_handles_many_files() {
    let temp_dir = setup_test_environment();

    // Create 100 files
    for i in 0..100 {
        let file = temp_dir.path().join(format!("file-{}.txt", i));
        std::fs::write(file, format!("content {}", i)).unwrap();
    }

    let result = process_directory(temp_dir.path()).await;

    assert!(result.is_ok());
    let processed = result.unwrap();
    assert_eq!(processed.len(), 100);
}

// ============================================================================
// Concurrent Integration Tests
// ============================================================================

#[tokio::test]
async fn test_concurrent_workflows() {
    let temp_dir = setup_test_environment();

    let handles: Vec<_> = (0..5)
        .map(|i| {
            let path = temp_dir.path().to_path_buf();
            let input = TestInput {
                field: format!("test-{}", i),
                count: i,
                enabled: true,
            };

            tokio::spawn(async move {
                execute_full_workflow(&path, input).await
            })
        })
        .collect();

    let results: Vec<_> = futures::future::join_all(handles)
        .await
        .into_iter()
        .map(|r| r.unwrap())
        .collect();

    assert!(results.iter().all(|r| r.is_ok()));
}

// ============================================================================
// Helper Types and Functions
// ============================================================================

#[derive(Clone)]
struct TestInput {
    field: String,
    count: i32,
    enabled: bool,
}

async fn execute_full_workflow(dir: &Path, input: TestInput) -> [ModuleName]Result<String> {
    // Implement your workflow
    Ok("success".to_string())
}

async fn initialize_system(dir: &Path) -> [ModuleName]Result<()> {
    // Implement initialization
    Ok(())
}

async fn process_data(path: &Path) -> [ModuleName]Result<()> {
    // Implement data processing
    Ok(())
}

async fn generate_output(dir: &Path) -> [ModuleName]Result<()> {
    // Implement output generation
    Ok(())
}

async fn process_file(path: &Path) -> [ModuleName]Result<String> {
    // Implement file processing
    Ok("processed".to_string())
}