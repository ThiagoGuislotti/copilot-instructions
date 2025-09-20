---
applyTo: "**/{CHANGELOG,changelog,feedback,issue}*"
---

# Feedback Integration
Use changelog-entry-template.md with feedback integration section; document issue + context + problem + solution in CHANGELOG format; semantic versioning with date; consolidate feedback tracking in version history.

# CHANGELOG Format
- Format [version] YYYY-MM-DD
- Changed (existing modifications)
- Added (new rules)
- Fixed (corrections)
- Removed (discontinued)
- Breaking (compatibility break)
- Use changelog-entry-template.md template
```markdown
## [2.0.1] - 2025-09-03

### Fixed
- .github/instructions/frontend.instructions.md handleApiError(): automatic retry added
- LoadingButton: improved loading state

### Feedback Integration
- Issue context: GitHub issue #123
- Problem identified: Copilot missing retry pattern
- Solution applied: exponential backoff retry
- Workspace impact: 15 of 59 NetToolsKit projects
```

# Workflow
Issue identification → modify instruction pattern → document CHANGELOG → git tag copilot-vX.Y.Z.

# GitHub Issues
Optional for complex discussions; prefer direct CHANGELOG documentation for instruction improvements; use standard GitHub issue templates when needed.

# Semantic Versioning
- Major (restructuring/breaking)
- Minor (new instructions)
- Patch (corrections/adjustments)

# Communication
Breaking changes in README.md with migration instructions; discontinuation timeline.

# Mandatory Formatting
NEVER leave empty lines at end of CHANGELOG files; remove trailing newlines; end with content on last line; check all related files.

# Feedback Tracking Format
File | context | problem | solution | workspace-impact within CHANGELOG entries.