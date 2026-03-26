---
name: docs-release-engineer
description: Produce and maintain repository documentation and release artifacts including README files, PR descriptions, changelog entries, prompt templates, and instruction docs. Use when the user asks to create or update docs/process files under .github or project root.
---

# Docs Release Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Documentation instruction packs

- README:
  - `.github/instructions/readme.instructions.md`
  - `.github/instructions/nettoolskit-rules.instructions.md`
- PR and release:
  - `.github/instructions/pr.instructions.md`
  - `.github/instructions/feedback-changelog.instructions.md`
- Prompt and instruction authoring:
  - `.github/instructions/prompt-templates.instructions.md`
  - `.github/instructions/copilot-instruction-creation.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent within the Super Agent pipeline.

## Execution workflow

1. Identify artifact type (README, PR text, changelog, prompt, instruction).
2. Apply the required structure/template from instruction files.
3. Keep technical text in English; preserve language policy.
4. For changelog updates, enforce semantic version format and ISO date.
5. Validate links and cross-references before finishing.

## Prompt accelerators

- `.github/prompts/generate-pr-description.prompt.md`
- `.github/prompts/generate-changelog.prompt.md`