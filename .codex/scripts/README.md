# Codex Scripts

> Shared runtime scripts synced to `~/.codex/shared-scripts` for cross-repository usage.

---

## Introduction

These scripts are synchronized by `scripts/runtime/bootstrap.ps1` into local runtime so agents can execute them in any project without copying scripts into each repository.

---

## Features

- ✅ Render VS Code MCP template (`mcp.tamplate.jsonc`) from manifest
- ✅ Apply MCP servers into local `~/.codex/config.toml`
- ✅ Preserve non-MCP sections in local Codex config
- ✅ Shared security vulnerability gates for .NET, frontend, and Rust

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
pwsh -File .\scripts\runtime\bootstrap.ps1
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

### Example 4: Use Shared Security Gate In Any Repo

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Install-SecurityAuditPrerequisites.ps1') -RepoRoot $PWD -FrontendPackageManager auto
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-PreBuildSecurityGate.ps1') -RepoRoot $PWD -InstallMissingPrerequisites -FailOnSeverities Critical,High
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

`security/Invoke-PreBuildSecurityGate.ps1`
- Inputs: repo root, stack toggles, severity threshold, warning-only mode.
- Behavior: runs consolidated dependency vulnerability gate via stack-specific scripts with optional prerequisite installation.

`security/Install-SecurityAuditPrerequisites.ps1`
- Inputs: repo root, stack toggles, frontend manager mode, system install switch.
- Behavior: validates and auto-installs missing audit prerequisites before gates.

`security/Invoke-VulnerabilityAudit.ps1`
- Inputs: solution path, severity threshold.
- Behavior: runs .NET package vulnerability audit.

`security/Invoke-FrontendPackageVulnerabilityAudit.ps1`
- Inputs: frontend project path, package manager mode, severity threshold.
- Behavior: runs npm/pnpm/yarn dependency vulnerability audit.

`security/Invoke-RustPackageVulnerabilityAudit.ps1`
- Inputs: Rust project path, severity threshold.
- Behavior: runs cargo-audit vulnerability check.

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