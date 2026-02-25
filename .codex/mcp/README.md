# MCP Shared Config

> Shared MCP configuration source for Codex and VS Code.

---

## Introduction

This folder defines MCP servers in a single manifest and uses scripts to render/apply target-specific configuration files. It prevents drift between Codex and VS Code MCP setups.

---

## Features

- ✅ Single source of truth (`servers.manifest.json`)
- ✅ Automated output for Codex TOML sections
- ✅ Automated output for VS Code `mcp.json`

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

No package installation is required. Edit the manifest and run scripts from `.codex/scripts/`.

---

## Quick Start

```powershell
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.vscode\mcp.json
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -CreateBackup
```

---

## Usage Examples

### Example 1: Generate VS Code MCP File

```powershell
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 `
  -OutputPath .\.vscode\mcp.json
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

- `servers.manifest.json`: source of truth for server definitions.
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

- Add servers only in `servers.manifest.json`.
- Keep backward-compatible field names unless migration is documented.
- Validate both render/apply scripts after manifest changes.

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

- Keep secrets out of `servers.manifest.json`.
- For authenticated providers, prefer environment variables or runtime prompts.