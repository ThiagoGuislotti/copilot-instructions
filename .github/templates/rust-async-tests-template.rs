/// Tests for async [ModuleName] operations
///
/// Validates async execution, cancellation, timeout handling,
/// concurrent operations, and progress reporting.
///
/// USAGE:
/// 1. Replace [ModuleName] with your module name
/// 2. Replace [crate_name] with your crate name
/// 3. Replace [async_function] with your actual async functions
/// 4. Add/remove test sections as needed
/// 5. Adjust timeouts and delays for your use case

use [crate_name]::{[ModuleName], [ModuleName]Error, [ModuleName]Result};
use tokio::time::{sleep, timeout, Duration};
use std::time::Instant;

// ============================================================================
// Happy Path Tests - Successful async operations
// ============================================================================

#[tokio::test]
async fn test_async_operation_success() {
    let result = [async_function]("valid input").await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "expected output");
}

#[tokio::test]
async fn test_async_operation_with_delay() {
    let start = Instant::now();
    let expected_delay = Duration::from_millis(50);

    let result = [async_function_with_delay](expected_delay).await;
    let elapsed = start.elapsed();

    assert!(result.is_ok());
    assert!(elapsed >= expected_delay);
    assert!(elapsed < expected_delay + Duration::from_millis(100)); // Allow 100ms variance
}

#[tokio::test]
async fn test_async_operation_returns_correct_value() {
    let input = "test data";
    let result = [async_function](input).await;

    assert!(result.is_ok());
    let output = result.unwrap();
    assert!(output.contains(input));
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[tokio::test]
async fn test_async_operation_invalid_input() {
    let result = [async_function]("").await;

    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(error.to_string().contains("invalid"));
}

#[tokio::test]
async fn test_async_operation_propagates_error() {
    async fn failing_operation() -> [ModuleName]Result<String> {
        Err([ModuleName]Error::OperationFailed("test".into()))
    }

    async fn calling_operation() -> [ModuleName]Result<String> {
        failing_operation().await
    }

    let result = calling_operation().await;
    assert!(result.is_err());
}

// ============================================================================
// Timeout Tests
// ============================================================================

#[tokio::test]
async fn test_async_operation_timeout() {
    let result = timeout(
        Duration::from_millis(10),
        async {
            sleep(Duration::from_secs(10)).await;
            "never completes"
        }
    ).await;

    assert!(result.is_err()); // tokio::time::error::Elapsed
}

#[tokio::test]
async fn test_async_operation_completes_before_timeout() {
    let result = timeout(
        Duration::from_secs(1),
        async {
            sleep(Duration::from_millis(10)).await;
            "completed"
        }
    ).await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "completed");
}

#[tokio::test]
async fn test_async_operation_with_custom_timeout() {
    // If your API has built-in timeout support
    let result = [async_function_with_timeout](
        "input",
        Duration::from_millis(100)
    ).await;

    assert!(result.is_ok());
}

// ============================================================================
// Cancellation Tests (if using CancellationToken)
// ============================================================================

#[tokio::test]
async fn test_async_operation_cancellation() {
    use [crate_name]::CancellationToken; // Adjust import

    let token = CancellationToken::new();

    // Start long-running operation
    let handle = tokio::spawn({
        let token = token.clone();
        async move {
            token.with_cancellation(async {
                sleep(Duration::from_secs(10)).await;
                "completed"
            }).await
        }
    });

    // Cancel immediately
    sleep(Duration::from_millis(10)).await;
    token.cancel();

    let result = handle.await.unwrap();
    assert!(result.is_err()); // Should be cancelled
}

#[tokio::test]
async fn test_async_operation_not_cancelled() {
    use [crate_name]::CancellationToken;

    let token = CancellationToken::new();

    let result = token.with_cancellation(async {
        sleep(Duration::from_millis(10)).await;
        "completed"
    }).await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "completed");
}

#[tokio::test]
async fn test_async_operation_cancel_before_start() {
    use [crate_name]::CancellationToken;

    let token = CancellationToken::new();
    token.cancel(); // Cancel before operation starts

    let result = token.with_cancellation(async {
        "should not run"
    }).await;

    assert!(result.is_err());
}

// ============================================================================
// Concurrent Execution Tests
// ============================================================================

#[tokio::test]
async fn test_multiple_concurrent_operations() {
    let handles: Vec<_> = (0..5)
        .map(|i| {
            tokio::spawn(async move {
                [async_function](&format!("input-{}", i)).await
            })
        })
        .collect();

    let results: Vec<_> = futures::future::join_all(handles)
        .await
        .into_iter()
        .map(|r| r.unwrap())
        .collect();

    assert_eq!(results.len(), 5);
    assert!(results.iter().all(|r| r.is_ok()));
}

