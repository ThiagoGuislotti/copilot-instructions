# Plan: Super Agent Unified Starter And Copilot Native Surface

## Objective

Deliver a stronger universal Super Agent workflow by collapsing the visible starter surface to `super-agent`, requiring spec-before-plan for non-trivial work, and exposing native Copilot skill/agent surfaces without regressing the current runtime.

## Spec Reference

- `planning/specs/completed/spec-super-agent-unified-starter-copilot-native.md`

## Ordered Tasks

1. Remove the extra visible starter alias and update runtime tests that depended on it.
2. Harden Super Agent instructions and skills so non-trivial change-bearing work requires spec registration before planning.
3. Add native Copilot skill and agent profile surfaces.
4. Extend runtime bootstrap, doctor, healthcheck, install, self-heal, and audit export to cover `~/.copilot/skills`.
5. Update repository documentation and changelog.
6. Run targeted runtime/instruction validation and the full validation profile used by this repo.

## Validation Checklist

- `scripts/tests/runtime/runtime-scripts.tests.ps1`
- `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
- `scripts/validation/validate-instructions.ps1`
- `scripts/validation/validate-runtime-script-tests.ps1 -WarningOnly:$false`
- `scripts/validation/validate-readme-standards.ps1`
- `scripts/validation/validate-all.ps1 -ValidationProfile dev`
- `scripts/runtime/bootstrap.ps1 -RepoRoot .`

## Risks And Mitigations

- Runtime target drift: mitigate by extending doctor/healthcheck/export to the new Copilot target.
- Instruction drift: mitigate by updating AGENTS, copilot instructions, lifecycle instructions, and the super-agent skill together.
- Picker confusion: mitigate by removing the alias instead of introducing another entry.

## Specialist Focus

- `Super Agent` controller
- runtime/bootstrap maintenance
- docs/release updates

## Closeout Expectations

- update `CHANGELOG.md`
- provide a semantic commit message
- move plan and spec to completed once validation passes

## Completion Notes

- Completed on `2026-03-21`.
- `using-super-agent` was removed from the repository-managed skill set so `super-agent` is the only visible starter/controller.
- Non-trivial change-bearing work now requires `spec -> plan` in the Super Agent lifecycle instructions and skill contract.
- Native Copilot surfaces were added under `.github/skills/super-agent/` and `.github/agents/super-agent.agent.md`.
- Runtime sync and drift tooling now track `%USERPROFILE%\\.copilot\\skills`.

## Validation Status

- `passed` `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/runtime/bootstrap.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`