# Scripts

> Automation scripts for bootstrap, deployment, docs validation, maintenance, and tests.

---

## Introduction

This folder centralizes operational scripts used by this repository. It includes bootstrap sync for shared `.github/.codex` assets and utility scripts for maintenance and tests.

---

## Features

- ✅ Bootstrap local runtime from versioned shared assets
- ✅ Utility scripts for deployment, docs, maintenance, and tests
- ✅ MCP apply mode integrated in bootstrap flow

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

No package installation is required. Scripts run with PowerShell 7+.

---

## Quick Start

```powershell
# Sync shared assets
pwsh -File .\scripts\runtime\bootstrap.ps1

# Sync and apply MCP servers into ~/.codex/config.toml
pwsh -File .\scripts\runtime\bootstrap.ps1 -ApplyMcpConfig -BackupConfig

# Enable local Git hooks (pre-commit + post-commit sync)
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1
```

---

## Usage Examples

### Example 1: Bootstrap Shared Runtime Assets

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1
```

### Example 2: Mirror Sync (Cleanup Included)

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -Mirror
```

### Example 3: Apply MCP Servers With Backup

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1 -ApplyMcpConfig -BackupConfig
```

---

## API Reference

### Structure

```text
scripts/
├── runtime/
│   └── bootstrap.ps1
├── git-hooks/
│   └── setup-git-hooks.ps1
├── validation/
│   └── validate-instructions.ps1
├── deploy/
├── doc/
├── maintenance/
├── tests/
└── README.md
```

### Bootstrap Contract

`runtime/bootstrap.ps1` syncs:
- `.github/` -> `~/.github`
- `.codex/skills/` -> `~/.codex/skills`
- `.codex/mcp/` -> `~/.codex/shared-mcp`
- `.codex/scripts/` -> `~/.codex/shared-scripts`

MCP apply mode updates only `[mcp_servers.*]` sections in `~/.codex/config.toml`, preserving the rest.

Runtime-sensitive files such as `~/.codex/auth.json`, `~/.codex/sessions/`, and `~/.codex/log/` are not managed.

### Utility Scripts

| Script | Purpose | Quick example |
|--------|---------|---------------|
| `deploy/deploy-backend-to-vps.ps1` | Interactive Docker deployment pipeline for VPS hosts. | `& .\scripts\deploy\deploy-backend-to-vps.ps1 @params` |
| `doc/validate-xml-documentation.ps1` | Audits `<summary>` XML documentation across C# projects. | `pwsh -File scripts/doc/validate-xml-documentation.ps1 -ProjectPath src/Api` |
| `validation/validate-instructions.ps1` | Validates instruction assets (routing catalog paths, markdown links, and JSON files used by prompts/skills/snippets). | `pwsh -File scripts/validation/validate-instructions.ps1` |
| `git-hooks/setup-git-hooks.ps1` | Configures local Git hooks path (`core.hooksPath=.githooks`) and enables `pre-commit` validation + `post-commit` sync. | `pwsh -File scripts/git-hooks/setup-git-hooks.ps1` |
| `maintenance/clean-build-artifacts.ps1` | Deletes `.build`, `.deployment`, `bin`, and `obj` directories. Supports dry-run and prompts for confirmation. | `pwsh -File scripts/maintenance/clean-build-artifacts.ps1 -DryRun` |
| `maintenance/generate-http-from-openapi.ps1` | Generates a REST Client .http file from OpenAPI (default) or Swagger JSON. | `pwsh -File scripts/maintenance/generate-http-from-openapi.ps1 -Source http://localhost:5000` |
| `maintenance/fix-version-ranges.ps1` | Normalises PackageReference versions into `[current, limit)` ranges. | `pwsh -File scripts/maintenance/fix-version-ranges.ps1 -Verbose` |
| `maintenance/trim-trailing-blank-lines.ps1` | Removes trailing spaces and blank lines at EOF. | `pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1 -Path "C:\repo" -CheckOnly` |
| `tests/apply-aaa-pattern.ps1` | Applies AAA comments to frontend TypeScript/Vue test files. | `pwsh -File scripts/tests/apply-aaa-pattern.ps1` |
| `tests/check-test-naming.ps1` | Validates required underscore segments in test names. | `pwsh -File scripts/tests/check-test-naming.ps1 Projects "OpenApi.Readers.UnitTests"` |
| `tests/refactor_tests_to_aaa.ps1` | Refactors Rust test files to follow AAA pattern with comments and formatting. | `pwsh -File scripts/tests/refactor_tests_to_aaa.ps1 -TestFile tests/unit/config_tests.rs` |
| `tests/run-coverage.ps1` | Runs tests with coverage and generates HTML/Cobertura reports. | `pwsh -File scripts/tests/run-coverage.ps1 -ProjectsDir tests` |

---

## Build and Tests

```powershell
# lint-like execution test for bootstrap (safe dry usage)
pwsh -File .\scripts\runtime\bootstrap.ps1 -TargetGithubPath .\.temp\github -TargetCodexPath .\.temp\codex

# validate instruction assets and static routing references
pwsh -File .\scripts\validation\validate-instructions.ps1

# install local Git hooks (validation + sync)
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1

# inspect help for script contracts
Get-Help .\scripts\runtime\bootstrap.ps1 -Full
```

After setup, hooks behavior is:
- `pre-commit`: runs `scripts/validation/validate-instructions.ps1`
- `post-commit`: runs `scripts/runtime/bootstrap.ps1` to sync `~/.github` and `~/.codex`

To skip sync for a single shell session:
```powershell
$env:CODEX_SKIP_POST_COMMIT_SYNC = "1"
```

---

## Contributing

- Keep scripts idempotent and safe by default.
- Document new script parameters in this README.
- Prefer explicit paths and robust error handling.

---

## Dependencies

- Runtime: PowerShell 7+, `robocopy` (Windows).
- Tooling-specific: may require `npx`, `dotnet`, or other CLIs depending on each script.

---

## References

- `.codex/README.md`
- `.codex/scripts/README.md`
- `.github/AGENTS.md`
- `.github/copilot-instructions.md`