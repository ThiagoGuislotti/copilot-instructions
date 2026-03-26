---
name: code-review-engineer
description: Perform repository-aware code reviews focused on bugs, regressions, architectural violations, missing tests, and operational risks. Use when the user asks for review of diffs, pull requests, patches, or implementation quality.
---

# Code Review Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Load `.github/instructions/pr.instructions.md`.
3. Route additional domain instructions with `.github/instruction-routing.catalog.yml` based on changed files.

## Review order

1. Correctness and behavior regressions.
2. Architecture boundary violations and layering breaks.
3. Missing or weak tests for changed behavior.
4. Security, resilience, and performance risks.
5. Documentation/changelog impact for user-visible or process changes.

## Review output format

1. Findings first, ordered by severity.
2. For each finding: file path, risk, evidence, and precise fix recommendation.
3. If no findings, state that explicitly and list residual risks/testing gaps.

## Useful references

- `.github/instructions/clean-architecture-code.instructions.md`
- `.github/instructions/backend.instructions.md`
- `.github/instructions/frontend.instructions.md`
- `.github/instructions/database.instructions.md`
- `.github/instructions/ci-cd-devops.instructions.md`
- `.github/chatmodes/clean-architecture-review.chatmode.md`