# Plan: Hook Super Agent Selector

## Objective

Allow the repository-owned VS Code hook bootstrap to select a different startup controller while keeping `Super Agent` as the tracked default.

## Completed Work

1. Added the versioned selector contract under `.github/hooks/super-agent.selector.json`.
2. Extended `.github/hooks/scripts/common.ps1` to resolve the startup controller from:
   - repository default
   - optional local override file under `~/.github/hooks`
   - environment override through `COPILOT_SUPER_AGENT_SKILL` and `COPILOT_SUPER_AGENT_NAME`
3. Updated SessionStart and SubagentStart bootstrap context to announce the selected startup controller and its resolution source.
4. Extended `scripts/validation/validate-agent-hooks.ps1` to require and validate the selector contract.
5. Extended `scripts/tests/runtime/vscode-agent-hooks.tests.ps1` to verify:
   - default selection
   - environment override selection
6. Updated `README.md`, `scripts/README.md`, and `CHANGELOG.md` to document the selector and override behavior.
7. Revalidated the hook flow and synced the runtime projection.

## Validation

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/bootstrap.ps1 -RepoRoot .`

## Outcome

The hook bootstrap now supports a repository-owned default startup controller with controlled untracked overrides, without changing the versioned default behavior.