# VS Code Workspace Assets

> Versioned VS Code templates and snippets for shared Copilot/Codex workflows.

---

## Introduction

This folder stores repository-managed VS Code assets used to bootstrap local and global runtime configuration.

This path is the authoritative authored surface. The tracked `.vscode/` files are projected outputs rendered from here.

For `settings` and `mcp`, the repository uses `*.tamplate.jsonc` files to avoid forcing active workspace files (`settings.json`, `mcp.json`) into the repository.

For `.code-workspace`, the repository uses `base.code-workspace` as the shared inheritance baseline for workspace-level recommendations and top-level defaults.

For snippets, the repository uses `*.tamplate.code-snippets` files so they follow the same template-first versioning pattern used by `settings` and `mcp`. During sync, the `.tamplate` segment is removed before writing to the global VS Code profile.

For global VS Code settings, the repository uses `settings.tamplate.jsonc` as the versioned source of truth. The runtime sync renders `%USERPROFILE%` and writes the final `settings.json` into the global VS Code profile.

---

## Features

- ✅ Template-first settings via `settings.tamplate.jsonc`
- ✅ Canonical catalog-driven MCP config via `.github/governance/mcp-runtime.catalog.json`
- ✅ Base workspace pseudo-inheritance via `base.code-workspace`
- ✅ Template-first Copilot/Codex snippets under `snippets/`
- ✅ Rendered global VS Code settings sync via `scripts/runtime/sync-vscode-global-settings.ps1`
- ✅ Rendered global VS Code MCP sync via `scripts/runtime/sync-vscode-global-mcp.ps1`
- ✅ Validation integrated in `scripts/validation/validate-instructions.ps1`
- ✅ Versioned VS Code profile baselines under `.vscode/profiles/` with explicit selection support
- ✅ Local rendered MCP helper mirror under `.vscode/mcp-vscode-global.json`

---

## Contents

