# GitHub Definitions Coverage Completion Phase 5 Plan

Generated: 2026-03-26 09:25
LastUpdated: 2026-03-26 19:05

## Status

- State: completed
- Spec: `planning/specs/completed/spec-github-definitions-coverage-completion-phase-5.md`
- Priority: high
- Execution mode: non-destructive definitions coverage completion

## Objective And Scope

Complete the pre-Rust architecture work by closing the remaining GitHub provider-authoring gaps under `definitions/` so authored GitHub assets have one authoritative source before the Rust engine starts.

In scope for this phase:
- expand `definitions/providers/github/root/` to include the remaining authored root files
- add authoritative `definitions/providers/github/ISSUE_TEMPLATE/`
- add authoritative `definitions/providers/github/templates/`
- update the GitHub renderer, projection catalog, validation logic, and docs for the expanded coverage
- keep governance-native `.github/` assets explicit and unchanged where they intentionally remain authored in place

Out of scope:
- Rust/Cargo migration
- broad repository cleanup
- moving governance-native `.github/{governance,policies,runbooks,schemas,workflows}/` into `definitions/`
- deleting legacy/provider runtime folders

## Normalized Request Summary

The current `definitions/providers/github/` tree still misses several authored GitHub assets that already exist under `.github/`, especially issue templates, reusable repository templates, and a few root-level provider files. Before introducing Rust, the definitions tree should be complete enough that the authored GitHub provider surface is unambiguous and documented.

## Ordered Tasks

1. Register the phase-5 plan/spec and confirm the remaining GitHub authored surfaces that should move behind `definitions/`
2. Add the missing authoritative GitHub definition trees and files under `definitions/providers/github/`
3. Extend the GitHub renderer and the provider-surface projection catalog to project and validate those new surfaces
4. Update validation/docs/changelog/checksums for the completed coverage model
5. Run runtime validation and full install, then move the plan/spec to `completed`

## Validation Checklist

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

- Risk: moving more `.github/` assets behind `definitions/` could blur the line between provider-authored assets and governance-native assets.
  - Fallback: limit this phase to provider-authored root files, issue templates, and repository templates, and document the remaining native exceptions explicitly.
- Risk: the GitHub renderer could over-mirror directories that should remain native.
  - Fallback: expand the renderer only for the new explicit directories and keep the catalog authoritative.
- Risk: validation drift could increase if the new files are copied without catalog coverage.
  - Fallback: add the new surfaces to both the catalog and `validate-instructions.ps1` in the same slice.

## Recommended Specialists

- Planning: `plan-active-work-planner`
- Documentation: `docs-release-engineer`
- Review: `review-code-engineer`

## Closeout Expectations

- Keep commit guidance and changelog in English.
- Document clearly which `.github/` folders are now definitions-backed and which remain governance-native.
- Move the plan/spec to `completed` only after `validate-all` and the full install flow stay green.