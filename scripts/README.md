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
- ✅ Multi-agent pipeline runner with guardrails and deterministic stage handoffs
- ✅ Release governance checks (CODEOWNERS, changelog contracts, branch-protection baseline)
- ✅ Security baseline checks (sensitive file patterns and secret-like content scanning)
- ✅ Release provenance checks (validation coverage, evidence files, git traceability, optional audit proof)
- ✅ Validation profiles (`dev`, `release`, `enforced`) with warning-only execution policy
- ✅ Hash-chained validation ledger for immutable local audit trail
- ✅ Agent/skill permission matrix checks and supply-chain baseline checks
- ✅ Unified validation suite runner (`validate-all`) for local hooks and CI
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

# Execute default multi-agent pipeline (writes artifacts to .temp/runs)
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Validate enterprise multi-agent flow"

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
│   ├── self-heal.ps1
│   ├── run-agent-pipeline.ps1
│   └── clean-codex-runtime.ps1
├── orchestration/
│   └── stages/
│       ├── plan-stage.ps1
│       ├── implement-stage.ps1
│       ├── validate-stage.ps1
│       └── review-stage.ps1
├── governance/
│   └── set-branch-protection.ps1
├── git-hooks/
│   └── setup-git-hooks.ps1
├── validation/
│   ├── validate-instructions.ps1
│   ├── validate-agent-orchestration.ps1
│   ├── validate-policy.ps1
│   ├── validate-release-governance.ps1
│   ├── validate-routing-coverage.ps1
│   ├── validate-agent-skill-alignment.ps1
│   └── export-audit-report.ps1
├── deploy/
├── doc/
├── maintenance/
├── security/
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
| `validation/validate-readme-standards.ps1` | Validates README structure/formatting using `.github/governance/readme-standards.baseline.json`. | `pwsh -File scripts/validation/validate-readme-standards.ps1` |
| `validation/validate-powershell-standards.ps1` | Validates script standards for PowerShell files (help, param block, function docs, approved verbs). | `pwsh -File scripts/validation/validate-powershell-standards.ps1` |
| `validation/validate-shell-hooks.ps1` | Validates `.githooks/*` shell syntax with `sh -n` and optional `shellcheck`. | `pwsh -File scripts/validation/validate-shell-hooks.ps1` |
| `validation/validate-runtime-script-tests.ps1` | Runs Pester tests for critical runtime scripts under `scripts/tests/pester`. | `pwsh -File scripts/validation/validate-runtime-script-tests.ps1` |
| `validation/validate-dotnet-standards.ps1` | Validates .NET template standards under `.github/templates/*.cs`. | `pwsh -File scripts/validation/validate-dotnet-standards.ps1` |
| `validation/validate-architecture-boundaries.ps1` | Validates architecture boundaries from `.github/governance/architecture-boundaries.baseline.json`. | `pwsh -File scripts/validation/validate-architecture-boundaries.ps1` |
| `validation/validate-instruction-metadata.ps1` | Validates frontmatter metadata for `.github/instructions`, `.github/prompts`, and `.github/chatmodes`. | `pwsh -File scripts/validation/validate-instruction-metadata.ps1` |
| `validation/validate-routing-coverage.ps1` | Validates route coverage between `instruction-routing.catalog.yml` and golden fixtures. | `pwsh -File scripts/validation/validate-routing-coverage.ps1` |
| `validation/validate-agent-skill-alignment.ps1` | Validates consistency among agent manifest, skills, pipeline stages, and eval requiredAgents. | `pwsh -File scripts/validation/validate-agent-skill-alignment.ps1` |
| `validation/validate-agent-permissions.ps1` | Validates alignment between agent contracts and `.github/governance/agent-skill-permissions.matrix.json`. | `pwsh -File scripts/validation/validate-agent-permissions.ps1` |
| `validation/validate-security-baseline.ps1` | Validates `.github/governance/security-baseline.json` (required governance paths, forbidden sensitive files, and secret-like pattern scanning). Runs in warning-only mode by default. | `pwsh -File scripts/validation/validate-security-baseline.ps1` |
| `validation/validate-warning-baseline.ps1` | Validates PSScriptAnalyzer warning volume against `.github/governance/warning-baseline.json`. | `pwsh -File scripts/validation/validate-warning-baseline.ps1` |
| `validation/validate-supply-chain.ps1` | Validates dependency manifests against `.github/governance/supply-chain.baseline.json` and exports local SBOM artifact. | `pwsh -File scripts/validation/validate-supply-chain.ps1` |
| `validation/validate-release-provenance.ps1` | Validates release provenance baseline (`requiredValidationChecks`, `requiredEvidenceFiles`, changelog recency, git traceability, optional audit report). Runs in warning-only mode by default. | `pwsh -File scripts/validation/validate-release-provenance.ps1` |
| `validation/validate-audit-ledger.ps1` | Validates `.temp/audit/validation-ledger.jsonl` hash-chain integrity. | `pwsh -File scripts/validation/validate-audit-ledger.ps1` |
| `validation/validate-all.ps1` | Runs full profile-based suite, warning-only by default, appends hash-chained ledger evidence, and emits performance report at `.temp/audit/validate-all.latest.json`. | `pwsh -File scripts/validation/validate-all.ps1 -ValidationProfile dev` |
| `validation/export-audit-report.ps1` | Runs health baseline and exports consolidated JSON audit report with git metadata and policy inventory. | `pwsh -File scripts/validation/export-audit-report.ps1` |
| `validation/export-enterprise-trends.ps1` | Exports trends dashboard artifacts (`warnings`, `vulnerabilities`, and validation performance) from ledger + latest reports. | `pwsh -File scripts/validation/export-enterprise-trends.ps1` |
| `validation/test-routing-selection.ps1` | Runs deterministic golden tests for static routing behavior based on catalog + fixtures. | `pwsh -File scripts/validation/test-routing-selection.ps1` |
| `governance/set-branch-protection.ps1` | Validates or applies branch protection from `.github/governance/branch-protection.baseline.json` using GitHub CLI. | `pwsh -File scripts/governance/set-branch-protection.ps1 -Apply` |
| `git-hooks/setup-git-hooks.ps1` | Configures local Git hooks path (`core.hooksPath=.githooks`) and enables `pre-commit` validation + `post-commit` sync. | `pwsh -File scripts/git-hooks/setup-git-hooks.ps1` |
| `runtime/doctor.ps1` | Diagnoses drift between repository-managed runtime assets and local `~/.github`/`~/.codex` copies. | `pwsh -File scripts/runtime/doctor.ps1` |
| `runtime/apply-vscode-templates.ps1` | Applies `.vscode/*.tamplate.jsonc` into active `.vscode/settings.json` and `.vscode/mcp.json` files. | `pwsh -File scripts/runtime/apply-vscode-templates.ps1 -Force` |
| `runtime/healthcheck.ps1` | Runs `validate-all` (profile-aware) plus `runtime-doctor`, emits report/log, and defaults to warning-only mode. | `pwsh -File scripts/runtime/healthcheck.ps1 -ValidationProfile release` |
| `runtime/self-heal.ps1` | Runs controlled repair flow (bootstrap + optional templates) and validates final state via healthcheck. | `pwsh -File scripts/runtime/self-heal.ps1 -Mirror -StrictExtras` |
| `runtime/run-agent-pipeline.ps1` | Executes default multi-agent pipeline with blocked-command, allowed-path, and budget guardrails; writes run artifacts under `.temp/runs/<traceId>/`. | `pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate change"` |
| `runtime/clean-codex-runtime.ps1` | Cleans local Codex runtime garbage (`tmp`, `vendor_imports`) and prunes `log`/`sessions` files older than retention using `LastWriteTime` (default 30 days). | `pwsh -File scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 30 -Apply` |
| `orchestration/stages/*.ps1` | Stage executors (`plan`, `implement`, `validate`, `review`) consumed by `run-agent-pipeline.ps1`. | `pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Smoke run"` |
| `maintenance/clean-build-artifacts.ps1` | Deletes `.build`, `.deployment`, `bin`, and `obj` directories. Supports dry-run and prompts for confirmation. | `pwsh -File scripts/maintenance/clean-build-artifacts.ps1 -DryRun` |
| `maintenance/generate-http-from-openapi.ps1` | Generates a REST Client .http file from OpenAPI (default) or Swagger JSON. | `pwsh -File scripts/maintenance/generate-http-from-openapi.ps1 -Source http://localhost:5000` |
| `maintenance/fix-version-ranges.ps1` | Normalises PackageReference versions into `[current, limit)` ranges. | `pwsh -File scripts/maintenance/fix-version-ranges.ps1 -Verbose` |
| `maintenance/trim-trailing-blank-lines.ps1` | Removes trailing spaces and blank lines at EOF. | `pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1 -Path "C:\repo" -CheckOnly` |
| `security/Invoke-VulnerabilityAudit.ps1` | Audits .NET backend package vulnerabilities via `dotnet list package --vulnerable --include-transitive`. | `pwsh -File scripts/security/Invoke-VulnerabilityAudit.ps1 -FailOnSeverities Critical,High` |
| `security/Invoke-FrontendPackageVulnerabilityAudit.ps1` | Audits frontend dependencies using npm/pnpm/yarn and applies severity quality gate. | `pwsh -File scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1 -ProjectPath src/WebApp -FailOnSeverities Critical,High` |
| `security/Invoke-RustPackageVulnerabilityAudit.ps1` | Audits Rust dependencies via `cargo audit --json` with severity quality gate. | `pwsh -File scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1 -ProjectPath . -FailOnSeverities Critical,High` |
| `security/Install-SecurityAuditPrerequisites.ps1` | Validates and auto-installs audit prerequisites (`dotnet`, `cargo`, `cargo-audit`, npm/pnpm/yarn) with optional system package manager support. | `pwsh -File scripts/security/Install-SecurityAuditPrerequisites.ps1 -FrontendPackageManager auto` |
| `security/Invoke-PreBuildSecurityGate.ps1` | Runs unified pre-build vulnerability gate across .NET, frontend, and Rust using stack scripts and consolidated summary artifacts; optionally runs prerequisite setup first. | `pwsh -File scripts/security/Invoke-PreBuildSecurityGate.ps1 -InstallMissingPrerequisites -FailOnSeverities Critical,High` |
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

