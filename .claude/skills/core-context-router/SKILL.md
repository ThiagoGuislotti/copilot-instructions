---
name: core-context-router
description: Route tasks using the repository's static routing catalog and load only the minimal context pack. Use before execution when the task spans multiple domains or the correct instruction set is unclear.
---

# Repo Context Router

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Route then execute

1. Route with:
   - `.github/instruction-routing.catalog.yml`
   - `.github/prompts/route-instructions.prompt.md`
2. Build a minimal context pack (2–5 domain files).
3. Execute using only the files selected by the context pack.

## Claude-native execution

Run as an `Explore` agent. Maps to the router role in the Super Agent pipeline.

## Rules

- Keep context minimal — prefer most specific instruction by scope/path on conflicts.
- Do not trim required execution context by default.
- If route is ambiguous, ask up to 3 short clarifying questions before proceeding.

## Output contract

1. Selected context pack (ordered file list)
2. Domain instructions chosen and why
3. Recommended specialist skill
4. Execution mode (`sequential` or `parallel-safe`)