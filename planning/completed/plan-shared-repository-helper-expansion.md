# Plan: Shared Repository Helper Expansion

## Objective
- Remove duplicated repository helper logic from runtime, security, orchestration, and runtime tests by expanding and reusing the shared common helper layer.

## Scope
- `scripts/common/repository-paths.ps1`
- `scripts/runtime/*.ps1`
- `scripts/security/*.ps1`
- `scripts/orchestration/**/*.ps1`
- `scripts/tests/runtime/*.ps1`
- targeted docs and changelog

## Spec
- `planning/specs/active/spec-shared-repository-helper-expansion.md`

## Tasks
1. Expand the shared repository helper.
   - Target paths: `scripts/common/repository-paths.ps1`
   - Checkpoint: helper provides strict-safe verbose log plus generic full-path and repo-relative-path utilities.
2. Migrate runtime and security scripts.
   - Target paths: `scripts/runtime/*.ps1`, `scripts/security/*.ps1`
   - Checkpoint: duplicate helper blocks removed and scripts load the shared helper instead.
3. Migrate orchestration stages and runtime tests.
   - Target paths: `scripts/orchestration/**/*.ps1`, `scripts/tests/runtime/*.ps1`
   - Checkpoint: duplicated path/log helpers removed without changing orchestration or test behavior.
4. Update docs and validate.
   - Target paths: `scripts/README.md`, `CHANGELOG.md`, checksum manifest.
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Risks
- Helper load order regressions.
- Unintended behavior drift in orchestration artifact paths.

## Closeout Expectations
- Update changelog.
- Provide commit message.