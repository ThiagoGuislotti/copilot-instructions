---
name: worktree-isolation-engineer
description: Create safe, deterministic git worktrees for large or risky workstreams. Use when tasks are complex enough to warrant isolation from the main working tree.
---

# Worktree Isolation Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/super-agent.instructions.md`
4. `.github/instructions/worktree-isolation.instructions.md`
5. `.github/instructions/repository-operating-model.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent. Use the Agent tool with `isolation: "worktree"` for truly isolated work.

## Responsibilities

- Decide whether the current workstream should move into an isolated worktree.
- Prefer the repository-owned script `scripts/runtime/new-super-agent-worktree.ps1` when available.
- Keep branch and folder naming deterministic.
- Preserve Windows-safe path defaults.
- Avoid destructive cleanup or implicit pruning.

## Output contract

1. Whether worktree isolation is recommended
2. Worktree name slug
3. Branch name
4. Worktree root and path
5. Creation command or execution result