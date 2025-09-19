---
applyTo: "**/{CHANGELOG,changelog,feedback,issue}*"
---

Feedback: use changelog-entry-template.md with feedback integration section; document issue + context + problem + solution in CHANGELOG format; semantic versioning with date; consolidate feedback tracking in version history.
CHANGELOG: format [version] YYYY-MM-DD; Changed (existing modifications); Added (new rules); Fixed (corrections); Removed (discontinued); Breaking (compatibility break); use changelog-entry-template.md template.
Workflow: Issue identification → modify instruction pattern → document CHANGELOG → git tag copilot-vX.Y.Z.
GitHub Issues: optional for complex discussions; prefer direct CHANGELOG documentation for instruction improvements; use standard GitHub issue templates when needed.
Semantic versioning: Major (restructuring/breaking); Minor (new instructions); Patch (corrections/adjustments).
Communication: breaking changes in README.md with migration instructions; discontinuation timeline.
Mandatory formatting: NEVER leave empty lines at end of CHANGELOG files; remove trailing newlines; end with content on last line; check all related files.
Example CHANGELOG entry with feedback: [2.0.1] 2025-09-03 ## Fixed .github/instructions/frontend.instructions.md handleApiError(): automatic retry added; LoadingButton: improved loading state ## Feedback Integration Issue context: GitHub issue #123; Problem identified: Copilot missing retry pattern; Solution applied: exponential backoff retry; Workspace impact: 15 of 59 NetToolsKit projects.
Feedback tracking format: file | context | problem | solution | workspace-impact within CHANGELOG entries.