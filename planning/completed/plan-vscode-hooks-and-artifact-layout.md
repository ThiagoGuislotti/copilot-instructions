# VS Code Hooks And Artifact Layout Plan

## Scope
- Add repository-owned VS Code agent hooks for automatic session bootstrap in Copilot and Codex sessions running inside VS Code.
- Standardize non-versioned build and deployment artifacts under `.build/` and `.deployment/`.

## Work Items
1. Add versioned VS Code hook configuration under `.github/hooks/` with runtime-safe PowerShell entrypoints.
2. Add a validation script and runtime tests for hook bootstrap behavior.
3. Add a canonical artifact-layout instruction and align routing plus repository operating rules.
4. Update VS Code global settings template so user-level hooks load from `~/.github/hooks`.
5. Update README and CHANGELOG to document the new bootstrap and artifact workspace policy.

## Validation
- `pwsh -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- `pwsh -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -File scripts/validation/validate-vscode-global-alignment.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`