# execute default multi-agent pipeline and produce run artifact
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Run pipeline smoke test"

# preview/runtime cleanup (no deletion)
pwsh -File .\scripts\runtime\clean-codex-runtime.ps1 -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 30

# apply runtime cleanup and session retention
pwsh -File .\scripts\runtime\clean-codex-runtime.ps1 -IncludeSessions -SessionRetentionDays 30 -LogRetentionDays 30 -Apply

# validate instruction assets and static routing references
pwsh -File .\scripts\validation\validate-instructions.ps1

# run full validation suite (hooks baseline)
pwsh -File .\scripts\validation\validate-all.ps1

# validate policy contracts
pwsh -File .\scripts\validation\validate-policy.ps1

# validate multi-agent contracts and pipeline integrity
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1

# validate routing catalog coverage against golden fixtures
pwsh -File .\scripts\validation\validate-routing-coverage.ps1

# validate agent, skill, pipeline, and eval alignment
pwsh -File .\scripts\validation\validate-agent-skill-alignment.ps1

# validate release governance contracts
pwsh -File .\scripts\validation\validate-release-governance.ps1

# validate security baseline (paths + secret-like content patterns)
pwsh -File .\scripts\validation\validate-security-baseline.ps1

# validate release provenance baseline and evidence traceability
pwsh -File .\scripts\validation\validate-release-provenance.ps1

