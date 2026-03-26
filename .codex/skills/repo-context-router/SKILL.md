---
name: repo-context-router
description: Route tasks using this repository's static routing catalog and load only the minimal context pack.
---

# Repo Context Router

Use this skill when the task should follow the repo routing model before execution.

## Always Load First

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`

## Route Then Execute

1. Route with:
   - `.github/instruction-routing.catalog.yml`
   - `.github/prompts/route-instructions.prompt.md`
2. Build a minimal context pack.
3. Execute using only the files selected by the context pack.

## Rules

- Keep context minimal (2-5 domain files whenever possible).
- Prefer the most specific instruction by scope/path on conflicts.
- If route is ambiguous, ask up to 3 short clarifying questions.