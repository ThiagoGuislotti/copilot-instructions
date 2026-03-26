# EOF Origin Fix Plan

## Goal
- stop VS Code AI editing tools from writing repository files with a terminal newline when the repository policy requires `insert_final_newline = false`
- move the enforcement to the origin of the edit flow instead of relying on post-edit or pre-commit cleanup

## Scope
- repository-owned VS Code hooks under `.github/hooks/`
- mandatory top-level instruction files and session bootstrap context
- hook/runtime validation and documentation

## Implementation Steps
1. add a `PreToolUse` hook that normalizes edit/create tool payloads before the tool writes to disk
2. propagate the EOF policy into mandatory bootstrap and top-level instruction layers so the model sees it before generating edits
3. extend runtime tests and hook validation to cover the new hook and EOF normalization behavior
4. update README/changelog and close the workstream after validation

## Validation
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-agent-hooks.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/vscode-agent-hooks.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`