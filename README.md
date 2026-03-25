# Copilot Instructions

> Structured AI agent instructions for software development projects. Defines a universal Super Agent lifecycle, hierarchical domain instruction files, and multi-runtime support for GitHub Copilot, OpenAI Codex, and Claude Code — focused on repeatable, high-quality engineering workflows across planning, implementation, testing, docs, and reviews.

[![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-supported-0969DA?logo=github&logoColor=white)](https://github.com/features/copilot)
[![Claude Code](https://img.shields.io/badge/Claude_Code-supported-D97706?logo=anthropic&logoColor=white)](https://claude.ai/code)
[![OpenAI Codex](https://img.shields.io/badge/OpenAI_Codex-supported-412991?logo=openai&logoColor=white)](https://openai.com/codex)
[![VS Code](https://img.shields.io/badge/VS_Code-integrated-007ACC?logo=visualstudiocode&logoColor=white)](https://code.visualstudio.com)

[![.NET](https://img.shields.io/badge/.NET-supported-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com)
[![Rust](https://img.shields.io/badge/Rust-supported-CE422B?logo=rust&logoColor=white)](https://www.rust-lang.org)
[![Vue.js](https://img.shields.io/badge/Vue.js%2FQuasar-supported-42B883?logo=vue.js&logoColor=white)](https://vuejs.org)
[![Docker](https://img.shields.io/badge/Docker-supported-2496ED?logo=docker&logoColor=white)](https://www.docker.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-supported-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![PowerShell](https://img.shields.io/badge/PowerShell-supported-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell)

---

## Supported AI Runtimes

| Runtime | Versioned source | Global target | Install profile | Entry point |
| --- | --- | --- | --- | --- |
| ![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-0969DA?logo=github&logoColor=white&style=flat-square) | `.github/` | `~/.github` | `github` | `.github/copilot-instructions.md` |
| ![OpenAI Codex](https://img.shields.io/badge/OpenAI_Codex-412991?logo=openai&logoColor=white&style=flat-square) | `.codex/` | `~/.codex` | `codex` | `.codex/skills/super-agent/SKILL.md` |
| ![Claude Code](https://img.shields.io/badge/Claude_Code-D97706?logo=anthropic&logoColor=white&style=flat-square) | `.claude/` | `~/.claude` | `claude` | `CLAUDE.md` |

All three runtimes share the same **Super Agent lifecycle**, **44 domain instruction files**, **planning workspace**, and **governance catalogs** under `.github/`. Runtime-specific layers (skills, hooks, preferences) are the only divergence.

---

## Supported Tech Stacks

| Domain | Stack | Instruction files |
| --- | --- | --- |
| Backend / API | .NET 9 / C#, Clean Architecture, EF Core | `dotnet-csharp`, `clean-architecture-code`, `backend`, `api-high-performance-security` |
| Frontend | Vue.js 3 / Quasar, TypeScript | `vue-quasar`, `vue-quasar-architecture`, `frontend`, `ui-ux` |
| Systems | Rust | `rust-code-organization`, `rust-testing` |
| Database / ORM | SQL Server, EF Core, Dapper | `database`, `orm`, `database-configuration-operations` |
| Infrastructure | Docker, Kubernetes, CI/CD | `docker`, `k8s`, `ci-cd-devops`, `workflow-generation` |
| Scripts / Automation | PowerShell 7+ | `powershell-execution`, `powershell-script-creation` |
| Observability / SRE | OpenTelemetry, resilience | `observability-sre`, `platform-reliability-resilience` |
| Security / Compliance | OWASP, GDPR | `security-vulnerabilities`, `data-privacy-compliance` |
| Testing | TDD, E2E, static analysis | `tdd-verification`, `e2e-testing`, `static-analysis-sonarqube` |

---

## Features

### Instructions & Architecture
- ✅ **Hierarchical Instruction Structure:** Solution-level → Global → Domain-specific guidelines
- ✅ **Multi-Stack Coverage:** .NET/C#, Rust, Vue.js/Quasar, Docker, Kubernetes, databases
- ✅ **Architecture Patterns:** Clean Architecture, CQRS, DDD, microservices
- ✅ **Convention Standardization:** Code style, test patterns, commits, file organization
- ✅ **Authoritative Source Policy:** Repository context first, then official docs by stack

### AI Runtime Support
- ✅ **Single Visible Super Agent Starter:** the shared `super-agent` starter/controller stays canonical through `%USERPROFILE%\\.agents\\skills`; GitHub/Copilot runtime sync removes legacy duplicate starters from `%USERPROFILE%\\.github\\skills` and `%USERPROFILE%\\.copilot\\skills`, while the repo-owned Copilot agent profile keeps a secondary non-`/super-agent` alias under `%USERPROFILE%\\.github\\agents`
- ✅ **Codex Multi-Agent Orchestration:** 22 skills under `.codex/skills/`, pipeline manifests, and MCP configuration for OpenAI Codex
- ✅ **Claude Code Integration Layer:** `CLAUDE.md` workspace adapter, `.claude/skills/` skill adapters, and `settings.json` lifecycle hooks for Claude Code-native discovery and Super Agent lifecycle activation
- ✅ **VS Code Session Bootstrap Hooks:** repository-owned `SessionStart`, `PreToolUse`, and `SubagentStart` hooks for Copilot and Codex sessions inside VS Code
- ✅ **Planning-Anchored Continuity Bootstrap:** `SessionStart` and `SubagentStart` inject a short continuity summary from the latest active plan/spec so recovery after context compaction does not depend on replaying giant chat history
  - ✅ **Context Economy and Checkpoint Protocol:** automatic three-mode context compression (Execution / Continuous Compression / Structured Checkpoint) with a six-block state model, CHECKPOINT format, and user command vocabulary; enforced across Copilot, Codex, and Claude Code via `context-economy-checkpoint.instructions.md`
- ✅ **Safe Periodic Housekeeping:** `SessionStart` and `SubagentStart` can trigger a throttled housekeeping pass that exports planning continuity first and cleans only persisted Codex/VS Code runtime state, never the live active context window
- ✅ **Configurable Startup Controller Selector:** repository-owned hook selector with repo default plus local and environment overrides for the startup controller injected by VS Code hooks
- ✅ **Origin-Level EOF Guardrail:** repository-owned `PreToolUse` hook strips terminal newlines from supported AI edit payloads before VS Code writes tracked files

### Super Agent Lifecycle & Orchestration
- ✅ **Quality-First Non-Trivial Flow:** super-agent → brainstorm-spec → planner → context-token-optimizer → specialist → tester → reviewer → release-closeout
- ✅ **Versioned Planning Workspace:** Active/completed plans under `planning/` plus active/completed specs under `planning/specs/`
- ✅ **Multi-Agent Contracts:** Versioned orchestration manifests, schemas, and runtime artifacts
- ✅ **Approval Gate For Sensitive Execution:** sensitive implementation and closeout agents require explicit approval metadata before dispatching file-mutating or release-mutating work
- ✅ **Worker-Ready Planning:** planner work items carry target paths, explicit commands, expected checkpoints, and commit checkpoint suggestions
- ✅ **Task-Level Review Loop:** each implementation slice passes through task spec review and task quality review before completion
- ✅ **Safe Parallel Dispatch:** dependency-aware batching blocks overlapping write-sets before parallel worker fan-out
- ✅ **Worktree Isolation Helpers:** repository-owned worktree creation flow for risky or long-running workstreams
- ✅ **Workflow Entry Commands:** thin PowerShell entrypoints for brainstorm, plan, execute, and parallel dispatch flows
- ✅ **Guardrailed Multi-Agent Runner:** Deterministic pipeline execution with handoffs, budgets, allowed-path enforcement, and optional live `codex-exec` dispatch
- ✅ **Run-State Diagnostics:** Persisted `.temp/runs/<traceId>/run-state.json` snapshots for orchestration auditing and recovery analysis

### Developer Experience
- ✅ **Custom Chat Modes:** Architecture review, instruction generation
- ✅ **Prompt Templates:** POML-based templates with CoT, SoT, ToT patterns
- ✅ **Tool Integration:** Git, CLI tools, CI/CD pipelines, static analysis
- ✅ **Global VS Code MCP Sync:** canonical `.github/governance/mcp-runtime.catalog.json` now renders both the tracked `.vscode/mcp.tamplate.jsonc` projection and the global VS Code `mcp.json` profile plus the local ignored helper mirror `.vscode/mcp-vscode-global.json`
- ✅ **TDD and Verification Contracts:** repository-owned workflow rules for test-first implementation and verification-before-completion
- ✅ **Closeout Documentation Automation:** release closeout can rewrite repository README files and prepend CHANGELOG entries when the workstream is ready for commit
- ✅ **Canonical Artifact Layout:** non-versioned generated outputs standardized under `.build/` and `.deployment/`
- ✅ **Enterprise Dev Container:** Standardized toolchain for .NET, Rust, Node, PowerShell, and GitHub CLI

### Governance & Security
- ✅ **Unified Validation Suite:** Single `validate-all` command for hooks/CI governance checks
- ✅ **Security Baseline Validation:** Local enforcement for sensitive files and secret-like content patterns
- ✅ **Release Provenance Validation:** Local traceability checks for release evidence and validation coverage
- ✅ **Validation Profiles:** `dev`, `release`, and `enforced` profiles with warning-only policy
- ✅ **Immutable Audit Trail:** Hash-chained validation ledger under `.temp/audit/`
- ✅ **Agent Permission Matrix + Supply Chain:** Governance checks for agent permissions and dependency risk baseline
- ✅ **Security Observability Pipelines:** SBOM, provenance attestation, CodeQL, and Scorecard workflows without blocking merges
- ✅ **Dependency Automation:** Dependabot updates and PR dependency severity policy in warning-only observability mode
- ✅ **Trends Dashboard Export:** Consolidated metrics for validation warnings, vulnerability posture, and execution performance

---

## Table of Contents

- [Installation](#installation)
  - [Using in Existing Projects](#using-in-existing-projects)
  - [Repository Setup](#repository-setup)
  - [One-Step Local Onboarding](#one-step-local-onboarding)
  - [Cross-Platform Prerequisites](#cross-platform-prerequisites)
- [Contribution Workflow](#contribution-workflow)
- [Integration Matrix](#integration-matrix)
- [Architecture Model](#architecture-model)
  - [Layers](#layers)
  - [Architecture Contracts](#architecture-contracts)
  - [Planning Workspace](#planning-workspace)
  - [Runbooks](#runbooks)
  - [Policies](#policies)
  - [MCP Configuration](#mcp-configuration)
- [Dev Container](#dev-container)
  - [Includes](#includes)
  - [Usage](#usage)
  - [Repository Layout](#repository-layout)
  - [Bootstrap Local Folders](#bootstrap-local-folders)
- [Parameterization & Privacy](#parameterization--privacy)
  - [Rules](#rules)
  - [PowerShell Example (Safe Defaults)](#powershell-example-safe-defaults)
  - [Bash Example (Linux/macOS)](#bash-example-linuxmacos)
  - [Optional Local Override (Not Committed)](#optional-local-override-not-committed)
- [Git Hooks](#git-hooks)
  - [Setup](#setup)
  - [Global Manual Alias](#global-manual-alias)
  - [Do You Still Need `git trim-eof`?](#do-you-still-need-git-trim-eof)
  - [Global Autofix Limits](#global-autofix-limits)
  - [pre-commit](#pre-commit)
  - [post-commit](#post-commit)
  - [post-merge](#post-merge)
  - [post-checkout](#post-checkout)
  - [Enterprise Ops](#enterprise-ops)
  - [Issue Templates](#issue-templates)
- [Quick Start](#quick-start)
  - [Recommended: Static RAGs Routing](#recommended-most-important-static-rags-routing)
  - [Basic Setup (3 Steps)](#basic-setup-3-steps)
  - [First AI Interaction](#first-ai-interaction)
- [Usage Examples](#usage-examples)
  - [Code Refactoring (.NET)](#code-refactoring-net)
  - [Test Generation (Rust)](#test-generation-rust)
  - [Architecture Review](#architecture-review)
  - [Component Generation (Vue)](#component-generation-vue)
  - [Using Prompt Templates](#using-prompt-templates)
- [Chat Modes](#chat-modes)
  - [clean-architecture-review](#clean-architecture-reviewchatmodemd)
  - [instruction-writer](#instruction-writerchatmodemd)
- [Prompt Templates](#prompt-templates)
  - [Standard Templates (Markdown-based)](#standard-templates-markdown-based)
  - [POML Templates (XML-based)](#poml-templates-xml-based)
- [API Reference](#api-reference)
  - [Core Files](#core-files)
  - [Instruction Files](#instruction-files)
  - [Context Selection Rule](#context-selection-rule-hard-requirement)
  - [Static RAGs Routing](#static-rags-routing)
- [Dependencies](#dependencies)
  - [Runtime Dependencies](#runtime-dependencies)
  - [Development Dependencies](#development-dependencies)
  - [Optional Dependencies](#optional-dependencies)
- [References](#references)
  - [Official Documentation](#official-documentation)
  - [Best Practices & Articles](#best-practices--articles)
  - [Standards & Specifications](#standards--specifications)
  - [Internal Documentation](#internal-documentation)

---

## Installation

### Using in Existing Projects

Copy relevant files to your project (`.github/` for instructions and repo root for routing assets):

```bash
# Copy core instruction files
cp .github/AGENTS.md /path/to/your/project/.github/
cp .github/copilot-instructions.md /path/to/your/project/.github/

# Copy domain-specific instructions as needed
cp -r .github/instructions/ /path/to/your/project/.github/

# Optional: Copy chat modes, prompts, and routing schema
cp -r .github/chatmodes/ /path/to/your/project/.github/
cp -r .github/prompts/ /path/to/your/project/.github/
cp -r .github/schemas/ /path/to/your/project/.github/
```

### Repository Setup

```bash
git clone https://github.com/ThiagoGuislotti/copilot-instructions.git
cd copilot-instructions
```

### One-Step Local Onboarding

```powershell
$RepoRoot = '<REPO_ROOT>'
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig
```

You do not need to be inside the repository directory when running the installer. Point `pwsh -File` at the versioned script path and it will detect the repository root from the script location. Use `-RepoRoot` only when you need to override that default.

The installer is intentionally non-intrusive by default:

- `install.ps1` now defaults to runtime profile `none`
- `none` plans/applies nothing until you opt in with `-RuntimeProfile`
- the supported profiles are defined in `.github/governance/runtime-install-profiles.json`

Use one of these explicit profiles:

| Profile | What it enables |
| --- | --- |
| `none` | Default. No runtime projection, no VS Code global changes, no Git integration changes. |
| `github` | Only the GitHub/Copilot runtime surface: `githubRuntimeRoot`, its mirrored `scripts/`, and cleanup of legacy duplicate starters under `githubRuntimeRoot/skills` plus `copilotSkillsRoot`. |
| `codex` | Only the Codex runtime surface: `agentsSkillsRoot` plus `codexRuntimeRoot/shared-*`. |
| `claude` | Only the Claude Code runtime surface: `.claude/skills/` synced to `claudeRuntimeRoot/skills/` (`~/.claude/skills`). |
| `all` | Everything above plus global VS Code settings/snippets, local Git hooks, global Git aliases, and installer healthcheck. |

- `install.ps1` stays non-intrusive by default because `RuntimeProfile` defaults to `none`
- automatic runtime sync is not installed globally by default; it only runs in repositories that explicitly opt into the local `.githooks` runtime
- `pull` / `post-merge` does not run runtime bootstrap sync; it runs validation, reapplies safe Codex runtime preferences, and then runs cleanup

Runtime locations are also centralized now:

- versioned defaults live in `.github/governance/runtime-location-catalog.json`
- optional machine-local overrides live in `${HOME}/.codex/runtime-location-settings.json`
- every runtime/install script reads the same effective locations from `scripts/common/runtime-paths.ps1`

Example machine-local override:

```json
{
  "schemaVersion": 1,
  "paths": {
    "githubRuntimeRoot": "D:/ai-runtime/.github",
    "codexRuntimeRoot": "D:/ai-runtime/.codex",
    "agentsSkillsRoot": "D:/ai-runtime/.agents/skills",
    "copilotSkillsRoot": "D:/ai-runtime/.copilot/skills",
    "codexGitHooksRoot": "D:/ai-runtime/.codex/git-hooks",
    "claudeRuntimeRoot": "D:/ai-runtime/.claude"
  }
}
```

Defaults stay home-relative when no override file exists:

- Windows: `%USERPROFILE%/.github`, `%USERPROFILE%/.codex`, `%USERPROFILE%/.agents/skills`, `%USERPROFILE%/.copilot/skills`, `%USERPROFILE%/.claude`
- Linux/macOS: `$HOME/.github`, `$HOME/.codex`, `$HOME/.agents/skills`, `$HOME/.copilot/skills`, `$HOME/.claude`

Examples:

```powershell
# explicit no-op preview (default behavior)
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -PreviewOnly

# enable only the GitHub/Copilot runtime surface
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile github

# enable only the Codex runtime surface
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile codex -ApplyMcpConfig -BackupMcpConfig

# enable only the Claude Code runtime surface (syncs .claude/skills to ~/.claude/skills)
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile claude

# enable everything
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# enable everything with explicit safer Codex runtime overrides
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -CodexReasoningEffort medium -CodexMultiAgentMode disabled -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# enable full onboarding plus intrusive EOF autofix on pre-commit
# if scope is omitted, install asks whether it should be global and defaults to local-repo when you answer no
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -GitHookEofMode autofix -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# enable full onboarding plus explicit global EOF autofix across repositories using this hook runtime
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -GitHookEofMode autofix -GitHookEofScope global -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# global VS Code settings now keep Copilot Chat less prone to runaway sessions:
# - chat.agent.maxRequests = 100
# - chat.emptyState.history.enabled = false
# - chat.restoreLastPanelSession = false
# global VS Code MCP config also syncs the canonical MCP runtime catalog into:
# - tracked projection: `.vscode/mcp.tamplate.jsonc`
# - %APPDATA%\Code\User\mcp.json
# - .vscode/mcp-vscode-global.json
```

The VS Code MCP template also uses stable `${input:...}` identifiers per server so VS Code can store prompted credentials securely and reuse them across conversations instead of asking again every time:

- GitHub MCP: `${input:Authorization}`
- Postman MCP: `${input:PostmanAuthorization}`
- SonarQube MCP: `${input:SONARQUBE_TOKEN}`

Operational PowerShell entrypoints now share one execution-session pattern:

- default runs emit deterministic `Session start` / `Session end` markers
- default runs keep only necessary progress, errors, and final summaries
- verbose runs expand metadata and diagnostic detail through `-Verbose`, `-DetailedLogs`, or `-DetailedOutput` depending on the script contract
- the detailed user-facing contract, switch map, and family-by-family examples live in [scripts/README.md](./scripts/README.md)

Super Agent response economy is now quality-first as well:

- default chat and orchestration-facing output stays concise by design
- duplicated recap text across progress, review, closeout, and final completion should be avoided
- detailed breakdowns belong behind explicit user request or detailed/verbose modes
- token economy should target duplicated output first, not required execution context

Examples:

```text
Concise default:
- updated `scripts/runtime/install.ps1`
- validation: passed `validate-all`, passed `install.ps1 -RuntimeProfile all`
- remaining risk: none

Detailed on demand:
- outcome
- affected files
- validation evidence
- open risks
- follow-up options
```

### Cross-Platform Prerequisites

- PowerShell 7+ (`pwsh`) installed on Windows, Linux, or macOS.
- Git installed and available in `PATH`.
- Optional on Linux/macOS: ensure `chmod` is available (used by hook setup).

## Contribution Workflow

Use the repository-managed community flow instead of ad-hoc issue and PR descriptions.

- Read [CONTRIBUTING.md](./CONTRIBUTING.md) before changing versioned runtime assets.
- Use `.github/PULL_REQUEST_TEMPLATE.md` for pull requests.
- Use `.github/ISSUE_TEMPLATE/*` for bugs, new skill requests, runtime sync problems, and validation gaps.
- Keep repository changes in `<REPO_ROOT>`; use sync scripts to propagate runtime state afterward.

## Integration Matrix

| Integration target | Versioned source of truth | Runtime target |
| --- | --- | --- |
| Copilot instructions, prompts, and VS Code agent hooks | `.github/` | `%USERPROFILE%\\.github` |
| Codex runtime skills, MCP, orchestration, shared scripts | `.codex/` + `scripts/common` + `scripts/security` + `scripts/maintenance` | `%USERPROFILE%\\.codex` |
| Picker-visible local skills for VS Code/Codex | `.codex/skills/` | `%USERPROFILE%\\.agents\\skills` |
| Claude Code workspace adapter and lifecycle hooks | `CLAUDE.md` + `.claude/settings.json` | loaded by Claude Code at workspace open |
| Claude Code skill adapters (Super Agent pipeline) | `.claude/skills/` | `%USERPROFILE%\\.claude\\skills` |
| VS Code global settings | `.vscode/settings.tamplate.jsonc` | `%APPDATA%\\Code\\User\\settings.json` |
| VS Code global snippets | `.vscode/snippets/*.tamplate.code-snippets` | `%APPDATA%\\Code\\User\\snippets\\*.code-snippets` |
| VS Code workspaces | `.vscode/base.code-workspace` + `.github/governance/workspace-efficiency.baseline.json` | `.code-workspace` files refreshed by script |

## Architecture Model

The repository uses an explicit layered instruction architecture so context stays predictable and no single file silently becomes the owner of unrelated policy.

### Layers

- `Global core`: `.github/AGENTS.md` and `.github/copilot-instructions.md` stay short and define universal behavior only.
- `Repository operating model`: `.github/instructions/repository-operating-model.instructions.md` owns repository topology, build/test/run, style, release, and domain map details.
- `Planning workspace`: `.github/instructions/subagent-planning-workflow.instructions.md`, `.github/instructions/brainstorm-spec-workflow.instructions.md`, `planning/README.md`, and `planning/specs/README.md` define active/completed plan and spec handling for non-trivial work.
- `Cross-cutting policy`: `.github/instructions/authoritative-sources.instructions.md`, `.github/governance/*`, and `.github/policies/*` own rules that apply across domains.
- `Cross-cutting policy`: `.github/instructions/artifact-layout.instructions.md` owns the canonical non-versioned build and deployment artifact layout.
- `Domain instructions`: `.github/instructions/*.instructions.md` own stack-specific technical behavior.
- `Prompts`: `.github/prompts/*` are execution helpers and must not become normative policy owners.
- `Templates`: `.github/templates/*`, `.vscode/*.tamplate.jsonc`, `.vscode/snippets/*.tamplate.code-snippets`, and `.codex/mcp/*.template.*` define concrete artifact shapes only.
- `Codex skills`: `.codex/skills/*/SKILL.md` specialize execution and must reference canonical repo instructions instead of duplicating policy.
- `Claude Code skills`: `.claude/skills/*/SKILL.md` adapt the same pipeline roles to Claude Code native agent types (`Plan`, `Explore`, `general-purpose`) and must reference canonical repo instructions without duplicating policy.
- `Runtime projection`: `scripts/runtime/*` renders the versioned source of truth into `%USERPROFILE%\\.github`, `%USERPROFILE%\\.codex`, `%USERPROFILE%\\.claude`, and the VS Code global profile.

### Architecture Contracts

- Keep the route-first model deterministic: `instruction-routing.catalog.yml` is the only routing source of truth.
- Keep global context stable: avoid regrowing `AGENTS.md` and `copilot-instructions.md` with domain detail that belongs elsewhere.
- Keep policy centralized: if a rule can be defined once in governance or a shared instruction, do not duplicate it in domain files, prompts, templates, or skills.
- Keep runtime non-authoritative: local runtime folders are projections of the repository, never the source of truth.
- Keep non-trivial work on the mandatory planning chain and keep active plans in `planning/active/` plus active specs in `planning/specs/active/` until the work is materially complete.

### Planning Workspace

The repository uses versioned planning artifacts to keep non-trivial work auditable without polluting stable docs.

- `planning/README.md` explains the planning contract.
- `planning/active/` stores the current active plan files.
- `planning/specs/README.md` explains the brainstorming/spec contract.
- `planning/specs/active/` stores the current active spec files when design direction must be versioned before planning.
- `planning/completed/` stores closed plans after implementation, validation, review, and closeout.
- `instructions/super-agent.instructions.md` defines the mandatory intake-to-closeout lifecycle for change-bearing work.
- `instructions/brainstorm-spec-workflow.instructions.md` defines when a separate spec is required before planning.
- `instructions/subagent-planning-workflow.instructions.md` defines the mandatory super-agent -> brainstorm-spec -> planner -> specialist -> tester -> reviewer -> release-closeout flow, with `context-token-optimizer` as an optional routing aid when the task is multi-domain or the context pack is clearly redundant.
- `instructions/subagent-planning-workflow.instructions.md` treats `context-token-optimizer` as conditional: use it when the task is multi-domain or the context pack has obvious redundancy, but do not trim required working context purely for token savings.
- `instructions/worktree-isolation.instructions.md` defines when isolated worktrees should be created for risky or multi-slice execution.
- `instructions/tdd-verification.instructions.md` defines the default test-first and verification-before-completion workflow contract.

### Runbooks

Operational runbooks for critical scenarios live under `.github/runbooks/`:

| Runbook | Purpose |
| --- | --- |
| `release-rollback.runbook.md` | Step-by-step rollback procedure for a failed or problematic release |
| `runtime-drift.runbook.md` | Diagnosis and recovery for runtime assets that diverged from the versioned source |
| `validation-failures.runbook.md` | Triage and fix guide for validation suite failures in CI and local runs |

### Policies

Governance policy files live under `.github/policies/`. They define hard rules for orchestration, branch protection, CI, git hooks, instruction authoring, and release governance:

| Policy file | Scope |
| --- | --- |
| `agent-orchestration.policy.json` | Multi-agent pipeline rules, approval gates, budget limits |
| `branch-protection.policy.json` | Branch protection baseline for main and release branches |
| `ci-validation.policy.json` | CI validation suite profile and gate rules |
| `git-hooks.policy.json` | Git hook behavior defaults and EOF hygiene rules |
| `instruction-system.policy.json` | Instruction authoring rules, ownership, and hierarchy contracts |
| `release-governance.policy.json` | Release governance checklist, traceability, and evidence requirements |

GitHub governance infrastructure exported for branch/ruleset management lives under `infra/github/`:

| Infrastructure file | Scope |
| --- | --- |
| `infra/github/main.json` | GitHub ruleset / branch governance artifact for the main branch; not runtime or MCP configuration |

### MCP Configuration

The repository now uses one canonical MCP runtime catalog plus generated per-runtime projections:

- Canonical source of truth: `.github/governance/mcp-runtime.catalog.json`
- Generated VS Code projection: `.vscode/mcp.tamplate.jsonc`
- Generated Codex projection: `.codex/mcp/servers.manifest.json`
- Regenerate tracked projections: `pwsh -File scripts/runtime/render-mcp-runtime-artifacts.ps1`
- Apply to Codex config: `pwsh -File .codex/scripts/sync-mcp-to-codex-config.ps1 -CreateBackup`
- Applied automatically when `install.ps1` is run with `-ApplyMcpConfig`

For safe local RAG/CAG continuity, the repository also owns a deterministic local context index:

- Catalog: `.github/governance/local-context-index.catalog.json`
- Build or refresh: `pwsh -File scripts/runtime/update-local-context-index.ps1 -RepoRoot .`
- Query locally: `pwsh -File scripts/runtime/query-local-context-index.ps1 -RepoRoot . -QueryText "context compaction continuity" -JsonOutput`

## Dev Container

Use `.devcontainer/devcontainer.json` to run this repository with a standardized enterprise toolchain.

### Includes

- .NET SDK (`8.0`)
- Rust toolchain
- Node.js LTS
- PowerShell (`pwsh`)
- GitHub CLI

### Usage

1. Open the repository in VS Code.
2. Run `Dev Containers: Reopen in Container`.
3. Wait for `postCreateCommand` to execute runtime bootstrap + instruction validation.

### Repository Layout

```text
copilot-instructions/
├─ .github/   # shared Copilot + Codex instructions, prompts, chatmodes, schemas
├─ .codex/    # shared Codex assets (skills/mcp/scripts/orchestration)
├─ scripts/   # bootstrap + automation scripts
├─ README.md
└─ .gitignore
```

### Bootstrap Local Folders

```powershell
pwsh -File ./scripts/runtime/bootstrap.ps1

# one-step local onboarding wrapper
$RepoRoot = '<REPO_ROOT>'
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# optional: apply shared MCP servers separately when you do not want the full install wrapper
pwsh -File ./scripts/runtime/bootstrap.ps1 -ApplyMcpConfig -BackupConfig

# enterprise healthcheck (instructions + policy + agent orchestration + release governance + runtime doctor)
pwsh -File ./scripts/runtime/healthcheck.ps1 -StrictExtras
```

`bootstrap.ps1` remains the direct runtime sync entrypoint and defaults to runtime profile `all` when called on its own. Use `-RuntimeProfile github` or `-RuntimeProfile codex` when you want the projection to stay scoped to one runtime surface.

With profile `all`, bootstrap syncs versioned `.github/` and `.codex/` assets into the effective runtime locations from `runtime-location-catalog.json` plus any local override file, projects the single visible repository-owned starter/controller into `agentsSkillsRoot`, keeps the repo-owned Copilot agent profile under `githubRuntimeRoot/agents` with a non-canonical alias, removes legacy duplicate starter folders from `githubRuntimeRoot/skills` and `copilotSkillsRoot`, mirrors shared helper scripts from `scripts/common`, `scripts/security`, and `scripts/maintenance` into `codexRuntimeRoot/shared-scripts`, removes stale duplicate repo-managed skill folders from `codexRuntimeRoot/skills`, and applies MCP servers derived from `.github/governance/mcp-runtime.catalog.json` into `codexRuntimeRoot/config.toml` when `-ApplyMcpConfig` is included.

For Codex-enabled install profiles, onboarding also applies safe local runtime preferences into `config.toml`:
- `model_reasoning_effort = "high"`
- `[features].multi_agent = true`

Those defaults are versioned in `.github/governance/codex-runtime-hygiene.catalog.json` and are meant to preserve the normal multi-agent capability while keeping runtime hygiene focused on stale-session cleanup rather than trimming required execution context. The expectation is still strategic multi-agent use through the repository-owned Super Agent workflow, not fan-out for trivial work.

The synced GitHub runtime also carries VS Code hook configuration under `githubRuntimeRoot/hooks`, and the global settings template loads hooks from that path so Copilot and Codex sessions in VS Code receive the repository-owned bootstrap automatically.

The startup controller injected by those hooks is selected from `.github/hooks/super-agent.selector.json`. The repository default remains `Super Agent`, and you can override it without changing tracked files by either:

- creating `githubRuntimeRoot/hooks/super-agent.selector.local.json`
- setting `COPILOT_SUPER_AGENT_SKILL` and optionally `COPILOT_SUPER_AGENT_NAME`

The repository-owned `PreToolUse` hook also normalizes supported AI edit payloads (`createFile`, `insertEdit`, `replaceString`, and `multiReplaceString`) so files created or edited through VS Code agents preserve the repository EOF policy instead of gaining a terminal newline.

To apply active VS Code workspace files from templates:

```powershell
pwsh -File ./scripts/runtime/apply-vscode-templates.ps1 -Force

# render the versioned global VS Code settings template into Code/User/settings.json
pwsh -File ./scripts/runtime/sync-vscode-global-settings.ps1 -CreateBackup

# synchronize versioned snippets into Code/User/snippets
pwsh -File ./scripts/runtime/sync-vscode-global-snippets.ps1
```

---

## Parameterization & Privacy

To avoid exposing machine-specific information (for example `<HOME_PATH>/...`) in docs, logs, screenshots, or commits, prefer parameterized paths and environment variables.

### Rules

- Use relative repo paths in documentation and examples (`./scripts/...`) whenever possible.
- Use environment variables for runtime locations: `$env:USERPROFILE`, `$HOME`, `$env:REPO_ROOT`.
- Use placeholders in shared docs: `<REPO_ROOT>`, `<GITHUB_RUNTIME_PATH>`, `<CODEX_RUNTIME_PATH>`.
- Do not hardcode personal absolute paths in tracked files, prompts, or snippets.
- For chat runtime storage examples on Windows, keep paths parameterized:
  - `"%USERPROFILE%\\.codex\\session_index.jsonl"`
  - `"%APPDATA%\\Code\\User\\workspaceStorage\\<workspace-id>\\chatSessions\\*.json"`
  - `"%APPDATA%\\Code\\User\\workspaceStorage\\<workspace-id>\\chatSessions\\*.jsonl"`
  - `"%APPDATA%\\Code\\User\\globalStorage\\emptyWindowChatSessions\\*.json"`
  - `"%APPDATA%\\Code\\User\\globalStorage\\emptyWindowChatSessions\\*.jsonl"`

### PowerShell Example (Safe Defaults)

```powershell
$RepoRoot = $env:REPO_ROOT
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}

function Resolve-UserHome {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }

    if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        return $HOME
    }

    $folder = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($folder)) {
        return $folder
    }

    throw 'Could not resolve user home path. Set USERPROFILE or HOME.'
}

. (Join-Path $RepoRoot 'scripts/common/common-bootstrap.ps1') `
    -CallerScriptRoot (Join-Path $RepoRoot 'scripts/runtime') `
    -Helpers @('runtime-paths')

$GithubRuntimePath = Resolve-GithubRuntimePath
$CodexRuntimePath = Resolve-CodexRuntimePath

pwsh -File (Join-Path $RepoRoot 'scripts/runtime/bootstrap.ps1') `
    -RepoRoot $RepoRoot `
    -TargetGithubPath $GithubRuntimePath `
    -TargetCodexPath $CodexRuntimePath `
    -Mirror
```

### Bash Example (Linux/macOS)

```bash
export REPO_ROOT="${REPO_ROOT:-$(pwd)}"

pwsh -File "$REPO_ROOT/scripts/runtime/bootstrap.ps1" \
  -RepoRoot "$REPO_ROOT" \
  -Mirror
```

### Optional Local Override (Not Committed)

Prefer the machine-local runtime override file and keep it out of versioned files:

```powershell
$runtimeOverride = @{
  schemaVersion = 1
  paths = @{
    githubRuntimeRoot = 'D:/ai-runtime/.github'
    codexRuntimeRoot = 'D:/ai-runtime/.codex'
  }
} | ConvertTo-Json -Depth 20

Set-Content -LiteralPath (Join-Path $HOME '.codex/runtime-location-settings.json') -Value $runtimeOverride
```

---

## Git Hooks

Git hook authority is scope-aware:

- `local-repo` uses `git config --local core.hooksPath .githooks`
- `global` uses `git config --global core.hooksPath %USERPROFILE%/.codex/git-hooks`
- local repo config still overrides the global hook path when both exist

### Setup

```powershell
pwsh -File ./scripts/git-hooks/setup-git-hooks.ps1
```

The EOF hygiene mode is configurable either per clone/worktree or globally for the current machine.

Supported modes and scopes are defined in `.github/governance/git-hook-eof-modes.json`:

| Mode | Behavior |
| --- | --- |
| `manual` | Default. `pre-commit` does not trim files automatically. Use the manual `git trim-eof` alias yourself before staging/committing when needed. |
| `autofix` | Intrusive mode. On every commit, `pre-commit` trims staged files and re-stages them before validation. |

| Scope | Behavior |
| --- | --- |
| `local-repo` | Less intrusive default scope. Persists the selection only for the current clone/worktree under `.git/`. |
| `global` | Persists the selection once under `%USERPROFILE%\\.codex\\git-hook-eof-settings.json`, installs a managed machine-wide `pre-commit` hook under `%USERPROFILE%\\.codex\\git-hooks`, and configures `git config --global core.hooksPath` so repositories inherit it unless they define a local override. |

Examples:

```powershell
# keep the safer default behavior for this clone
pwsh -File ./scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode manual -EofHygieneScope local-repo

# opt this clone/PC into automatic staged EOF cleanup during pre-commit
pwsh -File ./scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope local-repo

# apply the same EOF mode globally and make global core.hooksPath the authority
pwsh -File ./scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope global

# same opt-in through the installer; when scope is omitted it asks whether you want global
pwsh -File ./scripts/runtime/install.ps1 -RuntimeProfile all -GitHookEofMode autofix
```

Settings files:

- `.git/codex-hook-eof-settings.json`
- `%USERPROFILE%\\.codex\\git-hook-eof-settings.json`
- local hook path: `git config --local core.hooksPath`
- global hook path: `git config --global core.hooksPath`

Resolution order on every commit:

1. `.git/codex-hook-eof-settings.json`
2. `%USERPROFILE%\\.codex\\git-hook-eof-settings.json`
3. catalog default (`manual` + `local-repo`)

`pre-commit` reads that configuration on every commit, so changing local or global scope takes effect immediately on the next commit without editing tracked files.

When `global` is configured, the managed global hook directory contains the shared `pre-commit` EOF hygiene hook only. Repository-specific `post-commit`, `post-merge`, and `post-checkout` flows remain local to repos that explicitly opt into `.githooks`.

### Global Manual Alias

```powershell
pwsh -File ./scripts/git-hooks/setup-global-git-aliases.ps1
```

This installs a manual global alias:

```powershell
git trim-eof
```

Use it in any Git repository before `git add` when you want to trim only the files currently reported by `git status`.

### Do You Still Need `git trim-eof`?

- If you enabled `autofix` with `-EofHygieneScope global` and the current repository inherits the global `core.hooksPath`, you do not need to run `git trim-eof` manually for normal commits on that machine. The managed global `pre-commit` hook trims staged files automatically.
- `git trim-eof` is still useful when you want to clean files before staging, inspect the diff before commit, or work in repositories that intentionally stay in `manual` mode.
- `git trim-eof` remains a manual helper. Automatic cleanup happens only on `pre-commit`.

### Global Autofix Limits

- Git has no native `pre-add` hook. Automatic cleanup does not run on `git add` or the VS Code stage action itself; it runs on `pre-commit`.
- Local hook-path precedence still applies:
  - `git config --local core.hooksPath` overrides `git config --global core.hooksPath`
  - repositories with a local override do not inherit the managed global `pre-commit`
- The managed global hook only applies EOF hygiene. Repository-specific validation and `post-*` hooks still require a local `.githooks` setup in that repository.
- In `autofix` mode, the commit is blocked when a file has both staged and unstaged changes, because automatic restaging would be unsafe.

Examples:

```powershell
# enable global EOF autofix for repositories that inherit the machine-wide hooks path
pwsh -File ./scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope global

# confirm the global hook path that repositories will inherit
git config --global --get core.hooksPath

# check whether the current repository is overriding the global hook path
git config --local --get core.hooksPath

# optional manual cleanup when you want to inspect EOF fixes before staging
git trim-eof
git add .
git commit -m "Apply change"
```

### pre-commit

- Resolves EOF hygiene from `.git/codex-hook-eof-settings.json`, then `%USERPROFILE%\\.codex\\git-hook-eof-settings.json`, then the catalog default
- In `manual` mode:
  - does not trim files automatically
  - continues directly to validation
- In `autofix` mode:
  - trims only currently staged files
  - re-stages them before validation
  - blocks the commit if a file has both staged and unstaged changes, because auto-restaging would be unsafe
- Then runs `scripts/validation/validate-all.ps1`
- Uses `-ValidationProfile dev -WarningOnly true` (best effort)
- Validation itself remains warning-only, but the EOF hygiene step can block the commit in `autofix` mode when automatic cleanup is unsafe or fails

### post-commit

- Runs `scripts/runtime/bootstrap.ps1 -Mirror` (best effort) only when `HEAD` changed runtime-managed source paths under `.github/`, `.codex/`, or `scripts/`
- If the canonical MCP runtime catalog or its generated projections changed in `HEAD`, can optionally apply MCP config
- Runs `scripts/runtime/validate-vscode-global-alignment.ps1` (best effort) only when `HEAD` changed `.vscode/` or the VS Code sync/alignment scripts
- Re-applies safe Codex runtime preferences when runtime-managed source changed (best effort)
- Runs `scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -Apply` (best effort) to clean runtime garbage and stale session/history files that have not been updated for more than **30 days** by **LastWriteTime**; aggressive oversized-file and storage-budget pruning are available only through explicit overrides
- Schedules `scripts/runtime/clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 12` in the background (best effort) to prune stale Copilot workspace state, old VS Code history, old settings backups, and oversized `GitHub.copilot-chat/local-index*.db` files without blocking normal commit flow

### post-merge

- Runs `scripts/validation/validate-all.ps1 -ValidationProfile release -WarningOnly true` (best effort)
- Re-applies safe Codex runtime preferences (best effort)
- Runs `scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -Apply` (best effort) with the same 30-day stale-session retention defaults
- Schedules `scripts/runtime/clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 12` in the background (best effort)
- Does not run runtime sync

### post-checkout

- Runs `scripts/validation/validate-all.ps1 -ValidationProfile dev -WarningOnly true` (best effort)
- Does not run runtime sync

Environment variables:
- `CODEX_SKIP_POST_COMMIT_SYNC=1`: skip runtime sync
- `CODEX_APPLY_MCP_ON_POST_COMMIT=1`: enable MCP apply when canonical MCP runtime surfaces changed
- `CODEX_BACKUP_MCP_CONFIG=1|0`: backup control before MCP apply (`1` default)
- `CODEX_POST_COMMIT_MIRROR=0|1`: controls mirror cleanup on post-commit sync (`1` default)
- `CODEX_SKIP_VSCODE_GLOBAL_CHECK=1`: skips `.vscode` containment check against global VS Code User files in `post-commit`
- `CODEX_VSCODE_GLOBAL_USER_PATH=<path>`: overrides global VS Code User folder used by `post-commit` check
- `CODEX_SKIP_VSCODE_SNIPPET_CHECK=1`: skips snippet containment checks in `post-commit`
- `CODEX_SKIP_RUNTIME_PREFERENCES_APPLY=1`: skip automatic safe Codex runtime preference apply in `post-commit` and `post-merge`
- `CODEX_SKIP_RUNTIME_CLEANUP=1`: skip automatic runtime cleanup in `post-commit` and `post-merge`
- `CODEX_SKIP_VSCODE_RUNTIME_CLEANUP=1`: skip automatic VS Code user-runtime cleanup in `post-commit` and `post-merge`
- `CODEX_LOG_RETENTION_DAYS=<n>`: log retention window in days for automatic runtime cleanup (`14` default from the hygiene catalog, by `LastWriteTime`)
- `CODEX_INCLUDE_SESSIONS_CLEANUP=0|1`: enable cleanup for old session/history files (`1` default)
- `CODEX_SESSION_RETENTION_DAYS=<n>`: retention window for session/history cleanup (`30` default from the hygiene catalog, by `LastWriteTime`)
- `CODEX_MAX_SESSION_FILE_SIZE_MB=<n>`: optional oversized session threshold override (disabled by default)
- `CODEX_OVERSIZED_SESSION_GRACE_HOURS=<n>`: optional grace window paired with `CODEX_MAX_SESSION_FILE_SIZE_MB` (disabled by default)
- `CODEX_MAX_SESSION_STORAGE_GB=<n>`: optional total session storage budget override (disabled by default)
- `CODEX_SESSION_STORAGE_GRACE_HOURS=<n>`: optional grace window paired with `CODEX_MAX_SESSION_STORAGE_GB` (disabled by default)
- `CODEX_VSCODE_RECENT_RUN_WINDOW_HOURS=<n>`: throttle window for automatic VS Code user-runtime cleanup (`12` default)
- `CODEX_VSCODE_WORKSPACE_STORAGE_RETENTION_DAYS=<n>`: stale workspaceStorage directory retention (`30` default)
- `CODEX_VSCODE_CHAT_SESSION_RETENTION_DAYS=<n>`: Copilot chat session retention (`14` default)
- `CODEX_VSCODE_CHAT_EDITING_RETENTION_DAYS=<n>`: chat editing-session retention (`7` default)
- `CODEX_VSCODE_TRANSCRIPT_RETENTION_DAYS=<n>`: Copilot transcript retention (`14` default)
- `CODEX_VSCODE_HISTORY_RETENTION_DAYS=<n>`: VS Code `History` retention (`30` default)
- `CODEX_VSCODE_SETTINGS_BACKUP_RETENTION_DAYS=<n>`: `settings.json.*.bak` / `mcp.json.*.bak` retention (`30` default)
- `CODEX_VSCODE_MAX_CHAT_SESSION_FILE_SIZE_MB=<n>`: oversized Copilot chat session threshold (`128` default)
- `CODEX_VSCODE_MAX_WORKSPACE_INDEX_SIZE_MB=<n>`: oversized `GitHub.copilot-chat/local-index*.db` threshold (`1024` default)
- `CODEX_VSCODE_OVERSIZED_FILE_GRACE_HOURS=<n>`: grace window before oversized VS Code chat/index files become removable (`12` default)

### Enterprise Ops

```powershell
# run end-to-end checks and generate .temp/healthcheck-report.json + logs
pwsh -File ./scripts/runtime/healthcheck.ps1 -StrictExtras

# run full validation suite (instructions, policies, orchestration, docs standards)
pwsh -File ./scripts/validation/validate-all.ps1

# run full suite with release profile
pwsh -File ./scripts/validation/validate-all.ps1 -ValidationProfile release

# validate routing catalog coverage against golden fixtures
pwsh -File ./scripts/validation/validate-routing-coverage.ps1

# validate alignment between agents, skills, pipeline and evals
pwsh -File ./scripts/validation/validate-agent-skill-alignment.ps1

# validate agent permission matrix
pwsh -File ./scripts/validation/validate-agent-permissions.ps1

# validate release governance contracts (CHANGELOG + CODEOWNERS + baseline)
pwsh -File ./scripts/validation/validate-release-governance.ps1

# validate security baseline (sensitive paths + secret-like patterns)
pwsh -File ./scripts/validation/validate-security-baseline.ps1

# validate supply-chain baseline and generate SBOM artifact
pwsh -File ./scripts/validation/validate-supply-chain.ps1

# validate analyzer warning baseline
pwsh -File ./scripts/validation/validate-warning-baseline.ps1

# validate release provenance baseline (checks + evidence + git traceability)
pwsh -File ./scripts/validation/validate-release-provenance.ps1

# validate audit ledger hash chain
pwsh -File ./scripts/validation/validate-audit-ledger.ps1

# validate multi-agent contracts and orchestration integrity
pwsh -File ./scripts/validation/validate-agent-orchestration.ps1

# execute default multi-agent pipeline and generate run artifacts
pwsh -File ./scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate request"

# execute the same pipeline with live sequential planner/executor/reviewer dispatch
pwsh -File ./scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate request" -ExecutionBackend codex-exec

# execute the same pipeline with explicit approval for sensitive agents
pwsh -File ./scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate request" -ExecutionBackend codex-exec -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved implementation and closeout for this run"

# create an isolated Super Agent worktree before risky or parallel work
pwsh -File ./scripts/runtime/new-super-agent-worktree.ps1 -WorktreeName "feature-slice"

# stop after the brainstorm/spec stage
pwsh -File ./scripts/runtime/invoke-super-agent-brainstorm.ps1 -RequestText "Design the workstream"

# stop after planning
pwsh -File ./scripts/runtime/invoke-super-agent-plan.ps1 -RequestText "Write the execution plan"

# run the full lifecycle
pwsh -File ./scripts/runtime/invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan"

# run the full lifecycle with safe parallel batching
pwsh -File ./scripts/runtime/invoke-super-agent-parallel-dispatch.ps1 -RequestText "Execute independent work items"

# run the full lifecycle with explicit approval for sensitive stages
pwsh -File ./scripts/runtime/invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan" -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved full lifecycle execution"

# validate branch protection drift against baseline (no mutation)
pwsh -File ./scripts/governance/set-branch-protection.ps1

# apply branch protection baseline (opt-in remote mutation)
pwsh -File ./scripts/governance/set-branch-protection.ps1 -Apply

# repair runtime and validate final state
pwsh -File ./scripts/runtime/self-heal.ps1 -Mirror -StrictExtras

# clean local Codex runtime garbage and prune sessions using the safe catalog defaults
pwsh -File ./scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -Apply

# preview VS Code user-runtime cleanup
pwsh -File ./scripts/runtime/clean-vscode-user-runtime.ps1 -RecentRunWindowHours 0

# apply VS Code user-runtime cleanup immediately
pwsh -File ./scripts/runtime/clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 0

# export planning continuity and clean only persisted runtime state for the active workspace
pwsh -File ./scripts/runtime/invoke-super-agent-housekeeping.ps1 -WorkspacePath . -Apply

# export consolidated audit report with git metadata and policy inventory
pwsh -File ./scripts/validation/export-audit-report.ps1 -ValidationProfile release -StrictExtras

# export enterprise trends dashboard artifacts
pwsh -File ./scripts/validation/export-enterprise-trends.ps1 -MaxEntries 30

# validate/install audit prerequisites and run security gate
pwsh -File ./scripts/security/Install-SecurityAuditPrerequisites.ps1 -FrontendPackageManager auto
pwsh -File ./scripts/security/Invoke-PreBuildSecurityGate.ps1 -InstallMissingPrerequisites -FailOnSeverities Critical,High
```

Audit logs are generated under `.temp/logs/`.
Validation ledger and SBOM artifacts are generated under `.temp/audit/`.

Notes for VS Code cleanup:
- Hook-driven cleanup runs detached by default so a large `workspaceStorage` backlog does not stall `git commit` or `git pull`.
- Set `CODEX_VSCODE_RUNTIME_CLEANUP_BACKGROUND=0` only when you explicitly want the hook to wait for cleanup completion.
- The manual cleanup command can still take a while when draining a large existing backlog for the first time.

Security and governance observability workflows:
- `.github/workflows/dependency-risk-observability.yml`
- `.github/workflows/enterprise-trends-dashboard.yml`
- `.github/workflows/sbom-attestation-observability.yml`
- `.github/workflows/security-static-observability.yml`

`validate-agent-system.yml` owns push-time audit/healthcheck coverage; `enterprise-trends-dashboard.yml` is reserved for scheduled or manually-triggered trend exports to avoid duplicate `validate-all` runs on every push.

### Issue Templates

The repository provides GitHub issue templates under `.github/ISSUE_TEMPLATE/` to standardize how problems and requests are reported:

| Template | Use when |
| --- | --- |
| `bug-instructions.yml` | An instruction file produces wrong, missing, or inconsistent AI behavior |
| `new-skill-request.yml` | A new skill is needed for Codex or Claude Code |
| `runtime-sync-problem.yml` | Runtime sync, bootstrap, or install is failing or producing stale assets |
| `validation-gap.yml` | A validation rule is missing, incorrect, or producing false positives |

---

## Quick Start

### Recommended (Most Important): Static RAGs Routing

Use a routing step to select a minimal “context pack” before doing any work.

1. **Copy the core files (required):**
   ```bash
   cp .github/AGENTS.md .github/copilot-instructions.md /your/project/.github/
   ```

2. **Copy the routing assets (recommended):**
   ```bash
   cp .github/instruction-routing.catalog.yml /your/project/.github/
   cp .github/prompts/route-instructions.prompt.md /your/project/.github/prompts/
   cp -r .github/schemas/ /your/project/.github/
   ```

3. **Route first, then execute:**
   - Run the route-only prompt `.github/prompts/route-instructions.prompt.md`.
   - Load ONLY the files from the returned Context Pack (mandatory + selected).
   - Execute the task using that minimal context.

### Basic Setup (3 Steps)

1. **Copy core files:**
   ```bash
   cp .github/AGENTS.md .github/copilot-instructions.md /your/project/.github/
   ```

2. **Adapt `.github/AGENTS.md`** for your project structure

3. **Select relevant instructions:**
   ```bash
   # .NET project
   cp .github/instructions/{dotnet-csharp,clean-architecture-code,backend}.instructions.md /your/project/.github/instructions/

   # Rust project
   cp .github/instructions/rust-testing.instructions.md /your/project/.github/instructions/

   # Frontend project
   cp .github/instructions/{frontend,vue-quasar,ui-ux}.instructions.md /your/project/.github/instructions/

   # DevOps
   cp .github/instructions/{docker,k8s,ci-cd-devops}.instructions.md /your/project/.github/instructions/
   ```

### First AI Interaction

```text
# In GitHub Copilot Chat (reference loaded instruction files)
"Refactor following dotnet-csharp.instructions.md conventions"
"Generate Rust tests using rust-testing.instructions.md patterns"
"Review architecture compliance per clean-architecture-code.instructions.md"
```

---

## Usage Examples

### Code Refactoring (.NET)

```text
"Refactor to C# 12 with sealed classes and file-scoped namespaces per dotnet-csharp.instructions.md"
```

### Test Generation (Rust)

```text
"Generate async tests for this module following rust-testing.instructions.md patterns"
```

### Architecture Review

```text
@clean-architecture-review "Analyze this service for SOLID violations"
```

### Component Generation (Vue)

```text
"Create Quasar component with Composition API per vue-quasar.instructions.md"
```

### Using Prompt Templates

```text
# Reference .github/prompts/generate-unit-tests.prompt.md
"Generate xUnit tests for OrderService with AAA pattern and mocking"
```

---

## Chat Modes

### clean-architecture-review.chatmode.md

Specialized mode for reviewing code against Clean Architecture principles.

**Capabilities:**
- SOLID principles validation
- Dependency rule enforcement
- Layer boundary verification
- Code smell detection

**Usage:**
```text
@clean-architecture-review "Analyze this repository structure and identify violations"
```

### instruction-writer.chatmode.md

Specialized mode for creating new instruction files following meta-conventions.

**Capabilities:**
- Instruction file scaffolding
- Consistency with existing instructions
- Best practice enforcement
- Automatic formatting

**Usage:**
```text
@instruction-writer "Create instruction file for gRPC service development"
```

---

## Prompt Templates

### Standard Templates (Markdown-based)

Located in `.github/prompts/`:
- **create-dotnet-class.prompt.md** - Generate Clean Architecture compliant classes
- **create-powershell-script.prompt.md** - Generate `scripts/*` PowerShell automation with safe defaults
- **generate-changelog.prompt.md** - Create semantic versioning CHANGELOG entries
- **generate-unit-tests.prompt.md** - Generate comprehensive xUnit/NUnit tests

### POML Templates (XML-based)

Located in `.github/prompts/poml/templates/`:
- **changelog-entry.poml** - Structured CHANGELOG generator with versioning
- **unit-test-generator.poml** - AAA pattern test generator with mocking

**Learn more:** [POML Guide](./.github/prompts/poml/prompt-engineering-poml.md)

---

## API Reference

### Core Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `.github/AGENTS.md` | Agent policies, workflow patterns, context selection rules | Always load FIRST — all runtimes |
| `.github/copilot-instructions.md` | Global rules, domain mapping, routing, language policy | Always load SECOND — Copilot and Codex sessions |
| `CLAUDE.md` | Claude Code workspace adapter, agent type mapping, memory policy | Loaded automatically by Claude Code at workspace open |

### Instruction Files (43 total)

All instruction files live under `.github/instructions/`. Select only the pack relevant to the task — see `.github/instruction-routing.catalog.yml` for the routing rules.

| Domain | Files |
|--------|-------|
| **.NET / C# / Backend** | `dotnet-csharp`, `clean-architecture-code`, `backend`, `api-high-performance-security`, `microservices-performance`, `nettoolskit-rules` |
| **Database / ORM** | `database`, `orm`, `database-configuration-operations` |
| **Frontend / Vue / Quasar** | `frontend`, `vue-quasar`, `vue-quasar-architecture`, `ui-ux` |
| **Rust** | `rust-code-organization`, `rust-testing` |
| **PowerShell / Scripts** | `powershell-execution`, `powershell-script-creation` |
| **Infrastructure / CI-CD** | `ci-cd-devops`, `docker`, `k8s`, `workflow-generation` |
| **Security / Compliance** | `security-vulnerabilities`, `data-privacy-compliance` |
| **Observability / SRE** | `observability-sre`, `platform-reliability-resilience` |
| **Testing** | `tdd-verification`, `e2e-testing`, `static-analysis-sonarqube` |
| **Documentation / Release** | `readme`, `pr`, `feedback-changelog`, `prompt-templates`, `copilot-instruction-creation`, `effort-estimation-ucp` |
| **VS Code / Workspace** | `vscode-workspace-efficiency`, `workflow-optimization` |
| **Super Agent / Orchestration** | `super-agent`, `brainstorm-spec-workflow`, `subagent-planning-workflow`, `worktree-isolation`, `artifact-layout`, `authoritative-sources`, `repository-operating-model` |

### Context Selection Rule (Hard Requirement)

**Always load FIRST in any Copilot Chat session:**
1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`

This ensures consistent agent behavior and proper context hierarchy.

### Static RAGs Routing

If you want a RAGs-style routing step (selecting a minimal “context pack” before execution), use:
- `.github/instruction-routing.catalog.yml` (single source of truth for routes)
- `.github/prompts/route-instructions.prompt.md` (route-only prompt that outputs a JSON context pack)

---

## Dependencies

### Runtime Dependencies
None. This is a documentation and policy repository.

### Development Dependencies
- **GitHub Copilot** (or compatible AI coding assistant)
- **VS Code** with Copilot Chat extension
- **Git** for version control

### Optional Dependencies
- **POML CLI** (`npm install -g @microsoft/poml-cli`) for POML template rendering
- **Language SDKs** (.NET SDK, Rust toolchain, Node.js) depending on your project stack

---

## References

### Official Documentation

- [GitHub Copilot Documentation](https://docs.github.com/en/copilot) - Complete Copilot reference
- [VS Code Copilot Tips](https://code.visualstudio.com/docs/copilot/copilot-tips-and-tricks) - Best practices and shortcuts
- [VS Code Prompt Crafting](https://code.visualstudio.com/docs/copilot/chat/prompt-crafting) - Effective prompt engineering
- [Custom Instructions Guide](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions) - Repository-level instructions

### Best Practices & Articles

- [Microsoft DevBlogs: 5 Copilot Chat Prompts .NET Devs Should Steal](https://devblogs.microsoft.com/dotnet/5-copilot-chat-prompts-dotnet-devs-should-steal-today/) - Practical .NET prompts
- [Dev.to: Supercharge VSCode Copilot](https://dev.to/pwd9000/supercharge-vscode-github-copilot-using-instructions-and-prompt-files-2p5e) - Advanced instruction techniques
- [GitHub Copilot Troubleshooting](https://docs.github.com/copilot/troubleshooting-github-copilot/troubleshooting-common-issues-with-github-copilot) - Common issues and solutions

### Standards & Specifications

- [Microsoft POML](https://github.com/microsoft/poml) - Prompt Orchestration Markup Language
- [Keep a Changelog](https://keepachangelog.com/) - Changelog format standard
- [Semantic Versioning](https://semver.org/) - Version numbering convention
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message convention

### Internal Documentation

- [CHANGELOG](./CHANGELOG.md) - Version history
- [COMPATIBILITY](./COMPATIBILITY.md) - Support lifecycle and EOL policy
- [CONTRIBUTING](./CONTRIBUTING.md) - Contribution workflow and validation guidance

---

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

---