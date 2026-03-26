# Git Hook EOF Hygiene Scope Plan

Generated: 2026-03-21

## Status

- State: completed
- Owner: Super Agent
- Result target: EOF hook mode can be configured per repo clone or globally, with install keeping the default less intrusive and making the scope choice explicit.

## Objective And Scope

Extend the existing configurable EOF hook mode so teams can choose whether the mode selection is stored only for the current repository/worktree or as a global machine-level preference, while preserving the current default manual behavior.

## Normalized Request Summary

The user wants the intrusive EOF autofix behavior to be configurable either globally or per repository. The installer should ask whether the selection should be global when a hook mode is being configured, and the default should remain the least intrusive behavior.

## Design Decision

- Keep mode and scope explicit through versioned governance data.
- Resolve effective behavior in this order: local-repo override, global setting, catalog default.
- Store global EOF settings outside the repository under the user profile runtime area.
- Let `install.ps1` prompt for scope only when a hook mode is requested without an explicit scope.
- Keep the default scope less intrusive (`local-repo`) and the default mode less intrusive (`manual`).

## Ordered Tasks

1. Extend the EOF settings helper and catalog to support scope resolution and global storage
2. Update hook setup and install flows to accept scope and prompt when needed
3. Extend tests, docs, and changelog for global/local behavior and validate end to end

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