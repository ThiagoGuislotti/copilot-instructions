---
applyTo: "**/*.{ps1,md,json,jsonc,yml,yaml,cs,csproj,sln,rs,toml,ts,tsx,js,jsx,vue,sql}"
priority: high
---

# Worktree Isolation

Use this instruction when a workstream is risky, long-running, multi-task, or should avoid contaminating the current working tree.

Rules:
- Prefer an isolated `git worktree` for large features, parallel subagent execution, or experiments that may touch many files.
- Keep the main repository checkout clean when the workstream can be isolated safely.
- Use the repository-owned runtime helper `scripts/runtime/new-super-agent-worktree.ps1` instead of ad-hoc `git worktree` commands.
- Do not delete or prune worktrees automatically.
- Do not use destructive Git commands as part of worktree setup.

Default expectations:
- Worktree naming should be stable and slug-based.
- Branch naming should be deterministic and derived from the workstream slug when the user does not supply one.
- Worktree root should live outside the main repo directory by default.
- The workflow must stay Windows-safe and PowerShell-first.

When to prefer worktrees:
- multi-step features with isolated branch work
- subagent or worker execution where the write scope is broad
- review-heavy work that should not pollute the primary checkout
- risky refactors or migrations

When not to require worktrees:
- trivial documentation-only edits
- very small, low-risk changes in a clean working tree
- follow-up fixes that must stay in the current branch context