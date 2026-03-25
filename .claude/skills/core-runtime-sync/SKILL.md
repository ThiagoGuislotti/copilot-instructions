---
name: core-runtime-sync
description: Sync shared repo assets into local ~/.github, ~/.codex, and ~/.claude, and apply MCP settings from the shared canonical runtime catalog. Use when runtime assets are stale or after onboarding a new machine.
---

# Runtime Sync

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent.

## Sync shared assets (all runtimes)

```powershell
pwsh -File scripts/runtime/install.ps1 -RuntimeProfile all -ApplyMcpConfig -BackupMcpConfig -CreateSettingsBackup
```

## Sync individual runtime surfaces

```powershell
# GitHub/Copilot only
pwsh -File scripts/runtime/install.ps1 -RuntimeProfile github

# Codex only
pwsh -File scripts/runtime/install.ps1 -RuntimeProfile codex -ApplyMcpConfig -BackupMcpConfig

# Claude Code only
pwsh -File scripts/runtime/install.ps1 -RuntimeProfile claude
```

## Apply MCP servers to Codex

```powershell
pwsh -File .codex/scripts/sync-mcp-to-codex-config.ps1 -CreateBackup
```

## Render VS Code MCP from the canonical runtime catalog

```powershell
pwsh -File .codex/scripts/render-vscode-mcp.ps1 -OutputPath .vscode/mcp.tamplate.jsonc
```

## Source of truth

- `.github/governance/mcp-runtime.catalog.json` — canonical MCP runtime catalog
- `.codex/mcp/servers.manifest.json` — generated Codex subset
- `.github/governance/runtime-location-catalog.json` — runtime path catalog
- `scripts/common/runtime-paths.ps1` — effective path resolution