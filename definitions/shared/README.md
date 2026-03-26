# Shared Definitions

`definitions/shared/` holds repository-owned authoritative assets reused across
more than one provider/runtime surface.

## Coverage

- `instructions/` -> projected into `.github/instructions/` and consumed by the
  repository runtime/validation stack as the canonical instruction set
- `prompts/poml/` -> projected into `.github/prompts/poml/` as the shared POML
  prompt library used by GitHub/Copilot prompt surfaces
- `templates/` -> projected into `.github/templates/` and reused by runtime
  helpers, validation, and authoring flows

## Rules

- Keep reusable authored content here when it is not specific to one provider.
- Do not duplicate the same instruction/template under provider folders.
- Provider folders should only own provider-specific runtime surfaces.
- GitHub-native repository/community assets such as `.github/ISSUE_TEMPLATE/`,
  `.github/PULL_REQUEST_TEMPLATE.md`, `.github/dependabot.yml`, and
  `.github/dependency-review-config.yml` stay authored directly in `.github/`.

Render projected surfaces with:

```powershell
pwsh -File .\scripts\runtime\render-github-instruction-surfaces.ps1 -RepoRoot .
```