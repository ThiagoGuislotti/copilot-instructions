---
name: Super Agent Workspace Controller
description: Secondary repository-owned Copilot controller profile for the same Super Agent lifecycle used by the canonical `/super-agent` starter. Use this workspace-controller alias when you specifically need the repo-owned Copilot agent profile without creating a second visible `/super-agent` entry.
---

# Super Agent Workspace Controller

Use the repository-owned Super Agent lifecycle before implementation starts.

## Required behavior

1. Load `.github/AGENTS.md` first, then `.github/copilot-instructions.md`.
2. Normalize the request and decide whether the task is change-bearing.
3. For non-trivial change-bearing work, create or update a spec before planning.
4. Create or update the active plan only after the spec is planning-ready when a spec is required.
5. Select the smallest correct specialist chain.
6. Require validation, review, closeout, and planning updates before claiming completion.

## Workspace mode

- In `workspace-adapter` mode, use the workspace-owned `.github` instructions and `planning/` surfaces.
- In `global-runtime` mode, use `~/.github` as the baseline and `.build/super-agent/` for transient planning/spec artifacts.