- [Introduction](#introduction)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Build and Tests](#build-and-tests)
- [Contributing](#contributing)
- [Dependencies](#dependencies)
- [References](#references)

---

## Installation

No installation is required beyond PowerShell 7+ and VS Code.

---

## Quick Start

Refresh the active workspace MCP file from the tracked template and then sync the global MCP profile:

```powershell
pwsh -File .\scripts\runtime\apply-vscode-templates.ps1
pwsh -File .\scripts\runtime\sync-vscode-global-mcp.ps1 -CreateBackup
```

---

## Usage Examples

### Example 1: Validate templates and references

```powershell
pwsh -File .\scripts\validation\validate-instructions.ps1
```

### Example 2: Inspect available snippets

```powershell
Get-ChildItem .\.vscode\snippets\*.tamplate.code-snippets
```

### Example 3: Apply active VS Code files from templates

```powershell
pwsh -File .\scripts\runtime\apply-vscode-templates.ps1 -Force
```

### Example 4: Synchronize canonical snippets into the global VS Code profile

```powershell
pwsh -File .\scripts\runtime\sync-vscode-global-snippets.ps1
```

### Example 5: Render the versioned settings template into the global VS Code profile

```powershell
pwsh -File .\scripts\runtime\sync-vscode-global-settings.ps1 -CreateBackup
```

### Example 6: Render the versioned MCP template into the global VS Code profile and refresh the local helper mirror

```powershell
pwsh -File .\scripts\runtime\sync-vscode-global-mcp.ps1 -CreateBackup
```

### Example 7: Generate a workspace from the shared base and settings baseline

```powershell
pwsh -File .\scripts\runtime\sync-workspace-settings.ps1 -WorkspacePath C:\Users\me\Projects\api.code-workspace -FolderPath src\Api
```

---

## API Reference

- `settings.tamplate.jsonc`: base VS Code/Copilot instruction-routing settings.
- `mcp.tamplate.jsonc`: generated VS Code MCP projection rendered from `.github/governance/mcp-runtime.catalog.json`, then used to render the global VS Code `mcp.json` profile and the local helper mirror.
- `base.code-workspace`: shared pseudo-inheritance source for `.code-workspace` files.
- `snippets/codex-cli.tamplate.code-snippets`: versioned Codex CLI snippet template synchronized into the global profile.
- `snippets/copilot.tamplate.code-snippets`: versioned Copilot chat/workflow snippet template synchronized into the global profile.
- `scripts/runtime/apply-vscode-templates.ps1`: applies templates into active `settings.json` and `mcp.json`.
- `scripts/runtime/sync-vscode-global-settings.ps1`: renders `settings.tamplate.jsonc` into the global VS Code user profile.
- `scripts/runtime/sync-vscode-global-mcp.ps1`: renders the canonical MCP runtime catalog into the global VS Code user profile and refreshes `.vscode/mcp-vscode-global.json`.
- `scripts/runtime/sync-vscode-global-snippets.ps1`: synchronizes canonical snippets into the global VS Code user profile.
- `scripts/runtime/sync-workspace-settings.ps1`: merges `base.code-workspace` with target workspaces and regenerates the approved workspace `settings` block.
- `.vscode/profiles/`: rendered repository surface projected from `definitions/providers/vscode/profiles/` and consumed by the runtime setup entrypoint in `scripts/runtime/`.
- `.vscode/profiles/README.md`: rendered operator guide for profile creation and profile-driven MCP enablement.
- `scripts/runtime/render-vscode-profile-surfaces.ps1`: renders the authoritative VS Code profile definitions into `.vscode/profiles/`.
- `scripts/runtime/render-vscode-mcp-template.ps1`: renders `.vscode/mcp.tamplate.jsonc` from the canonical MCP runtime catalog.

### VS Code profile baselines

The repository treats `definitions/providers/vscode/profiles/` as the authoritative baseline surface and renders `.vscode/profiles/` from it. Use the rendered `.vscode/profiles/` folder for discovery and docs, but edit the definitions tree when profile content changes.

Profiles can also drive MCP enable/disable selection for the global VS Code
runtime through the `mcp.servers.<name>.enabled` map consumed by
`scripts/runtime/setup-vscode-profiles.ps1`.

Examples:

```powershell
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -ListProfiles
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -DryRun -ProfileName Base,Frontend
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -ProfileName "Backend .NET"
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -ProfileName Frontend -CreateMcpBackup
```

### Local helper assets

The repository treats this path as a generated local helper, not as an input source-of-truth:

- `.vscode/mcp-vscode-global.json`

This surface is ignored by Git and is regenerated from the canonical MCP runtime catalog by:

- `scripts/runtime/sync-vscode-global-mcp.ps1`
- `scripts/runtime/install.ps1`

Use the tracked files below as the only authoritative VS Code runtime inputs:

- `definitions/providers/vscode/workspace/settings.tamplate.jsonc`
- `.github/governance/mcp-runtime.catalog.json`
- `.vscode/mcp.tamplate.jsonc`
- `definitions/providers/vscode/workspace/base.code-workspace`
- `definitions/providers/vscode/workspace/snippets/*.tamplate.code-snippets`
- `definitions/providers/vscode/profiles/`
- `scripts/runtime/setup-vscode-profiles.ps1`

### MCP authentication persistence

When the global `mcp.json` uses `${input:...}` placeholders, VS Code prompts once per input id and then stores the answer securely for reuse. Keep auth inputs stable and scoped per server so repeated chat conversations do not force unnecessary reauthentication.

Examples in this repository:

- GitHub MCP: `${input:Authorization}`
- Postman MCP: `${input:PostmanAuthorization}`
- SonarQube MCP: `${input:SONARQUBE_TOKEN}`


---

## Build and Tests

```powershell
pwsh -File .\scripts\validation\validate-instructions.ps1
```

---

## Contributing

- Keep template files valid JSON/JSONC.
- Do not commit active `settings.json` or `mcp.json`.
- When VS Code MCP servers change, update `.github/governance/mcp-runtime.catalog.json` first, then regenerate the tracked runtime projections with `scripts/runtime/render-mcp-runtime-artifacts.ps1`.
- Apply templates locally when needed with `scripts/runtime/apply-vscode-templates.ps1`.
- Sync the global VS Code settings from `settings.tamplate.jsonc` with `scripts/runtime/sync-vscode-global-settings.ps1`.
- Sync the global VS Code MCP profile from the canonical MCP runtime catalog with `scripts/runtime/sync-vscode-global-mcp.ps1`.
- Treat `definitions/providers/vscode/workspace/base.code-workspace` as the shared workspace inheritance baseline and re-render `.vscode/base.code-workspace` after edits.
- Treat `definitions/providers/vscode/workspace/snippets/*.tamplate.code-snippets` as the versioned snippet source and re-render `.vscode/snippets/` after edits.
- Keep `.vscode/profiles/` versioned and internally consistent with the checked-in `profile-*.json` set.
- Keep executable entrypoints under `scripts/`; `.vscode/profiles/` stores versioned profile definitions only.
- Keep `.vscode/mcp-vscode-global.json` ignored and generated; do not hand-edit it.
- Re-render the tracked `.vscode/` workspace surface with `scripts/runtime/render-vscode-workspace-surfaces.ps1 -RepoRoot .` after changing this authored tree.

---

## Dependencies

- Runtime: PowerShell 7+.
- Tools: VS Code, GitHub Copilot extension, optional MCP server runtimes (`npx`, etc.).

---

## References

- `.github/governance/mcp-runtime.catalog.json`
- `.codex/mcp/servers.manifest.json`
- `scripts/runtime/render-vscode-mcp-template.ps1`
- `scripts/runtime/sync-codex-mcp-config.ps1`
- `definitions/providers/vscode/workspace/base.code-workspace`
- `scripts/runtime/render-vscode-workspace-surfaces.ps1`
- `scripts/runtime/apply-vscode-templates.ps1`
- `scripts/runtime/sync-vscode-global-settings.ps1`
- `scripts/runtime/sync-vscode-global-mcp.ps1`
- `scripts/runtime/sync-vscode-global-snippets.ps1`
- `scripts/runtime/sync-workspace-settings.ps1`
- `scripts/validation/validate-instructions.ps1`