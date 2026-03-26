# Global Git Hook Authority Plan

Generated: 2026-03-21

## Status

- State: completed
- Owner: Super Agent
- Result target: global EOF hygiene mode configures a real machine-wide `core.hooksPath`, while local-repo remains an explicit override.

## Objective And Scope

Correct the EOF hook scope model so `global` means Git global hook authority, not just a global mode selection file. Keep the default non-intrusive behavior and preserve explicit local-repo overrides.

## Normalized Request Summary

The user wants global mode to actually be authoritative through Git global configuration, not merely through a persisted mode file. Local scope must remain available as an override, and install/setup should keep the least intrusive default.

## Design Decision

- Keep EOF mode selection precedence as `local-repo -> global -> catalog default`.
- Make `global` configure `git config --global core.hooksPath` to a managed hook directory.
- Keep local repo `.githooks` for repository-specific validation/post-* flows.
- Make the global hook install only the shared `pre-commit` EOF hygiene behavior.
- Allow the global managed hook to resolve support files from runtime-synced paths first, then fall back to the source repository paths when runtime sync is not yet present.

## Ordered Tasks

1. Add runtime helpers for managed global hook path resolution
2. Make EOF mode catalog resolution work outside adapter-enabled repositories
3. Rework `setup-git-hooks.ps1` so `global` installs a real global hook path and `local-repo` keeps `.githooks`
4. Update pre-commit EOF runner to work in arbitrary repositories with runtime or source fallbacks
5. Extend tests, docs, and changelog for the real global hook authority model

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/git-hook-eof-hygiene.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`