# Shared Authority Boundary Refactor Phase 6 Plan

Generated: 2026-03-26 10:22
LastUpdated: 2026-03-26 11:07

## Status

- State: completed
- Spec: `planning/specs/completed/spec-shared-authority-boundary-refactor-phase-6.md`
- Priority: high
- Execution mode: non-destructive boundary correction before Rust

## Objective And Scope

Correct the remaining authority-boundary mistakes in `definitions/` before any Rust work begins so the repository clearly separates shared authored assets, provider-specific runtime surfaces, and GitHub-native repository/community assets.

In scope for this phase:
- add `definitions/shared/` as the authoritative home for shared instructions and shared reusable templates
- move authored instructions out of `definitions/providers/github/instructions/` into `definitions/shared/instructions/`
- move shared reusable templates out of `definitions/providers/github/templates/` into `definitions/shared/templates/`
- narrow `definitions/providers/github/` to GitHub/Copilot runtime-only surfaces
- remove GitHub-native repository/community assets from provider projection ownership:
  - `.github/PULL_REQUEST_TEMPLATE.md`
  - `.github/ISSUE_TEMPLATE/**`
  - `.github/dependabot.yml`
  - `.github/dependency-review-config.yml`
- update renderers, projection catalog, validation, tests, docs, and checksums

Out of scope:
- Rust/Cargo migration
- broad repository cleanup
- changing GitHub-native governance assets that remain authored in place
- deleting runtime-facing `.github`, `.codex`, `.claude`, or `.vscode` surfaces

## Normalized Request Summary

The current `definitions/providers/github/` tree still mixes three authority types: GitHub/Copilot runtime surfaces, shared reusable assets, and GitHub-native repository/community files. That boundary is wrong. Before the Rust phase starts, the definitions tree must be corrected so `shared` owns reusable instructions/templates, `providers/github` owns only GitHub runtime surfaces, and GitHub-native cloud/community files remain authored directly in `.github/`.

## Ordered Tasks

1. Register the phase-6 plan/spec and define the corrected authority model
2. Create `definitions/shared/` and move shared instructions/templates into it
3. Remove GitHub-native repository/community files from provider ownership and keep them native in `.github/`
4. Update GitHub projection scripts, provider-surface catalog, validation rules, runtime tests, and docs for the corrected boundary
5. Run full validation and install, then move the plan/spec to `completed`

## Completion Summary

- `definitions/shared/instructions/` is now the authority for reusable
  instruction files projected into `.github/instructions/`
- `definitions/shared/templates/` is now the authority for reusable templates
  projected into `.github/templates/`
- `definitions/providers/github/` now owns only provider-specific runtime
  surfaces: `root/`, `agents/`, `chatmodes/`, `prompts/`, and `hooks/`
- GitHub-native repository/community files remain authored directly in
  `.github/`:
  - `PULL_REQUEST_TEMPLATE.md`
  - `ISSUE_TEMPLATE/**`
  - `dependabot.yml`
  - `dependency-review-config.yml`
- validation passed:
  - `validate-instructions`
  - `runtime-scripts.tests`
  - `validate-powershell-standards -SkipScriptAnalyzer`
  - `validate-readme-standards`
  - `update-shared-script-checksums-manifest`
  - `validate-shared-script-checksums -WarningOnly:$false`
  - `validate-runtime-script-tests -WarningOnly:$false`
  - `validate-planning-structure -WarningOnly:$false`
  - `validate-all -ValidationProfile dev`
  - `install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig -GitHookEofMode autofix -GitHookEofScope global`

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/runtime/render-github-instruction-surfaces.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig -GitHookEofMode autofix -GitHookEofScope global`

## Risks And Fallbacks

- Risk: moving instructions/templates to `definitions/shared/` could break renderers or tests that still assume `definitions/providers/github/`.
  - Fallback: keep projection targets unchanged and update renderers/tests in the same slice.
- Risk: removing GitHub-native files from provider projection could leave stale docs or validation paths.
  - Fallback: update catalog, docs, and validation together and rerender `.github/` before running the suite.
- Risk: partial migration could leave duplicate authored copies in both `shared` and `providers/github`.
  - Fallback: move the authoritative copies and remove the provider-owned duplicates in the same checkpoint.

## Recommended Specialists

- Planning: `plan-active-work-planner`
- Architecture/spec: `brainstorm-spec-architect`
- Documentation: `docs-release-engineer`
- Review: `review-code-engineer`

## Closeout Expectations

- Keep commit guidance and changelog in English.
- Explicitly document the corrected split between `definitions/shared/`, `definitions/providers/github/`, and native `.github/`.
- Do not start Rust/Cargo work in this phase.