# Spec: Shared Helper Loader Bootstrap

## Problem
- Many scripts still duplicate the same helper import logic for `console-style`, `repository-paths`, `runtime-paths`, and `validation-logging`.
- The duplication increases maintenance cost and makes mirrored runtime fallback changes harder to apply consistently.

## Goal
- Introduce one shared loader that resolves helper files from repository and mirrored runtime layouts, then reuse it across scripts with a short and stable call pattern.

## Non-Goals
- Rewriting helper implementations themselves.
- Changing runtime behavior beyond helper import resolution.

## Design
1. Add a shared loader under `scripts/common/`.
2. Loader responsibilities:
   - resolve helper roots from the caller script root
   - support repository `scripts/common`
   - support mirrored `.github/scripts/common`
   - support mirrored `.codex/shared-scripts/common`
   - import one or more named helpers deterministically
3. Call pattern in consumer scripts:
   - locate the shared loader with the minimal fallback list
   - dot-source the loader once with `-CallerScriptRoot` and `-Helpers`
   - keep the helper resolution contract declarative at the call site
4. Keep existing helper behavior untouched after import.

## Acceptance Criteria
- Consumer scripts no longer inline helper path detection for the common helper set.
- Mirrored runtime paths still work for orchestration and runtime scripts.
- Validation suite passes without warnings or failures.

## Final Notes
- The canonical consumer pattern is:
  - `. $script:CommonBootstrapPath -CallerScriptRoot $PSScriptRoot -Helpers @('console-style', 'repository-paths')`
- The direct dot-sourced invocation is used so imported helper functions materialize in the consumer script scope without extra wrapper duplication.