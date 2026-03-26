# Plan: Super Agent Universal Workspace Mode

## Objective

Make `Super Agent` operate as a universal startup controller across arbitrary repositories while preserving repository-owned adapter behavior inside repositories that provide local `.github` instructions and planning surfaces.

## Scope Summary

- `.github/hooks/scripts/common.ps1`
- `.github/hooks/scripts/session-start.ps1`
- `.github/hooks/scripts/subagent-start.ps1`
- `.github/AGENTS.md`
- `.github/copilot-instructions.md`
- `.github/instructions/super-agent.instructions.md`
- `.github/instructions/brainstorm-spec-workflow.instructions.md`
- `.github/instructions/subagent-planning-workflow.instructions.md`
- `.codex/skills/super-agent/`
- `.codex/skills/using-super-agent/`
- hook/runtime tests, docs, and changelog if needed

## Spec Path

- `planning/specs/active/spec-super-agent-universal-workspace-mode.md`

## Ordered Tasks

1. Add workspace-mode detection to the hook helper layer and emit explicit `workspace-adapter` vs `global-runtime` bootstrap context.
2. Define universal planning/spec fallback roots under `.build/super-agent/` for global runtime mode and propagate them through bootstrap text.
3. Update global runtime instructions and Super Agent skills so they stop assuming the `copilot-instructions` repository model when the workspace lacks a local adapter.
4. Extend hook/runtime tests to cover both modes and the universal fallback paths.
5. Update docs/changelog and move plan/spec to completed after validation.

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/bootstrap.ps1 -RepoRoot .`

## Recommended Specialist

- primary: runtime/hook orchestration
- secondary: instruction architecture and skill bootstrap

## Closeout Expectations

- update README only if the universal-mode behavior needs operator-facing documentation
- always produce a commit message suggestion
- update CHANGELOG because this changes the global startup-controller behavior

## Task Execution Notes

### Task 1
- Target paths:
  - `.github/hooks/scripts/common.ps1`
  - `.github/hooks/scripts/session-start.ps1`
  - `.github/hooks/scripts/subagent-start.ps1`
- Commands:
  - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- Checkpoints:
  - bootstrap context exposes workspace mode and correct path/routing fallback

### Task 2
- Target paths:
  - `.github/hooks/scripts/common.ps1`
  - `.github/instructions/super-agent.instructions.md`
  - `.github/instructions/brainstorm-spec-workflow.instructions.md`
  - `.github/instructions/subagent-planning-workflow.instructions.md`
- Commands:
  - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- Checkpoints:
  - global fallback uses `.build/super-agent/` and no longer assumes `planning/`

### Task 3
- Target paths:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `.codex/skills/super-agent/`
  - `.codex/skills/using-super-agent/`
- Commands:
  - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- Checkpoints:
  - runtime baseline is universal while preserving workspace adapter precedence

### Task 4
- Target paths:
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
  - `scripts/validation/validate-agent-hooks.ps1`
- Commands:
  - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
  - `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- Checkpoints:
  - tests cover both repo mode and global mode

### Task 5
- Target paths:
  - `CHANGELOG.md`
  - optional docs touched by the implementation
  - `planning/active/plan-super-agent-universal-workspace-mode.md`
  - `planning/specs/active/spec-super-agent-universal-workspace-mode.md`
- Commands:
  - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- Checkpoints:
  - validation green and planning/spec moved to completed