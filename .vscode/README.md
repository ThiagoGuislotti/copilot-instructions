# VS Code Workspace Assets

> Versioned VS Code templates and snippets for shared Copilot/Codex workflows.

---

## Introduction

This folder stores repository-managed VS Code assets in template form to avoid forcing active workspace files (`settings.json`, `mcp.json`) into the repository. The templates are the source used to bootstrap local runtime configuration.

---

## Features

- ✅ Template-first settings via `settings.tamplate.jsonc`
- ✅ Template-first MCP config via `mcp.tamplate.jsonc`
- ✅ Reusable Copilot/Codex snippets under `snippets/`
- ✅ Validation integrated in `scripts/validation/validate-instructions.ps1`

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

Regenerate MCP template from the shared manifest:

```powershell
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.vscode\mcp.tamplate.jsonc
pwsh -File .\scripts\runtime\apply-vscode-templates.ps1
```

---

## Usage Examples

### Example 1: Validate templates and references

```powershell
pwsh -File .\scripts\validation\validate-instructions.ps1
```

### Example 2: Inspect available snippets

```powershell
Get-ChildItem .\.vscode\snippets\*.code-snippets
```

### Example 3: Apply active VS Code files from templates

```powershell
pwsh -File .\scripts\runtime\apply-vscode-templates.ps1 -Force
```

---

## API Reference

- `settings.tamplate.jsonc`: base VS Code/Copilot instruction-routing settings.
- `mcp.tamplate.jsonc`: base VS Code MCP servers map derived from `.codex/mcp/servers.manifest.json`.
- `snippets/codex-cli.code-snippets`: Codex CLI prompt/snippet catalog.
- `snippets/copilot.code-snippets`: Copilot chat and workflow snippets.
- `scripts/runtime/apply-vscode-templates.ps1`: applies templates into active `settings.json` and `mcp.json`.

---

## Build and Tests

```powershell
pwsh -File .\scripts\validation\validate-instructions.ps1
```

---

## Contributing

- Keep template files valid JSON/JSONC.
- Do not commit active `settings.json` or `mcp.json`.
- When MCP servers change, regenerate `mcp.tamplate.jsonc` from manifest.
- Apply templates locally when needed with `scripts/runtime/apply-vscode-templates.ps1`.

---

## Dependencies

- Runtime: PowerShell 7+.
- Tools: VS Code, GitHub Copilot extension, optional MCP server runtimes (`npx`, etc.).

---

## References

- `.codex/mcp/servers.manifest.json`
- `.codex/scripts/render-vscode-mcp.ps1`
- `scripts/runtime/apply-vscode-templates.ps1`
- `scripts/validation/validate-instructions.ps1`
