# Codex Scripts

> Scripts to render and apply shared MCP configuration in local environments.

---

## Introduction

These scripts consume `.codex/mcp/servers.manifest.json` and generate/apply target configuration files for Codex and VS Code.

---

## Features

- ✅ Render VS Code MCP template (`mcp.tamplate.jsonc`) from manifest
- ✅ Apply MCP servers into local `~/.codex/config.toml`
- ✅ Preserve non-MCP sections in local Codex config

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

No additional installation is required beyond PowerShell.

---

## Quick Start

```powershell
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -CreateBackup
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.vscode\mcp.tamplate.jsonc
```

---

## Usage Examples

### Example 1: Preview Codex MCP Changes

```powershell
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -DryRun
```

### Example 2: Apply MCP Config With Backup

```powershell
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 `
  -TargetConfigPath "$env:USERPROFILE\.codex\config.toml" `
  -CreateBackup
```

### Example 3: Render VS Code MCP Output

```powershell
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 `
  -OutputPath .\.vscode\mcp.tamplate.jsonc
```

---

## API Reference

### Scripts

`sync-mcp-to-codex-config.ps1`
- Inputs: manifest path, target config path, backup/dry-run flags.
- Behavior: rewrites only `[mcp_servers.*]` sections in TOML.

`render-vscode-mcp.ps1`
- Inputs: manifest path, output path.
- Behavior: generates `{"servers": {...}}` JSON for VS Code MCP.

---

## Build and Tests

```powershell
# validate VS Code render
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.temp\vscode.mcp.generated.json

# validate codex apply logic without writing
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -DryRun
```

---

## Contributing

- Keep script behavior deterministic and idempotent.
- Preserve local user configuration outside MCP sections.
- Update `.codex/mcp/README.md` when script behavior changes.

---

## Dependencies

- Runtime: PowerShell 7+.
- Optional tooling from manifest server definitions (for example `npx`).

---

## References

- `.codex/mcp/servers.manifest.json`
- `.codex/mcp/README.md`