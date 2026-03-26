# MCP Shared Config

> Generated Codex MCP subset and projected support documentation for the shared canonical MCP runtime catalog.

---

## Introduction

This projected surface contains the generated Codex MCP subset and helper
templates derived from the canonical runtime catalog under
`.github/governance/mcp-runtime.catalog.json`.

The authoritative copies for the support files in this folder live under
`definitions/providers/codex/mcp/`. The generated `servers.manifest.json`
remains owned by the canonical catalog renderer. The render/apply scripts keep
Codex and VS Code MCP setups aligned without making the Codex subset the
primary source of truth.

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

No package installation is required. Edit the canonical catalog and run the canonical scripts from `scripts/runtime/`. The `.codex/scripts/` files remain compatibility wrappers only.

---

## Quick Start

```powershell
pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 -OutputPath .\.vscode\mcp.tamplate.jsonc
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -CreateBackup
```

---

## Usage Examples

### Example 1: Generate VS Code MCP File

```powershell
pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 `
  -OutputPath .\.vscode\mcp.tamplate.jsonc
```

### Example 2: Update Local Codex MCP Servers

```powershell
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 `
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
pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 -OutputPath .\.temp\vscode.mcp.generated.json

# preview codex config output without writing
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -DryRun
```

---

## Contributing

- Add or update servers only in `.github/governance/mcp-runtime.catalog.json`.
- Keep backward-compatible field names unless migration is documented.
- Edit support docs/templates in `definitions/providers/codex/mcp/`, not in the
  projected `.codex/mcp/` copies.
- Regenerate both runtime projections after catalog changes with `pwsh -File scripts/runtime/render-mcp-runtime-artifacts.ps1`.
- Validate both render/apply scripts after catalog changes.

---

## Dependencies

- Runtime: PowerShell 7+.
- Tooling examples: `npx` for stdio MCP servers.

---

## References

- `scripts/runtime/sync-codex-mcp-config.ps1`
- `scripts/runtime/render-vscode-mcp-template.ps1`
- `.codex/mcp/codex.config.template.toml`
- `.codex/mcp/vscode.mcp.template.json`

---

## Security

- Keep secrets out of `.github/governance/mcp-runtime.catalog.json`.
- For authenticated providers, prefer environment variables or runtime prompts.