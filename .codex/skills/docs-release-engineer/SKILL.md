---
name: docs-release-engineer
description: Produce and maintain repository documentation and release artifacts, including README files, PR descriptions, changelog entries, prompt templates, and instruction docs. Use when the user asks to create or update docs/process files under .github or project root.
---

# Docs Release Engineer

## Load minimal context first

1. Load `.github/AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/repository-operating-model.instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Load documentation/process packs based on target file type.

## Documentation instruction packs

- README documentation:
  - `.github/instructions/readme.instructions.md`
  - `.github/instructions/nettoolskit-rules.instructions.md`
- PR and release communication:
  - `.github/instructions/pr.instructions.md`
  - `.github/instructions/feedback-changelog.instructions.md`
- Prompt and instruction authoring:
  - `.github/instructions/prompt-templates.instructions.md`
  - `.github/instructions/copilot-instruction-creation.instructions.md`

## Execution workflow

1. Identify artifact type (README, PR text, changelog, prompt, instruction).
2. Apply the required structure/template from instruction files.
3. Keep technical text in English and preserve repository language policy.
4. For changelog updates, enforce semantic version format and ISO date.
5. Validate links and cross-references before finishing.

## Prompt accelerators

- `.github/prompts/generate-pr-description.prompt.md`
- `.github/prompts/generate-changelog.prompt.md`