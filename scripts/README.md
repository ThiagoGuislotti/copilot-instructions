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
- ✅ Policy-as-code validation for instruction/runtime governance
- ✅ Multi-agent contract and orchestration validation
- ✅ Release governance checks (CODEOWNERS, changelog contracts, branch-protection baseline)
- ✅ Healthcheck and self-heal flows with JSON reports and execution logs

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

# Run full enterprise healthcheck
pwsh -File .\scripts\runtime\healthcheck.ps1 -StrictExtras

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
│   ├── bootstrap.ps1
│   ├── doctor.ps1
│   ├── apply-vscode-templates.ps1
│   ├── healthcheck.ps1
│   └── self-heal.ps1
├── governance/
│   └── set-branch-protection.ps1
├── git-hooks/
│   └── setup-git-hooks.ps1
├── validation/
│   ├── validate-instructions.ps1
│   ├── validate-agent-orchestration.ps1
│   ├── validate-policy.ps1
│   ├── validate-release-governance.ps1
│   └── export-audit-report.ps1
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
- `.codex/orchestration/` -> `~/.codex/shared-orchestration`

MCP apply mode updates only `[mcp_servers.*]` sections in `~/.codex/config.toml`, preserving the rest.

Runtime-sensitive files such as `~/.codex/auth.json`, `~/.codex/sessions/`, and `~/.codex/log/` are not managed.

### Utility Scripts

| Script | Purpose | Quick example |
|--------|---------|---------------|
| `deploy/deploy-backend-to-vps.ps1` | Interactive Docker deployment pipeline for VPS hosts. | `& .\scripts\deploy\deploy-backend-to-vps.ps1 @params` |
| `doc/validate-xml-documentation.ps1` | Audits `<summary>` XML documentation across C# projects. | `pwsh -File scripts/doc/validate-xml-documentation.ps1 -ProjectPath src/Api` |
| `validation/validate-instructions.ps1` | Validates instruction assets (routing catalog paths, markdown links, and JSON files used by prompts/skills/snippets). | `pwsh -File scripts/validation/validate-instructions.ps1` |
| `validation/validate-agent-orchestration.ps1` | Validates multi-agent contracts (`.codex/orchestration/*`) against schemas and cross-file integrity rules. | `pwsh -File scripts/validation/validate-agent-orchestration.ps1` |
| `validation/validate-policy.ps1` | Validates policy contracts declared in `.github/policies/*.json` (required files/directories/hooks). | `pwsh -File scripts/validation/validate-policy.ps1` |
| `validation/validate-release-governance.ps1` | Validates release-governance baseline (`CHANGELOG`, `CODEOWNERS`, branch-protection baseline, governance docs). | `pwsh -File scripts/validation/validate-release-governance.ps1` |
| `validation/export-audit-report.ps1` | Runs health baseline and exports consolidated JSON audit report with git metadata and policy inventory. | `pwsh -File scripts/validation/export-audit-report.ps1` |
| `validation/test-routing-selection.ps1` | Runs deterministic golden tests for static routing behavior based on catalog + fixtures. | `pwsh -File scripts/validation/test-routing-selection.ps1` |
| `governance/set-branch-protection.ps1` | Validates or applies branch protection from `.github/governance/branch-protection.baseline.json` using GitHub CLI. | `pwsh -File scripts/governance/set-branch-protection.ps1 -Apply` |
| `git-hooks/setup-git-hooks.ps1` | Configures local Git hooks path (`core.hooksPath=.githooks`) and enables `pre-commit` validation + `post-commit` sync. | `pwsh -File scripts/git-hooks/setup-git-hooks.ps1` |
| `runtime/doctor.ps1` | Diagnoses drift between repository-managed runtime assets and local `~/.github`/`~/.codex` copies. | `pwsh -File scripts/runtime/doctor.ps1` |
| `runtime/apply-vscode-templates.ps1` | Applies `.vscode/*.tamplate.jsonc` into active `.vscode/settings.json` and `.vscode/mcp.json` files. | `pwsh -File scripts/runtime/apply-vscode-templates.ps1 -Force` |
| `runtime/healthcheck.ps1` | Executes end-to-end validation (`validate-instructions`, `validate-policy`, `validate-agent-orchestration`, `validate-release-governance`, `doctor`) and writes log/report artifacts. | `pwsh -File scripts/runtime/healthcheck.ps1 -StrictExtras` |
| `runtime/self-heal.ps1` | Runs controlled repair flow (bootstrap + optional templates) and validates final state via healthcheck. | `pwsh -File scripts/runtime/self-heal.ps1 -Mirror -StrictExtras` |
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

# diagnose runtime drift
pwsh -File .\scripts\runtime\doctor.ps1

# apply VS Code active files from versioned templates
pwsh -File .\scripts\runtime\apply-vscode-templates.ps1 -Force

# run enterprise healthcheck with strict runtime guarantees
pwsh -File .\scripts\runtime\healthcheck.ps1 -StrictExtras

# auto-repair runtime and validate final state
pwsh -File .\scripts\runtime\self-heal.ps1 -Mirror -StrictExtras

# validate instruction assets and static routing references
pwsh -File .\scripts\validation\validate-instructions.ps1

# validate policy contracts
pwsh -File .\scripts\validation\validate-policy.ps1

# validate multi-agent contracts and pipeline integrity
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1

# validate release governance contracts
pwsh -File .\scripts\validation\validate-release-governance.ps1

# validate branch protection drift from baseline
pwsh -File .\scripts\governance\set-branch-protection.ps1

# export consolidated audit report (JSON + logs)
pwsh -File .\scripts\validation\export-audit-report.ps1 -StrictExtras

# validate deterministic route selection
pwsh -File .\scripts\validation\test-routing-selection.ps1

# install local Git hooks (validation + sync)
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1

# inspect help for script contracts
Get-Help .\scripts\runtime\bootstrap.ps1 -Full
```

After setup, hooks behavior is:
- `pre-commit`: runs `validate-instructions` + `validate-policy` + `validate-agent-orchestration` + `validate-release-governance` and blocks commit on failures
- `post-commit`: runs `scripts/runtime/bootstrap.ps1` to sync `~/.github` and `~/.codex` (best effort)
- `post-merge`: runs `validate-instructions` + `validate-policy` + `validate-agent-orchestration` + `validate-release-governance` (validation-only)
- `post-checkout`: runs `validate-instructions` + `validate-policy` + `validate-agent-orchestration` + `validate-release-governance` (validation-only)
- `post-commit` optional MCP apply on manifest changes: set `CODEX_APPLY_MCP_ON_POST_COMMIT=1`
- `post-commit` MCP backup control: `CODEX_BACKUP_MCP_CONFIG=1|0` (`1` default)

To skip sync for a single shell session:
```powershell
$env:CODEX_SKIP_POST_COMMIT_SYNC = "1"
```

Full hook contracts are documented in `README.md` (`Git Hooks` section).

Health and audit logs are written under `.temp/logs/` by healthcheck and audit scripts.

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
- `README.md`