# validate agent permission matrix
pwsh -File .\scripts\validation\validate-agent-permissions.ps1

# validate warning baseline (PSScriptAnalyzer volume)
pwsh -File .\scripts\validation\validate-warning-baseline.ps1

# validate supply-chain baseline and export SBOM
pwsh -File .\scripts\validation\validate-supply-chain.ps1

# validate immutable validation ledger chain
pwsh -File .\scripts\validation\validate-audit-ledger.ps1

# run suite with release profile
pwsh -File .\scripts\validation\validate-all.ps1 -ValidationProfile release

# validate branch protection drift from baseline
pwsh -File .\scripts\governance\set-branch-protection.ps1

# export consolidated audit report (JSON + logs)
pwsh -File .\scripts\validation\export-audit-report.ps1 -ValidationProfile release -StrictExtras

# export enterprise trends dashboard artifacts
pwsh -File .\scripts\validation\export-enterprise-trends.ps1 -MaxEntries 30

# validate deterministic route selection
pwsh -File .\scripts\validation\test-routing-selection.ps1

# audit backend .NET dependencies before build/package
pwsh -File .\scripts\security\Invoke-VulnerabilityAudit.ps1 -FailOnSeverities Critical,High

# audit frontend dependencies (auto npm/pnpm/yarn)
pwsh -File .\scripts\security\Invoke-FrontendPackageVulnerabilityAudit.ps1 -ProjectPath src/WebApp -FailOnSeverities Critical,High

