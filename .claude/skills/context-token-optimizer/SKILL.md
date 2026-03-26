---
name: context-token-optimizer
description: Assembles the minimal context pack for a given task. Use when the task spans multiple domains or the context set has obvious redundancy. Do not trim required working context by default.
---

# Context Token Optimizer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instruction-routing.catalog.yml`
4. `.github/prompts/route-instructions.prompt.md`

## Claude-native execution

- Run as an `Explore` agent within the Super Agent pipeline.
- Use Glob and Grep to identify the minimal file set for the task scope.
- Output a context pack (list of paths) to hand off to the specialist.

## Responsibilities

- Route through `.github/instruction-routing.catalog.yml` when the workspace provides it.
- Build the minimal local context pack from target repo structure when the catalog is unavailable.
- Identify domain instruction files relevant to the task.
- Recommend the specialist focus based on the assembled pack.
- Do not trim required execution context purely to save tokens.

## Output contract

1. Context pack (ordered list of files)
2. Domain instruction files selected
3. Recommended specialist skill
4. Rationale for inclusions and exclusions