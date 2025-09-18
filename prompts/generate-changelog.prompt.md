---
description: Generate CHANGELOG entries following repository conventions
mode: ask
tools: ['codebase', 'search', 'findFiles']
---

# CHANGELOG Entry Generator

Generate a CHANGELOG entry following the repository's established pattern.

## Instructions

Based on the provided changes or current git diff, create a CHANGELOG entry that:

1. **Follows the template**: Use [changelog-entry-template.md](../templates/changelog-entry-template.md)
2. **Maintains consistency**: Match the style of existing entries in [CHANGELOG.md](../CHANGELOG.md)
3. **Groups logically**: Organize changes by type (Added, Changed, Fixed, Removed)
4. **Uses proper formatting**:
   - File names in backticks
   - Em dashes (—) for specific file descriptions
   - Technical, concise language
   - Past tense descriptions

## Input Variables
- `${input:version:Next version (e.g., 1.0.4)}` - Version number
- `${input:changes:Describe the changes made}` - Change description

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