#[tokio::test]
async fn test_concurrent_operations_with_shared_state() {
    use std::sync::Arc;
    use tokio::sync::Mutex;

    let counter = Arc::new(Mutex::new(0));

    let handles: Vec<_> = (0..10)
        .map(|_| {
            let counter = counter.clone();
            tokio::spawn(async move {
                let mut count = counter.lock().await;
                *count += 1;
                [async_function]("test").await
            })
        })
        .collect();

    futures::future::join_all(handles).await;

    let final_count = *counter.lock().await;
    assert_eq!(final_count, 10);
}

#[tokio::test]
async fn test_parallel_operations_complete_faster() {
    let operation_duration = Duration::from_millis(100);

    // Sequential
    let start = Instant::now();
    for _ in 0..3 {
        sleep(operation_duration).await;
    }
    let sequential_time = start.elapsed();

    // Parallel
    let start = Instant::now();
    let handles: Vec<_> = (0..3)
        .map(|_| tokio::spawn(async move {
            sleep(operation_duration).await;
        }))
        .collect();
    futures::future::join_all(handles).await;
    let parallel_time = start.elapsed();

    // Parallel should be significantly faster
    assert!(parallel_time < sequential_time / 2);
}

// ============================================================================
// Progress Reporting Tests (if applicable)
// ============================================================================

#[tokio::test]
async fn test_async_operation_with_progress() {
    use tokio::sync::mpsc;

    let (tx, mut rx) = mpsc::channel(10);

    let handle = tokio::spawn(async move {
        [async_function_with_progress](tx).await
    });

    let mut progress_updates = Vec::new();
    while let Some(progress) = rx.recv().await {
        progress_updates.push(progress);
    }

    let result = handle.await.unwrap();
    assert!(result.is_ok());
    assert!(progress_updates.len() > 0);
    assert_eq!(*progress_updates.last().unwrap(), 100); // 100% complete
}

#[tokio::test]
async fn test_async_operation_progress_increments() {
    use tokio::sync::mpsc;

    let (tx, mut rx) = mpsc::channel(100);

    tokio::spawn(async move {
        for i in 0..=100 {
            tx.send(i).await.ok();
            sleep(Duration::from_millis(1)).await;
        }
    });

    let mut last_progress = 0;
    while let Some(progress) = rx.recv().await {
        assert!(progress >= last_progress);
        last_progress = progress;
    }

    assert_eq!(last_progress, 100);
}

// ============================================================================
// Resource Management Tests
// ============================================================================

#[tokio::test]
async fn test_async_operation_cleans_up_on_success() {
    let result = [async_function_with_resource]("test").await;

    assert!(result.is_ok());
    // Verify resource was cleaned up
    // assert!(!resource_exists());
}

#[tokio::test]
async fn test_async_operation_cleans_up_on_error() {
    let result = [async_function_with_resource]("").await;

    assert!(result.is_err());
    // Verify resource was cleaned up even on error
    // assert!(!resource_exists());
}

#[tokio::test]
async fn test_async_operation_with_drop_guard() {
    struct Guard;
    impl Drop for Guard {
        fn drop(&mut self) {
            // Cleanup happens here
        }
    }

    async fn operation_with_guard() {
        let _guard = Guard;
        sleep(Duration::from_millis(10)).await;
        // Guard dropped here
    }

    operation_with_guard().await;
    // Verify cleanup happened
}

// ============================================================================
// Retry Logic Tests (if applicable)
// ============================================================================

#[tokio::test]
async fn test_async_operation_retries_on_failure() {
    let mut attempts = 0;

    async fn flaky_operation(attempts: &mut i32) -> [ModuleName]Result<String> {
        *attempts += 1;
        if *attempts < 3 {
            Err([ModuleName]Error::TemporaryFailure)
        } else {
            Ok("success".to_string())
        }
    }

    // Retry logic
    let mut result = Err([ModuleName]Error::TemporaryFailure);
    for _ in 0..5 {
        result = flaky_operation(&mut attempts).await;
        if result.is_ok() {
            break;
        }
        sleep(Duration::from_millis(10)).await;
    }

    assert!(result.is_ok());
    assert_eq!(attempts, 3);
}

// ============================================================================
// Stream/Channel Tests (if using streams)
// ============================================================================

#[tokio::test]
async fn test_async_stream_processing() {
    use tokio::sync::mpsc;
    use tokio_stream::wrappers::ReceiverStream;
    use tokio_stream::StreamExt;

    let (tx, rx) = mpsc::channel(10);

    // Producer
    tokio::spawn(async move {
        for i in 0..5 {
            tx.send(i).await.ok();
        }
    });

    // Consumer
    let mut stream = ReceiverStream::new(rx);
    let mut results = Vec::new();

    while let Some(item) = stream.next().await {
        results.push(item);
    }

    assert_eq!(results, vec![0, 1, 2, 3, 4]);
}

// ============================================================================
// Helper Functions
// ============================================================================

// Add helper functions for creating test data, mocks, etc.