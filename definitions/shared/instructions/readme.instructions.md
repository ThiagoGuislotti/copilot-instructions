---
applyTo: "**/README.md"
priority: medium
---

# README Baseline
Use `.github/templates/readme-template.md` as the default starting point.
This file defines the generic README baseline only.
If a higher-priority repository-specific README instruction exists, that file may narrow or override section set, order, and examples policy.
Do not assemble a README directly from this instruction file; use the template for concrete structure and placeholders.

# README Types

## Repository README
Focus on repository overview, navigation, build/test entry points, contribution guidance, dependencies, and references.
Do not force package-installation sections into the root README when repository-specific rules say otherwise.

## Package or App README
Prefer these sections when they are applicable:
Introduction, Table of Contents or Contents, Installation, Quick Start, Usage Examples, API Reference, Build and Tests, Contributing, Dependencies, References.
If a section does not apply, remove it instead of filling it with weak placeholder text.

# Content Expectations
- Introduction explains problem, context, and technical approach.
- Features section, when present, uses checkmark bullets.
- Table of Contents or Contents links the main sections that actually exist in the file.
- When stable subsections exist under a section, `Contents` must include nested anchor links for those subsection entries in the same order.
- The default README template must keep nested `Contents` items for `Usage Examples` and `API Reference` subsections unless those subsections are intentionally removed from the document.
- Installation shows real setup commands and package references.
- Quick Start stays minimal and runnable.
- Usage Examples cover typical and advanced scenarios with real code.
- API Reference uses real signatures, parameters, and returns.
- Build and Tests shows real repository commands when the README type requires operational guidance.
- References link to changelog, related packages, docs, issues, or external technical material.

# Format
- Keep README content concise, practical, and directly actionable.
- Use fenced code blocks with correct language tags.
- Use section separators (`---`) when they improve readability and match repository style.
- Prefer real examples over invented APIs or placeholder prose.
- Keep concrete placeholders, subsection anchors, and example scaffolding in `.github/templates/readme-template.md` instead of duplicating them here.