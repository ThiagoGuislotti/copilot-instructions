# GitHub Provider Definitions

This tree is the authoritative source for repository-owned GitHub/Copilot
provider-specific runtime surfaces that are rendered into `.github/`.

## Authoritative Coverage

- `root/` -> managed root files rendered into `.github/`
- `agents/` -> rendered into `.github/agents/`
- `chatmodes/` -> rendered into `.github/chatmodes/`
- `prompts/` -> provider-specific `*.prompt.md` entrypoints rendered into `.github/prompts/`
- `hooks/` -> rendered into `.github/hooks/`

## Projection Rules

- Edit these files here when changing GitHub/Copilot provider-specific runtime
  behavior.
- Shared instructions and reusable templates are authored under
  `definitions/shared/`, not here.
- Shared POML prompt assets are authored under `definitions/shared/prompts/poml/`,
  not under this provider tree.
- GitHub-native repository/community assets stay authored directly in `.github/`
  and are not projected from this provider tree:
  - `.github/PULL_REQUEST_TEMPLATE.md`
  - `.github/ISSUE_TEMPLATE/**`
  - `.github/dependabot.yml`
  - `.github/dependency-review-config.yml`
- Regenerate the projected repo surface with:

```powershell
pwsh -File .\scripts\runtime\render-github-instruction-surfaces.ps1 -RepoRoot .
```

- `.github/` still keeps GitHub-native governance assets such as workflows,
  policies, schemas, runbooks, governance catalogs, issue templates, PR
  templates, and dependency automation config authored in place. Only the
  provider-authored surfaces above are projected from
  `definitions/providers/github/`.