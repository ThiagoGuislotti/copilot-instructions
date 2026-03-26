# VS Code Profiles

> Versioned VS Code profile baselines with profile-aware MCP selection.

---

## Introduction

This folder keeps the authoritative repository-owned VS Code profile definitions under `profile-*.json`.
The rendered repository surface lives under `.vscode/profiles/`, and the operator
entrypoint lives in `scripts/runtime/setup-vscode-profiles.ps1`.

Profiles are the place where you choose which MCP servers should stay enabled for
your current VS Code setup. The canonical MCP template still lives in
`.vscode/mcp.tamplate.jsonc`, but each profile can
override server enablement through its `mcp.servers.<name>.enabled` map.

---

## Quick Start

List available profiles:

```powershell
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -ListProfiles
```

Create one profile and sync the global MCP selection from it:

```powershell
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -ProfileName Frontend -CreateMcpBackup
```

Create multiple profiles but force one of them to drive MCP enablement:

```powershell
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -ProfileName Base,Frontend -McpProfileName Frontend -CreateMcpBackup
```

Preview without changing anything:

```powershell
pwsh -File .\scripts\runtime\setup-vscode-profiles.ps1 -DryRun -ProfileName "Backend .NET"
```

---

## MCP Behavior

The setup flow delegates MCP sync to `scripts/runtime/sync-vscode-global-mcp.ps1`.

That means:

- `%APPDATA%\Code\User\mcp.json` is regenerated from the tracked MCP template
- `.vscode/mcp-vscode-global.json` is refreshed as the ignored local helper mirror
- the selected profile can enable or disable MCP servers without changing the base template
- stable `${input:...}` auth ids let VS Code reuse securely stored credentials after the first prompt

If multiple profiles are selected and no explicit `-McpProfileName` is supplied,
MCP sync is skipped because the choice is ambiguous.

---

## Profile Schema

Minimal shape:

```json
{
  "name": "Frontend",
  "description": "Vue/TS/browser tooling profile.",
  "extends": "Base",
  "extensions": [
    "vue.volar"
  ],
  "mcp": {
    "servers": {
      "io.github.github/github-mcp-server": { "enabled": true },
      "microsoft/playwright-mcp": { "enabled": true },
      "com.microsoft/azure": { "enabled": false }
    }
  }
}
```

---

## Notes

- Keep `profile-*.json` versioned here as the source of truth.
- Use `scripts/runtime/setup-vscode-profiles.ps1` as the operator entrypoint.
- Keep executable logic under `scripts/`; this folder stores authoritative profile JSON only.
- Do not hand-edit `.vscode/mcp-vscode-global.json`; it is generated.