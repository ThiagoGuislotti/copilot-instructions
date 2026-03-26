# MCP Shared Config

> Generated Codex MCP subset and documentation for the shared canonical MCP runtime catalog.

---

## Introduction

This folder contains the generated Codex MCP subset and helper templates derived from the canonical runtime catalog under `.github/governance/mcp-runtime.catalog.json`. The render/apply scripts keep Codex and VS Code MCP setups aligned without making the Codex subset the primary source of truth.

---

## Features

- ✅ Canonical source of truth (`.github/governance/mcp-runtime.catalog.json`)
- ✅ Automated output for Codex TOML sections
- ✅ Automated output for VS Code MCP template (`mcp.tamplate.jsonc`)

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
- [Security](#security)

---

## Installation

No package installation is required. Edit the canonical catalog and run scripts from `.codex/scripts/` or `scripts/runtime/`.

---

## Quick Start

```powershell
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.vscode\mcp.tamplate.jsonc
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -CreateBackup
```

---

## Usage Examples

### Example 1: Generate VS Code MCP File

```powershell
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 `
  -OutputPath .\.vscode\mcp.tamplate.jsonc
```

### Example 2: Update Local Codex MCP Servers

```powershell
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 `
  -TargetConfigPath "$env:USERPROFILE\.codex\config.toml" `
  -CreateBackup
```

---

## API Reference

### Main Files

- `.github/governance/mcp-runtime.catalog.json`: source of truth for runtime server definitions.
- `servers.manifest.json`: generated Codex subset used for Codex TOML sync.
- `codex.config.template.toml`: reference template for local Codex config.
- `vscode.mcp.template.json`: reference template for VS Code MCP config.

### Manifest Shape

```json
{
  "version": 1,
  "servers": [
    {
      "name": "playwright",
      "type": "stdio",
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  ]
}
```

---

## Build and Tests

```powershell
# render output in temp for verification
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.temp\vscode.mcp.generated.json

# preview codex config output without writing
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -DryRun
```

---

## Contributing

- Add or update servers only in `.github/governance/mcp-runtime.catalog.json`.
- Keep backward-compatible field names unless migration is documented.
- Regenerate both runtime projections after catalog changes with `pwsh -File scripts/runtime/render-mcp-runtime-artifacts.ps1`.
- Validate both render/apply scripts after catalog changes.

---

## Dependencies

- Runtime: PowerShell 7+.
- Tooling examples: `npx` for stdio MCP servers.

---

## References

- `.codex/scripts/sync-mcp-to-codex-config.ps1`
- `.codex/scripts/render-vscode-mcp.ps1`
- `.codex/mcp/codex.config.template.toml`
- `.codex/mcp/vscode.mcp.template.json`

---

## Security

- Keep secrets out of `.github/governance/mcp-runtime.catalog.json`.
- For authenticated providers, prefer environment variables or runtime prompts.