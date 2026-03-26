# Shared Repository Helper Expansion

## Summary
- Extend the shared repository helper layer so runtime, security, orchestration, and runtime test scripts stop re-implementing root resolution, verbose logging, and generic path utilities.
- Keep script-specific business logic local while centralizing the repeated infrastructure concerns.

## Motivation
- After moving validators onto shared logging, the next largest duplication remains in runtime, security, orchestration, and test scripts.
- The repeated helper code is mostly infrastructure logic, not domain logic:
  - repository root detection
  - verbose diagnostics
  - generic absolute-path resolution
  - repository-relative path conversion
- This is the right SOLID boundary: shared infrastructure in `scripts/common`, script-specific logic at the edge.

## Design Decisions
- Expand `scripts/common/repository-paths.ps1` instead of creating another overlapping helper.
- Make the shared helper strict-mode safe so tests and other scripts can use it without pre-initializing script-scope variables.
- Add these generic shared capabilities:
  - `Write-VerboseLog`
  - `Resolve-FullPath`
  - `Convert-ToRelativeRepoPath`
- Migrate duplicate helper blocks in:
  - `scripts/runtime/*.ps1`
  - `scripts/security/*.ps1`
  - `scripts/orchestration/**/*.ps1`
  - `scripts/tests/runtime/*.ps1`

## Alternatives Considered
- Create a separate `path-utils.ps1` helper.
  - Rejected because the repository already has a common path helper that is the natural home for these functions.
- Keep the duplicated helpers and only standardize logging style.
  - Rejected because the duplication problem is broader than log formatting; path utility code is repeated across many scripts.

## Risks
- Bulk migration can accidentally alter script bootstrap order.
- Strict-mode scripts can fail if the shared helper assumes preexisting state.
- Orchestration stages must preserve artifact-path behavior exactly.

## Acceptance Criteria
- `scripts/common/repository-paths.ps1` exposes strict-safe shared verbose and path helpers.
- Runtime, security, orchestration, and runtime tests no longer duplicate local implementations of those helpers.
- Existing validation and runtime test suites still pass.

## Planning Readiness
- Ready for planning.

## Recommended Specialist
- `Super Agent` with repository script refactor execution.