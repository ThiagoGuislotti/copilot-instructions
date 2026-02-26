# Codex Shared Assets

> Versioned Codex configuration assets for team-wide reuse.

---

## Introduction

This folder centralizes shared Codex assets to keep local runtime setup reproducible across contributors. The approach is to version only reusable config and automation, while keeping credentials and runtime state local.

---

## Features

- ✅ Shared skills stored as source (`skills/*/SKILL.md`)
- ✅ Single MCP source of truth (`mcp/servers.manifest.json`)
- ✅ Reusable scripts to apply config into local runtime
- ✅ Versioned multi-agent orchestration contracts and templates

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

Sync shared assets into local runtime with root bootstrap:

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1
```

---

## Quick Start

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -ApplyMcpConfig -BackupConfig
```

---

## Usage Examples

### Example 1: Sync Shared Assets

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1
```

### Example 2: Apply MCP Servers To Local Codex Config

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -ApplyMcpConfig -BackupConfig
```

---

## API Reference

### Main Folders

- `skills/`: reusable skills for routing and runtime sync.
- `mcp/`: manifest and templates for Codex/VS Code MCP configuration.
- `scripts/`: scripts that render/apply MCP config from the shared manifest.
- `orchestration/`: agent contracts, pipeline manifests, run templates, and eval fixtures.

### Current Skills

- `repo-context-router`
- `codex-runtime-sync`

---

## Build and Tests

```powershell
# render VS Code MCP output from manifest
pwsh -File .\.codex\scripts\render-vscode-mcp.ps1 -OutputPath .\.temp\vscode.mcp.generated.json

# preview MCP changes to local config without writing
pwsh -File .\.codex\scripts\sync-mcp-to-codex-config.ps1 -DryRun

# validate orchestration contracts and templates
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1
```

---

## Contributing

- Keep paths and naming aligned with existing repo conventions.
- Avoid duplicating rules already defined in `.github/*`.
- Add/update `SKILL.md` when introducing new shared skills.

---

## Dependencies

- Runtime: PowerShell 7+, `robocopy` (Windows).
- Development: Git and access to this repository.

---

## References

- `.codex/mcp/servers.manifest.json`
- `.codex/scripts/sync-mcp-to-codex-config.ps1`
- `.codex/scripts/render-vscode-mcp.ps1`
- `.codex/skills/README.md`
- `.codex/orchestration/README.md`

---

## Security

Do not store credentials or runtime artifacts here (for example: auth tokens, session logs, caches).