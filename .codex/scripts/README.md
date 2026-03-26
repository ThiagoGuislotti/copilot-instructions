# Codex Scripts

> Codex MCP utility scripts and runtime-shared script composition notes.

---

## Introduction

This folder contains compatibility wrappers for MCP utility scripts.
The authoritative source for this projected surface is
`definitions/providers/codex/scripts/`.

`scripts/runtime/bootstrap.ps1` composes `~/.codex/shared-scripts` from:
- `.codex/scripts/` (this folder, wrappers only)
- `scripts/common/`
- `scripts/security/`
- `scripts/maintenance/`

---

## Features

- ✅ Render VS Code MCP template (`mcp.tamplate.jsonc`) from the canonical runtime catalog
- ✅ Apply MCP servers into local `~/.codex/config.toml`
- ✅ Preserve non-MCP sections in local Codex config
- ✅ Shared security vulnerability gates synced from `scripts/security/`

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
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -CreateBackup
pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 -OutputPath .\.vscode\mcp.tamplate.jsonc
pwsh -File .\scripts\runtime\bootstrap.ps1
```

---

## Usage Examples

### Example 1: Preview Codex MCP Changes

```powershell
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -DryRun
```

### Example 2: Apply MCP Config With Backup

```powershell
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 `
  -TargetConfigPath "$env:USERPROFILE\.codex\config.toml" `
  -CreateBackup
```

### Example 3: Render VS Code MCP Output

```powershell
pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 `
  -OutputPath .\.vscode\mcp.tamplate.jsonc
```

### Example 4: Use Shared Security Gate In Any Repo

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Install-SecurityAuditPrerequisites.ps1') -RepoRoot $PWD -FrontendPackageManager auto
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-PreBuildSecurityGate.ps1') -RepoRoot $PWD -InstallMissingPrerequisites -FailOnSeverities Critical,High
```

---

## API Reference

### Scripts

`sync-codex-mcp-config.ps1`
- Inputs: catalog path or manifest path, target config path, backup/dry-run flags.
- Behavior: rewrites only `[mcp_servers.*]` sections in TOML.

`render-vscode-mcp-template.ps1`
- Inputs: catalog path, output path.
- Behavior: generates the VS Code MCP projection from the canonical runtime catalog.

`scripts/security/Invoke-PreBuildSecurityGate.ps1`
- Inputs: repo root, stack toggles, severity threshold, warning-only mode.
- Behavior: runs consolidated dependency vulnerability gate via stack-specific scripts with optional prerequisite installation.

`scripts/security/Install-SecurityAuditPrerequisites.ps1`
- Inputs: repo root, stack toggles, frontend manager mode, system install switch.
- Behavior: validates and auto-installs missing audit prerequisites before gates.

`scripts/security/Invoke-VulnerabilityAudit.ps1`
- Inputs: solution path, severity threshold.
- Behavior: runs .NET package vulnerability audit.

`scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1`
- Inputs: frontend project path, package manager mode, severity threshold.
- Behavior: runs npm/pnpm/yarn dependency vulnerability audit.

`scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1`
- Inputs: Rust project path, severity threshold.
- Behavior: runs cargo-audit vulnerability check.

---

## Build and Tests

```powershell
# validate VS Code render
pwsh -File .\scripts\runtime\render-vscode-mcp-template.ps1 -OutputPath .\.temp\vscode.mcp.generated.json

# validate codex apply logic without writing
pwsh -File .\scripts\runtime\sync-codex-mcp-config.ps1 -DryRun
```

---

## Contributing

- Keep wrapper behavior thin and deterministic.
- Edit the authoritative copies under `definitions/providers/codex/scripts/`,
  then re-render `.codex/scripts/`.
- Preserve local user configuration outside MCP sections.
- Update `.codex/mcp/README.md` when script behavior changes.

---

## Dependencies

- Runtime: PowerShell 7+.
- Optional tooling from manifest server definitions (for example `npx`).

---

## References

- `.github/governance/mcp-runtime.catalog.json`
- `.codex/mcp/servers.manifest.json`
- `.codex/mcp/README.md`
- `scripts/runtime/sync-codex-mcp-config.ps1`
- `scripts/runtime/render-vscode-mcp-template.ps1`