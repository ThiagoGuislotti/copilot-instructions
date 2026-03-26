# Git Hook EOF Hygiene Mode Plan

Generated: 2026-03-21

## Status

- State: completed
- Owner: Super Agent
- Result target: pre-commit can enforce staged EOF hygiene in a configurable local mode without hardcoding intrusive behavior for every machine.

## Objective And Scope

Add a local, install-configured hook mode for EOF hygiene so a specific machine/clone can opt into intrusive pre-commit auto-fix behavior while the repository keeps the behavior explicit and configurable.

## Normalized Request Summary

The user reported that VS Code stage actions do not trigger manual trim behavior, which allowed trailing blank lines at EOF to pass into commits and pushes. The requested fix is to support a more intrusive mode on this PC, configured through install-style parameters, and to make each commit read the current configuration so hook behavior changes apply immediately.

## Design Decision

- Keep the repository policy explicit through a versioned catalog of supported hook hygiene modes.
- Persist the selected mode locally for this clone/machine under `.git/` so it is not committed and can differ across PCs.
- Make `pre-commit` read that local configuration on every commit.
- Support at least `manual` and `autofix` modes, with `manual` remaining the safer baseline.
- In `autofix`, trim only staged files and re-stage them before the existing validation flow.

## Ordered Tasks

1. Add the versioned hook hygiene mode catalog and local-config helper
2. Add an installer/setup path that writes the selected local mode for this clone
3. Update `pre-commit` to read the local config and run staged-file trim + re-add in `autofix`
4. Add runtime tests and README/docs for the new hook mode
5. Validate hook/runtime behavior and close out the plan

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/git-hook-eof-hygiene.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shell-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`