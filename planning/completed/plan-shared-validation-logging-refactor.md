# Plan: Shared Validation Logging Refactor

## Objective
- Replace duplicated validation logging/state helpers with a shared implementation and migrate the validation family without changing observed validation outcomes.

## Scope
- `scripts/common/*.ps1`
- `scripts/validation/*.ps1`
- `scripts/runtime/validate-vscode-global-alignment.ps1`
- targeted docs/changelog updates

## Spec
- `planning/specs/active/spec-shared-validation-logging-refactor.md`

## Tasks
1. Create the shared validation helper.
   - Target paths: `scripts/common/validation-logging.ps1`, `scripts/common/repository-paths.ps1` if needed.
   - Checkpoint: helper exposes initialization, verbose logging, warning/failure registration, and reusable summary output.
2. Migrate validation-family scripts to the shared helper.
   - Target paths: `scripts/validation/*.ps1`, `scripts/runtime/validate-vscode-global-alignment.ps1`.
   - Checkpoint: duplicated helper blocks are removed and scripts still keep their script-specific checks.
3. Update docs and closeout artifacts.
   - Target paths: `scripts/README.md`, `CHANGELOG.md`.
   - Checkpoint: documentation mentions the shared validation log helper.
4. Validate and close out.
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
   - Checkpoint: validations pass and plan/spec can move to completed.

## Risks
- Warning-only validators may accidentally start failing hard.
- Bulk helper import could break scripts with unique summary/output expectations.

## Closeout Expectations
- Update changelog with the shared validation logging refactor.
- Provide a commit message.