# Codex Compatibility Surface Projection Phase 3 Plan

Generated: 2026-03-26 10:30
LastUpdated: 2026-03-26 10:30

## Status

- State: completed
- Spec: `planning/specs/completed/spec-codex-compatibility-surface-projection-phase-3.md`
- Priority: high
- Execution mode: non-destructive projection expansion

## Objective And Scope

Finish the remaining Codex-authored compatibility surfaces that still live directly under `.codex/` by moving their authored copies behind `definitions/` while keeping the projected runtime folders intact and without entering Rust/Cargo migration or broad repository cleanup.

In scope for this phase:
- `.codex/mcp/README.md`
- `.codex/mcp/codex.config.template.toml`
- `.codex/mcp/vscode.mcp.template.json`
- `.codex/scripts/README.md`
- `.codex/scripts/render-vscode-mcp.ps1`
- `.codex/scripts/sync-mcp-to-codex-config.ps1`
- renderer/bootstrap/validation/test/doc updates required to keep parity green

Out of scope:
- `.codex/mcp/servers.manifest.json` source ownership changes (it remains generated from `.github/governance/mcp-runtime.catalog.json`)
- Rust/Cargo migration
- destructive cleanup of projected provider/runtime folders
- broad repository cleanup unrelated to authority boundaries

## Normalized Request Summary

The repository already moved provider skill surfaces, GitHub instruction/runtime surfaces, VS Code authored workspace surfaces, Codex orchestration, and Claude runtime settings behind `definitions/`. The remaining architectural inconsistency is in Codex compatibility assets: thin wrappers and MCP support docs/templates are still authored directly inside `.codex/`. The safe completion slice is to make these assets authoritative under `definitions/providers/codex/` while keeping `.codex/` as a projected runtime surface and leaving generated MCP manifest ownership unchanged.

## Ordered Tasks

1. [2026-03-26 10:30] Register phase-3 plan/spec and create authoritative `definitions/providers/codex/{mcp,scripts}/` trees from the current tracked assets
2. [2026-03-26 10:30] Add a Codex compatibility renderer that projects authored support files into `.codex/mcp/` and `.codex/scripts/` without touching the generated manifest
3. [2026-03-26 10:30] Wire the new renderer into bootstrap before Codex runtime sync consumes `.codex/` surfaces
4. [2026-03-26 10:30] Extend validation and runtime tests to prove parity for the new authored Codex compatibility surfaces
5. [2026-03-26 10:30] Update README/script docs/changelog/definitions coverage and close out the phase when runtime validation and install are green

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig -GitHookEofMode autofix -GitHookEofScope global`

## Risks And Fallbacks

- Risk: the Codex compatibility renderer could accidentally remove generated files from `.codex/mcp/`.
  - Fallback: scope MCP projection to selected authored files only and leave `servers.manifest.json` under the catalog renderer.
- Risk: wrapper parity may drift if compatibility wrappers remain editable in two places.
  - Fallback: treat `.codex/scripts/` as fully mirrored from `definitions/providers/codex/scripts/` and validate the full directory hash.
- Risk: bootstrap ordering could regress shared runtime sync if render happens after mirror.
  - Fallback: invoke the compatibility renderer before any Codex runtime copy step.

## Recommended Specialists

- Implementation: `ops-devops-platform-engineer`
- Documentation: `docs-release-engineer`
- Review: `review-code-engineer`

## Closeout Expectations

- Update README/script docs to explain that `.codex/mcp/` support docs/templates and `.codex/scripts/` wrappers are now projected surfaces.
- Keep commit guidance and changelog in English.
- Move the plan/spec to `completed` only after runtime validation and install are green.