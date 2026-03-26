# Provider Surface Projection Expansion Phase 2 Plan

Generated: 2026-03-26 05:30
LastUpdated: 2026-03-26 06:49

## Status

- State: completed
- Spec: `planning/specs/completed/spec-provider-surface-projection-expansion-phase-2.md`
- Priority: high
- Execution mode: non-destructive projection expansion

## Objective And Scope

Extend the `definitions/ -> projected surface` architecture to the next set of provider-authored assets that still live directly under `.github`, `.codex`, `.claude`, and `.vscode`, while keeping provider/runtime folders intact and without entering Rust/Cargo migration or broad repository cleanup.

In scope for this phase:
- GitHub chatmode surfaces
- VS Code workspace-owned authored assets that are still versioned directly under `.vscode`
- Codex orchestration authored assets that are still versioned directly under `.codex/orchestration`
- Claude runtime-authored settings surface
- renderer/bootstrap/validation/doc updates required to keep the new authoritative paths deterministic

Out of scope:
- Rust/Cargo migration
- destructive removal of provider/runtime folders
- broad repository cleanup unrelated to source/projection authority

## Normalized Request Summary

The repository already moved provider skills, GitHub instruction/root surfaces, and VS Code profiles into `definitions/`, but more authored content still lives directly inside projected runtime folders. The remaining problem is architectural consistency: provider/runtime folders should increasingly become render targets, while authored non-code assets should move behind one authoritative tree and `scripts/` should remain the only operational layer. The user explicitly does not want cleanup-driven deletion yet; the migration must stay additive and safe.

## Ordered Tasks

1. [2026-03-26 05:30] Register phase-2 plan/spec and map remaining authored provider surfaces
2. [2026-03-26 05:30] Move GitHub chatmodes into `definitions/providers/github/chatmodes/` and extend the GitHub renderer plus parity validation
3. [2026-03-26 05:30] Move VS Code authored workspace assets into `definitions/providers/vscode/workspace/` and render `.vscode/README.md`, `.vscode/base.code-workspace`, `.vscode/settings.tamplate.jsonc`, and `.vscode/snippets/**`
4. [2026-03-26 05:30] Move Codex orchestration authored assets into `definitions/providers/codex/orchestration/` and render `.codex/orchestration/**`
5. [2026-03-26 05:30] Move Claude authored runtime settings into `definitions/providers/claude/runtime/` and render `.claude/settings.json`
6. [2026-03-26 05:30] Update bootstrap/install-adjacent render flow, validations, tests, README/changelog, and close out the workstream when parity is green

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

- Risk: a projected folder may still contain native runtime-only files that should not move into `definitions/`.
  - Fallback: classify those files explicitly and leave them native.
- Risk: renderer expansion could over-mirror and delete runtime-native files.
  - Fallback: keep renderers scoped to the exact authored subtrees and retain non-managed folders untouched.
- Risk: bootstrap/install could drift if new renderers are not called consistently.
  - Fallback: wire the renderers into bootstrap before sync and validate parity in runtime tests.

## Recommended Specialists

- Implementation: `ops-devops-platform-engineer`
- Documentation: `docs-release-engineer`
- Review: `review-code-engineer`

## Closeout Expectations

- Update README/script docs to explain the expanded authority boundaries.
- Keep commit guidance and changelog in English.
- Move the plan/spec to `completed` only after runtime validation and install are green.