---
applyTo: "[TARGET_GLOB]"
priority: [medium|high]
---

# [Instruction Title]

Purpose: [Describe the instruction purpose, when it applies, and what it governs].

## Scope
- Applies to `[target paths or file types]`.
- Use together with `[related instructions or templates]` when applicable.
- Do not repeat global rules already defined in `copilot-instructions.md`.

## Rules
- [Rule 1 with clear action and expected outcome]
- [Rule 2 with constraints or guardrails]
- [Rule 3 with naming, formatting, or structural guidance]
- Example: `[command, file pattern, or implementation pattern]`

## Structure
- Required sections: `[section list when applicable]`
- Required formatting: `[headings, code fences, tables, or naming expectations]`
- Required references: `[files, scripts, or templates that must be updated together]`

## Validation Checklist
- [ ] Metadata and `applyTo` scope match the real target files
- [ ] Cross-references to `copilot-instructions.md`, README, or related files were updated when required
- [ ] Conflicts with existing instruction files were reviewed and resolved
- [ ] Examples, commands, and file references are valid for this repository