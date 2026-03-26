# Runtime Path Portability And Post-Commit Performance Plan

Generated: 2026-03-21

## Status

- State: completed
- Owner: Super Agent
- Completed: 2026-03-21
- Result target: runtime sync/install resolves configurable cross-platform home targets from one shared contract, and `post-commit` skips expensive work when the commit did not touch relevant runtime sources.

## Objective And Scope

Make runtime projection and install scripts portable across machines where `.github`, `.codex`, `.agents`, and `.copilot` live in different directories and where the OS is not Windows. Reduce `post-commit` latency by avoiding sync and VS Code global alignment work when the commit does not change files that affect those runtime surfaces.

## Normalized Request Summary

The user reported two problems: runtime sync/install still assumes Windows-style home-relative folders such as `%USERPROFILE%\.github` and `%USERPROFILE%\.codex`, and `post-commit` became noticeably slower after new responsibilities were added. The repository should support configurable runtime locations, remain compatible with non-Windows PowerShell environments, and keep the default experience less wasteful without losing functionality.

## Design Decision

- Introduce a versioned runtime location catalog plus an optional user-local override file so all runtime scripts resolve the same effective targets from one contract.
- Fix shared path helpers to build OS-correct paths from segments instead of embedding Windows backslashes in child paths.
- Update runtime scripts and docs/tests to use the centralized location resolution rather than repeated `Join-Path $userHome '.github'` / `'.codex'` assumptions.
- Make `post-commit` inspect the files changed in `HEAD` and run sync and VS Code global alignment only when the commit touched paths that actually affect those runtime surfaces.
- Keep runtime cleanup and optional MCP apply behavior intact, but avoid paying the VS Code alignment cost on unrelated commits.

## Ordered Tasks

1. Add the shared runtime location catalog/helper and make path resolution cross-platform and override-aware.
2. Migrate bootstrap/install/doctor/healthcheck/self-heal and related docs/tests to the shared runtime location contract.
3. Refactor `post-commit` to detect changed-path relevance and skip sync / VS Code global alignment when not needed.
4. Extend tests, docs, checksums, and changelog; then close out the plan.

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shell-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Closeout

- Implemented a shared runtime location catalog plus machine-local override contract for runtime sync/install, Git hooks, and MCP sync paths.
- Removed Windows-only path assumptions from the critical runtime/install/helper chain by switching to shared OS-safe path segment joins.
- Reduced `post-commit` latency by skipping runtime sync and VS Code global alignment when `HEAD` did not touch relevant managed sources.
- Added runtime regression coverage for custom runtime locations and fixed shared helper resolution for `.codex/scripts` callers.