# audit Rust dependencies
pwsh -File .\scripts\security\Invoke-RustPackageVulnerabilityAudit.ps1 -ProjectPath . -FailOnSeverities Critical,High

# validate/install security audit prerequisites
pwsh -File .\scripts\security\Install-SecurityAuditPrerequisites.ps1 -FrontendPackageManager auto

# run single pre-build security gate for all stacks
pwsh -File .\scripts\security\Invoke-PreBuildSecurityGate.ps1 -InstallMissingPrerequisites -FailOnSeverities Critical,High

# same gate with system-level installation attempts (winget/choco/brew/apt/etc)
pwsh -File .\scripts\security\Invoke-PreBuildSecurityGate.ps1 -InstallMissingPrerequisites -AllowSystemPrerequisiteInstall -FailOnSeverities Critical,High

# run same gate from shared runtime in any repository (Windows/Linux/macOS)
$HomePath = if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) { $env:USERPROFILE } else { $HOME }
$SecurityScriptsRoot = Join-Path $HomePath '.codex/shared-scripts/security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-PreBuildSecurityGate.ps1') -RepoRoot $PWD -InstallMissingPrerequisites -FailOnSeverities Critical,High

# install local Git hooks (validation + sync)
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1

# inspect help for script contracts
Get-Help .\scripts\runtime\bootstrap.ps1 -Full
```

After setup, hooks behavior is:
- `pre-commit`: runs `validate-all -ValidationProfile dev -WarningOnly true` (best effort, warning-only)
- `post-commit`: runs `scripts/runtime/bootstrap.ps1 -Mirror` to sync and clean drift in `~/.github` and managed `~/.codex` folders (best effort)
- `post-commit`: runs `scripts/runtime/clean-codex-runtime.ps1 -LogRetentionDays 30 -IncludeSessions -SessionRetentionDays 30 -Apply` (best effort)
- `post-merge`: runs `validate-all -ValidationProfile release -WarningOnly true` (best effort, warning-only)
- `post-merge`: runs `scripts/runtime/clean-codex-runtime.ps1 -LogRetentionDays 30 -IncludeSessions -SessionRetentionDays 30 -Apply` (best effort)
- `post-checkout`: runs `validate-all -ValidationProfile dev -WarningOnly true` (best effort, warning-only)
- `post-commit` optional MCP apply on manifest changes: set `CODEX_APPLY_MCP_ON_POST_COMMIT=1`
- `post-commit` MCP backup control: `CODEX_BACKUP_MCP_CONFIG=1|0` (`1` default)
- `post-commit` mirror control: `CODEX_POST_COMMIT_MIRROR=0|1` (`1` default)
- `post-commit` and `post-merge` cleanup bypass: `CODEX_SKIP_RUNTIME_CLEANUP=1`
- `post-commit` and `post-merge` log retention: `CODEX_LOG_RETENTION_DAYS=<n>` (`30` default, by `LastWriteTime`)
- `post-commit` and `post-merge` session cleanup toggle: `CODEX_INCLUDE_SESSIONS_CLEANUP=0|1` (`1` default)
- `post-commit` and `post-merge` session retention: `CODEX_SESSION_RETENTION_DAYS=<n>` (`30` default, by `LastWriteTime`)

To skip sync for a single shell session:
```powershell
$env:CODEX_SKIP_POST_COMMIT_SYNC = "1"
```

Full hook contracts are documented in `README.md` (`Git Hooks` section).

Health and audit logs are written under `.temp/logs/` by healthcheck and audit scripts.
Validation ledger and SBOM artifacts are written under `.temp/audit/`.

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