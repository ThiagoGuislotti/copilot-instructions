# Plan: Install Healthcheck Noise Reduction

## Objective

Reduce false-positive error perception during `scripts/runtime/install.ps1` by making runtime test execution quiet on success while preserving diagnostics on real failure.

## Tasks

1. Inspect `validate-runtime-script-tests.ps1` and identify where child test output leaks to the host stream.
2. Capture child test output and replay it only when:
   - verbose mode is enabled
   - the test fails
3. Validate the updated runtime test runner directly and through `install.ps1` preview/healthcheck paths.
4. Update docs and changelog if the behavior changes materially.