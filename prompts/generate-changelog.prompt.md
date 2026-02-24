---
description: Generate CHANGELOG entries following repository conventions
mode: ask
tools: ['codebase', 'search', 'findFiles']
---

# CHANGELOG Entry Generator
Generate a CHANGELOG entry following the repository's established pattern.

## Instructions
Based on the provided changes or current git diff, create a CHANGELOG entry that:
1. Analyze recent repository changes (files modified, additions, removals)
2. Categorize changes using standard semantic versioning categories
3. Follow the pattern established in existing CHANGELOG entries
4. Use concise, technical language appropriate for developers
5. Reference specific files with backticks when relevant
6. Group related changes logically
7. Maintain consistency with repository writing style

Use these references:
- [changelog-entry-template.md](../.github/templates/changelog-entry-template.md)
- Existing CHANGELOG.md entries for pattern matching
- Repository commit history and file changes

## Input Variables
- `${input:version:Next version (e.g., 1.0.4)}` - Version number
- `${input:changes:Recent changes to document}` - Description of changes made

## Expected Output Format
```markdown
## [${version}] - YYYY-MM-DD

### Added
- [New items with descriptions]

### Changed
- [Modified items with specific file references]

### Fixed
- [Bug fixes and corrections]
```

## Context to Consider
- Review recent git changes
- Check existing CHANGELOG entries for pattern consistency
- Group related changes under appropriate categories
- Ensure technical accuracy and completeness