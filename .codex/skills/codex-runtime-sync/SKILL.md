---
name: codex-runtime-sync
description: Sync shared repo assets into local ~/.github and ~/.codex, and apply MCP settings from the shared manifest.
---

# Codex Runtime Sync

Use this skill to keep local runtime folders aligned with the versioned repository structure.

This includes syncing the complete versioned `.github/` asset set (instructions, routing catalog, prompts, chatmodes, schemas, templates) into `~/.github`.

## Sync Shared Assets

```powershell
pwsh -File scripts/runtime/bootstrap.ps1
```

## Apply MCP Servers To Codex

```powershell
pwsh -File .codex/scripts/sync-mcp-to-codex-config.ps1 -CreateBackup
```

## Render VS Code MCP From Same Manifest

```powershell
pwsh -File .codex/scripts/render-vscode-mcp.ps1 -OutputPath .vscode/mcp.json
```

## Source Of Truth

- `.codex/mcp/servers.manifest.json`