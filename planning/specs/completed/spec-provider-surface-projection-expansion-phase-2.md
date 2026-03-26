# Provider Surface Projection Expansion Phase 2

Generated: 2026-03-26

## Objective

Expand the authoritative `definitions/` model to the next set of provider-authored non-code surfaces so that projected runtime folders keep behaving the same while more content is authored from one stable source tree.

## Problem Statement

The repository completed phase 1 of the topology refactor, but authored provider content still remains directly inside projected folders in a few high-signal areas:
- `.github/chatmodes/`
- `.vscode/README.md`, `.vscode/base.code-workspace`, `.vscode/settings.tamplate.jsonc`, `.vscode/snippets/**`
- `.codex/orchestration/**`
- `.claude/settings.json`

That keeps authority split across `definitions/` and projected runtime folders. The next safe slice is to move these authored assets behind the same projection model without deleting the projected folders themselves.

## Design Summary

This phase keeps the architecture hybrid and non-destructive:
- `definitions/` owns authored provider assets
- `.github/.codex/.claude/.vscode` remain projected/runtime surfaces
- `scripts/` stays the only operational entrypoint layer
- bootstrap/install/tests validate parity before runtime sync consumes projected outputs

### Authoritative additions in this phase

- `definitions/providers/github/chatmodes/`
- `definitions/providers/vscode/workspace/`
- `definitions/providers/codex/orchestration/`
- `definitions/providers/claude/runtime/`

### Projected surfaces affected

- `.github/chatmodes/`
- `.vscode/README.md`
- `.vscode/base.code-workspace`
- `.vscode/settings.tamplate.jsonc`
- `.vscode/snippets/**`
- `.codex/orchestration/**`
- `.claude/settings.json`

## Decisions

1. Chatmodes are provider-authored assets and should follow the same projection model as prompts/instructions.
2. VS Code workspace assets are authored configuration baselines and should move behind `definitions/providers/vscode/workspace/`.
3. Codex orchestration prompts/templates/manifests are provider-authored runtime content and should no longer be edited directly in `.codex/orchestration/`.
4. Claude settings should be treated as an authored runtime surface with projection, while the machine-local merge target remains `~/.claude/settings.json`.
5. Thin compatibility wrappers may remain in projected runtime folders when an external tool expects that path, but the operational logic must stay in `scripts/`.

## Constraints

- Do not introduce Rust/Cargo in this phase.
- Do not do broad repo cleanup unrelated to source/projection authority.
- Do not remove projected provider folders; only change where authored content originates.
- Keep install/bootstrap/runtime sync behavior stable for operators.

## Acceptance Criteria

1. GitHub chatmodes are authored from `definitions/providers/github/chatmodes/` and rendered into `.github/chatmodes/`.
2. VS Code authored workspace assets are authored from `definitions/providers/vscode/workspace/` and rendered into `.vscode/`.
3. Codex orchestration content is authored from `definitions/providers/codex/orchestration/` and rendered into `.codex/orchestration/`.
4. Claude authored settings are sourced from `definitions/providers/claude/runtime/` and rendered into `.claude/settings.json`.
5. Bootstrap triggers the relevant renderers before sync consumes the projected surfaces.
6. Validation/tests prove parity and the full install stays green.

## Risks

- Some projected files may still be native runtime metadata and should remain where they are.
- Overbroad directory mirroring could delete files that are intentionally native.
- README/doc drift can reintroduce ambiguity about which path is authoritative.

## Mitigations

- Scope each renderer to the exact authored subtree.
- Keep native runtime/governance assets documented as native when they are not moved.
- Update README and script docs alongside the renderer changes.

## Planning Readiness

ready-for-plan