---
name: context-token-optimizer
description: Build a minimal context pack and recommend the correct specialist path for token-efficient execution. Use when the task is non-trivial, spans multiple domains, or should reduce token usage before implementation.
---

# Context Token Optimizer

## Load minimal context first

1. Load `.github/AGENTS.md`.
2. Load `.github/copilot-instructions.md`.
3. Load `.github/instruction-routing.catalog.yml`.
4. Load `.github/instructions/repository-operating-model.instructions.md`.
5. Load `.github/instructions/super-agent.instructions.md`.
6. Load `.github/instructions/subagent-planning-workflow.instructions.md`.
7. Reuse the shared `$core-context-router` skill for deterministic minimal routing.

## Responsibilities

- read the active planning document when one exists
- select the smallest context pack that still preserves correctness
- recommend the most appropriate specialist agent for execution
- keep documentation and closeout needs visible for later stages

## Output contract

1. minimal context pack
2. selected specialist skill
3. specialist reasoning
4. documentation and changelog follow-up flags
5. token-saving notes when a broader context was intentionally avoided