---
name: core-runtime-sync
description: Sync shared repo assets into local ~/.github and ~/.codex, and apply MCP settings from the shared canonical runtime catalog.
---

# Codex Runtime Sync

Use this skill to keep local runtime folders aligned with the versioned repository structure.

## Load minimal context first

1. Load `.github/AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/repository-operating-model.instructions.md`.
2. Use the repository operating model as the canonical source for runtime projection responsibilities.

This includes syncing the complete versioned `.github/` asset set (instructions, routing catalog, prompts, chatmodes, schemas, templates) into `~/.github`.
It also composes `~/.codex/shared-scripts` from:
- `.codex/scripts/` (MCP utility scripts)
- `scripts/common/` (shared helpers)
- `scripts/security/` (shared security gates)

## Sync Shared Assets

```powershell
pwsh -File scripts/runtime/bootstrap.ps1
```

## Apply MCP Servers To Codex

```powershell
pwsh -File .codex/scripts/sync-mcp-to-codex-config.ps1 -CreateBackup
```

## Render VS Code MCP From The Canonical Runtime Catalog

```powershell
pwsh -File .codex/scripts/render-vscode-mcp.ps1 -OutputPath .vscode/mcp.tamplate.jsonc
```

## Source Of Truth

- `.github/governance/mcp-runtime.catalog.json`
- `.codex/mcp/servers.manifest.json` (generated Codex subset)
- `.codex/scripts/*` (MCP utilities)
- `scripts/common/*` (runtime shared helpers)
- `scripts/security/*` (runtime shared security scripts)