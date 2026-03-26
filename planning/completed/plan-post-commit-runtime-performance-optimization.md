# Post-Commit Runtime Performance Optimization Plan

## Objective
- reduce the latency of the local post-commit critical path without changing the default behavior or introducing new disable switches
- keep runtime sync, VS Code alignment validation, and runtime cleanup deterministic and safe for this repository

## Completed Work

1. Measured the current post-commit critical path and confirmed the main cost profile before changes:
   - `bootstrap.ps1`: ~1121 ms
   - `validate-vscode-global-alignment.ps1`: ~3139 ms
   - `clean-codex-runtime.ps1`: ~457 ms
2. Refactored `scripts/runtime/bootstrap.ps1` to:
   - cache `robocopy` resolution once per run
   - reuse a shared `robocopy` argument set with multithreaded copy enabled
   - replace per-skill repository skill projection with a single root sync into `~/.agents/skills` when `robocopy` is available
3. Refactored `.githooks/post-commit` to run runtime cleanup concurrently with the slower VS Code global alignment validation while replaying cleanup output after validation completes.
4. Re-measured the critical path after the changes:
   - `bootstrap.ps1`: ~647 ms
   - `validate-vscode-global-alignment.ps1`: ~3579 ms
   - `clean-codex-runtime.ps1`: ~458 ms
   - `post-commit`: ~4123 ms
5. Confirmed the gain came from reducing redundant skill sync work and overlapping cleanup with validation, without changing default hook behavior.

## Validation
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shell-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `sh .githooks/post-commit`

## Outcome

The post-commit path now does less redundant runtime sync work and overlaps cleanup with VS Code global alignment validation, reducing the end-to-end hook latency without adding any new disable switches or changing the repository defaults.