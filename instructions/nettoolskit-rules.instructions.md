---
applyTo: "**/README.md"
---

# Temporary README Rules (Reference)

Purpose: keep a consistent documentation pattern across the root README and each package README while preparing packages for NuGet. This guide is temporary and complements existing rules in .github/instructions/readme.instructions.md.

## Language
- All READMEs must be written in English.
- Code comments inside examples must be English too.

## Root README (repository)
- Keep ONLY these sections, in this order:
  - Introduction
  - Features
  - Contents
  - Build and Tests
  - Contributing
  - Dependencies
  - References
  - License
- Do NOT include code examples in the root README.
- Root README must NOT include Installation, Quick Start, Usage Examples, or API Reference sections; link to package READMEs under References instead.
- Mandatory: every package README under src/* must be referenced in the References section of the root README.

## Package READMEs (src/*)
- Keep ONLY these sections, in this order:
  - Introduction
  - Features
  - Contents
  - Installation
  - Quick Start (short 3–5 lines when meaningful)
  - Usage Examples (typical + advanced)
    - Must be organized into subsections (e.g., 1., 2., 3.) with descriptive titles
  - API Reference (real signatures)
    - Group by logical areas with subsections (e.g., Interpreters, Extensions, Enums/Models)
    - When the public API exposes enums, add a subsection per enum with a Markdown table listing all values and concise descriptions
    - When examples introduce structured payloads (request/response schemas), add a small "Data Shapes" table with Field, Description, and Example columns
  - References
  - License
- Remove and avoid: Build and Tests, Contributing, Dependencies.

## Examples Coverage Rule (≥ 70%)
- Each package README must include examples that cover at least 70% of the key public APIs/features intended for user consumption.
- Recommended measurement to validate coverage:
  - Identify “key APIs/features” listed in the API Reference (e.g., main extension methods, core classes, primary options).
  - Provide at least one example for each API/feature until the proportion of covered items reaches ≥ 70%.
  - Prefer runnable, minimal, and focused examples; avoid stubs of non-existent APIs.
- If coverage < 70%, add concise examples until the threshold is met or exceeded.

## API Reference
- Use real names and signatures from the codebase (no fictitious APIs).
- Keep concise: signatures + brief param/return notes when needed.

## Formatting & Style
- Consistent headings and section order across packages.
- Include a Contents section listing all sections above in the exact order. Every listed section must exist, and every section must be listed.
- When a README includes subsections under Usage Examples and API Reference, include those subsections as nested items under Contents for easier navigation.
- Prefer Markdown tables for:
  - Enums (columns: Value, Description; use code formatting for literal values)
  - Data shapes (columns: Field, Description, Example)
- Use fenced code blocks with correct language tags (csharp, xml, bash).
- Prefer concise examples that compile; keep comments short and instructive.
- Include useful external links (e.g., Microsoft Docs) in References.
 - Features section MUST use emoji checkmarks for each bullet: "-   ✅ ..." (three spaces after dash to align with repo style).
 - Package README section headings MUST use level-2 headings (##) for all top-level sections (Introduction, Features, Contents, Installation, Quick Start, Usage Examples, API Reference, References, License).
 - Insert a horizontal rule ("---") between major sections to match the repo house style (especially before Contents, Installation, Quick Start, Usage Examples, API Reference, References, and after License).
 - License section format is STRICT:
   - Heading: "## License"
   - Body: "This project is licensed under the MIT License. See the LICENSE file at the repository root for details."
   - Followed by a horizontal rule line "---".

## Guardrails
- Do not change or invent library logic; documentation updates only.
- Ensure examples align with the current source code and namespaces.
- Root README must not contain build/test/lint steps; keep those out of package READMEs as well.

## Verification Checklist
- [ ] English-only content (text and comments)
- [ ] Sections match the allowed set for root/package
- [ ] Contents section includes all sections (and order matches); no Installation/Quick Start/Usage Examples/API Reference in root
- [ ] No code in root README examples; links only
- [ ] Root References lists all package READMEs under src/*
- [ ] Package README examples cover ≥ 70% of key APIs/features
- [ ] API Reference uses real signatures
- [ ] Enums (when applicable) documented with a Value/Description table and linked in Contents
- [ ] Key payload schemas (when applicable) documented with Field/Description/Example table near the example or in a Data Shapes subsection
- [ ] References contain helpful links (docs/issues)
 - [ ] Features bullets use ✅ prefix
 - [ ] Top-level section headings use ## (not #)
 - [ ] Horizontal rules (---) present between sections and after License
 - [ ] License section matches the exact template (heading, sentence, separator)