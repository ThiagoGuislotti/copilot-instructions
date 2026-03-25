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
- ✅ Multi-agent pipeline runner with guardrails, deterministic stage handoffs, and optional live `codex-exec` dispatch
- ✅ Task-loop implementation with per-task spec review and code-quality review
- ✅ Safe parallel batching for dependency-independent work items with write-set conflict blocking
- ✅ Super Agent worktree isolation helper and thin lifecycle entry commands
- ✅ Single picker-visible `super-agent` controller projected into `%USERPROFILE%\\.agents\\skills`
- ✅ Legacy starter cleanup in `%USERPROFILE%\\.github\\skills` and `%USERPROFILE%\\.copilot\\skills` so the shared `super-agent` controller remains canonical
- ✅ Repository-owned Copilot agent profile under `.github/agents/super-agent.agent.md` with a non-canonical alias so `/super-agent` stays unique
- ✅ Configurable VS Code startup-controller selector with repository default plus local and environment overrides
- ✅ Repository-owned PreToolUse EOF normalization for supported VS Code AI edit tools
- ✅ Repository-owned TDD and verification workflow contracts for execution stages
- ✅ Persisted orchestration run state for replay diagnostics and auditability
- ✅ Release governance checks (CODEOWNERS, changelog contracts, branch-protection baseline)
- ✅ Security baseline checks (sensitive file patterns and secret-like content scanning)
- ✅ Shared script checksum manifest governance for external workflow integrity
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
# run the full recommended local onboarding flow
$RepoRoot = '<REPO_ROOT>'
pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# Sync shared assets
pwsh -File .\scripts\runtime\bootstrap.ps1

# Sync and apply MCP servers into ~/.codex/config.toml
pwsh -File .\scripts\runtime\bootstrap.ps1 -ApplyMcpConfig -BackupConfig

# Run full enterprise healthcheck
pwsh -File .\scripts\runtime\healthcheck.ps1 -StrictExtras

# Execute default multi-agent pipeline (writes artifacts to .temp/runs)
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Validate enterprise multi-agent flow"

# Execute the same pipeline through the live Codex backend
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Validate enterprise multi-agent flow" -ExecutionBackend codex-exec

# Approve sensitive agents explicitly for a live run
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Validate enterprise multi-agent flow" -ExecutionBackend codex-exec -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved sensitive pipeline stages"

# Create an isolated worktree before risky or multi-slice execution
pwsh -File .\scripts\runtime\new-super-agent-worktree.ps1 -WorktreeName "feature-slice"

# Stop after brainstorm/spec
pwsh -File .\scripts\runtime\invoke-super-agent-brainstorm.ps1 -RequestText "Design the workstream"

# Stop after planning
pwsh -File .\scripts\runtime\invoke-super-agent-plan.ps1 -RequestText "Write the execution plan"

# Execute the full lifecycle
pwsh -File .\scripts\runtime\invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan"

# Execute the full lifecycle and allow safe parallel worker fan-out
pwsh -File .\scripts\runtime\invoke-super-agent-parallel-dispatch.ps1 -RequestText "Implement independent work items"

# Execute the full lifecycle with explicit approval for sensitive stages
pwsh -File .\scripts\runtime\invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan" -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved implementation and closeout"

# Enable local Git hooks (pre-commit + post-commit sync)
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1

# Enable local Git hooks and opt this clone into automatic staged EOF cleanup
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope local-repo
```

The installer does not require the current shell to be in the repository root. If `pwsh -File` points to the versioned `install.ps1` path, the script resolves the repository root from its own location. Use `-RepoRoot` only when you need to override that auto-detection.

The installer now uses a versioned runtime profile catalog at `.github/governance/runtime-install-profiles.json`.

- `none` is the default profile for `install.ps1`
- `none` means the installer does not mutate runtime folders, VS Code globals, or Git configuration
- `all` now renders both the global VS Code `settings.json` and the global VS Code `mcp.json` from the tracked `.vscode/*.tamplate.jsonc` files
- Codex-enabled install profiles also apply safe local Codex runtime preferences by default: `model_reasoning_effort = "high"` and `[features].multi_agent = true`
- Those defaults preserve multi-agent availability, but the repository-owned Super Agent workflow remains responsible for calling subagents strategically instead of using fan-out for trivial work.
- `bootstrap.ps1`, `doctor.ps1`, `healthcheck.ps1`, and `self-heal.ps1` still default to `all` when called directly

Supported install profiles:

| Profile | Behavior |
| --- | --- |
| `none` | Default. No runtime projection or editor/Git integration changes. |
| `github` | Only sync `githubRuntimeRoot`, its mirrored `scripts/`, and cleanup of legacy duplicate starters under `githubRuntimeRoot/skills` plus `copilotSkillsRoot`. |
| `codex` | Only sync `agentsSkillsRoot` plus `codexRuntimeRoot/shared-*`. |
| `all` | Sync both runtime surfaces and also apply global VS Code settings/snippets, local Git hooks, global Git aliases, and installer healthcheck. |

Runtime locations are centralized through:

- versioned defaults: `.github/governance/runtime-location-catalog.json`
- optional machine-local overrides: `${HOME}/.codex/runtime-location-settings.json`
- shared resolver: `scripts/common/runtime-paths.ps1`

Machine-local override example:

```json
{
  "schemaVersion": 1,
  "paths": {
    "githubRuntimeRoot": "D:/ai-runtime/.github",
    "codexRuntimeRoot": "D:/ai-runtime/.codex",
    "agentsSkillsRoot": "D:/ai-runtime/.agents/skills",
    "copilotSkillsRoot": "D:/ai-runtime/.copilot/skills",
    "codexGitHooksRoot": "D:/ai-runtime/.codex/git-hooks"
  }
}
```

Examples:

```powershell
# default non-intrusive preview
pwsh -File .\scripts\runtime\install.ps1 -PreviewOnly

# only GitHub/Copilot runtime assets
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile github

# only Codex runtime assets
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile codex -ApplyMcpConfig -BackupMcpConfig

# full onboarding
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# full onboarding with explicit safer Codex runtime overrides
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -CodexReasoningEffort medium -CodexMultiAgentMode disabled -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# full onboarding plus intrusive EOF autofix on pre-commit
# if scope is omitted, install asks whether this should be global and defaults to local-repo when you answer no
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -GitHookEofMode autofix -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig

# full onboarding plus explicit global EOF autofix
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -GitHookEofMode autofix -GitHookEofScope global -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig
```

When the managed global VS Code settings template is applied, Copilot Chat is
kept on a safer default profile for long-running sessions:
- `chat.agent.maxRequests = 100`
- `chat.emptyState.history.enabled = false`
- `chat.restoreLastPanelSession = false`

When the managed global VS Code MCP template is applied:
- `%APPDATA%\\Code\\User\\mcp.json` is rendered from `.github/governance/mcp-runtime.catalog.json` via the tracked `.vscode/mcp.tamplate.jsonc` projection
- `.vscode/mcp-vscode-global.json` is refreshed as an ignored local helper mirror
- stable `${input:...}` ids let VS Code keep MCP credentials in its secure store after the first prompt instead of reauthenticating on every conversation

The VS Code hook bootstrap selects its startup controller from `.github/hooks/super-agent.selector.json`. Keep the repository default in version control and override locally only through `~/.github/hooks/super-agent.selector.local.json` or the environment variables `COPILOT_SUPER_AGENT_SKILL` and `COPILOT_SUPER_AGENT_NAME`.

Operational scripts now follow a shared execution-session contract:

- default mode stays concise and always emits a deterministic `Session start` / `Session end`
- default mode keeps only necessary progress, failures, and final summaries
- verbose mode expands session metadata and script-specific diagnostics
- supported detail switches are standardized to one of:
  - `-Verbose`
  - `-DetailedLogs`
  - `-DetailedOutput`

Use this contract as the user-facing baseline for every operational entrypoint:

- default run:
  - prints `Session start`
  - prints only necessary progress lines
  - prints warnings/errors
  - prints the final summary
  - prints `Session end`
- detailed run:
  - keeps the same start/end markers
  - adds script-specific diagnostics, resolved paths, and child-script detail
- helper and test scripts may stay internal, but top-level operational entrypoints must expose one of the standardized detail switches above

Super Agent and orchestration-facing entrypoints also follow a quality-first output-economy rule:

- default output stays concise and should avoid repeating the same status in stage summaries, review notes, closeout text, and final completion text
- detailed artifact narration belongs in `-DetailedOutput`, `-Verbose`, or explicit troubleshooting runs
- token reduction must come from less duplicated output first, not from trimming required execution context by default

### Execution Session Examples

#### Default concise runs

```powershell
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all
pwsh -File .\scripts\runtime\bootstrap.ps1
pwsh -File .\scripts\runtime\healthcheck.ps1
pwsh -File .\scripts\validation\validate-all.ps1 -ValidationProfile dev
pwsh -File .\scripts\maintenance\trim-trailing-blank-lines.ps1 -GitChangedOnly
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1
```

#### Verbose runtime diagnostics

```powershell
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -Verbose
pwsh -File .\scripts\runtime\bootstrap.ps1 -Verbose
pwsh -File .\scripts\runtime\doctor.ps1 -Verbose
pwsh -File .\scripts\runtime\healthcheck.ps1 -Verbose
pwsh -File .\scripts\runtime\self-heal.ps1 -Verbose
pwsh -File .\scripts\runtime\sync-vscode-global-settings.ps1 -Verbose
pwsh -File .\scripts\runtime\sync-vscode-global-mcp.ps1 -Verbose
pwsh -File .\scripts\runtime\sync-vscode-global-snippets.ps1 -Verbose
pwsh -File .\scripts\runtime\sync-workspace-settings.ps1 -Verbose
```

#### Detailed orchestration diagnostics

```powershell
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Smoke run" -DetailedOutput
pwsh -File .\scripts\runtime\resume-agent-pipeline.ps1 -RunDirectory .\.temp\runs\<traceId> -DetailedOutput
pwsh -File .\scripts\runtime\replay-agent-run.ps1 -RunDirectory .\.temp\runs\<traceId> -DetailedOutput
pwsh -File .\scripts\runtime\evaluate-agent-pipeline.ps1 -OutputPath .\.temp\agent-evals\pipeline-scorecard.json -DetailedOutput
pwsh -File .\scripts\runtime\invoke-super-agent-brainstorm.ps1 -RequestText "Design the workstream" -DetailedOutput
pwsh -File .\scripts\runtime\invoke-super-agent-plan.ps1 -RequestText "Write the execution plan" -DetailedOutput
pwsh -File .\scripts\runtime\invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan" -DetailedOutput
pwsh -File .\scripts\runtime\invoke-super-agent-parallel-dispatch.ps1 -RequestText "Implement independent work items" -DetailedOutput
pwsh -File .\scripts\runtime\new-super-agent-worktree.ps1 -WorktreeName "feature-slice" -DetailedOutput
pwsh -File .\scripts\runtime\clean-codex-runtime.ps1 -DetailedOutput
pwsh -File .\scripts\runtime\invoke-super-agent-housekeeping.ps1 -WorkspacePath . -DetailedOutput
```

#### Concise orchestration defaults

Default orchestration runs should keep the operator-facing output short:

- one stable outcome summary
- one validation status block
- blockers or next steps only when they exist
- no repeated restatement of request, plan, review, and closeout content when artifact paths already exist

Example concise completion:

```text
- updated route/review prompts
- validation: passed `validate-all`
- install: passed `install.ps1 -RuntimeProfile all`
```

Example detailed completion on demand:

```text
- outcome
- changed files
- validation evidence
- residual risks
- optional next steps
```

#### Validation diagnostics

```powershell
pwsh -File .\scripts\validation\validate-all.ps1 -ValidationProfile dev -Verbose
pwsh -File .\scripts\validation\validate-runtime-script-tests.ps1 -Verbose
pwsh -File .\scripts\validation\validate-readme-standards.ps1 -Verbose
pwsh -File .\scripts\validation\validate-powershell-standards.ps1 -Verbose
pwsh -File .\scripts\validation\validate-agent-hooks.ps1 -Verbose
pwsh -File .\scripts\validation\validate-planning-structure.ps1 -Verbose
pwsh -File .\scripts\validation\validate-shared-script-checksums.ps1 -DetailedOutput
pwsh -File .\scripts\validation\validate-instruction-architecture.ps1 -DetailedOutput
pwsh -File .\scripts\validation\validate-authoritative-source-policy.ps1 -DetailedOutput
pwsh -File .\scripts\validation\validate-workspace-efficiency.ps1 -DetailedOutput
```

#### Security and maintenance diagnostics

```powershell
pwsh -File .\scripts\security\Invoke-VulnerabilityAudit.ps1 -DetailedLogs
pwsh -File .\scripts\security\Install-SecurityAuditPrerequisites.ps1 -DetailedLogs
pwsh -File .\scripts\security\Invoke-FrontendPackageVulnerabilityAudit.ps1 -DetailedLogs
pwsh -File .\scripts\security\Invoke-RustPackageVulnerabilityAudit.ps1 -DetailedLogs
pwsh -File .\scripts\security\Invoke-PreBuildSecurityGate.ps1 -DetailedLogs
pwsh -File .\scripts\security\Invoke-CiPreBuildSecuritySnapshot.ps1 -Verbose
pwsh -File .\scripts\maintenance\trim-trailing-blank-lines.ps1 -GitChangedOnly -Verbose
pwsh -File .\scripts\maintenance\clean-build-artifacts.ps1 -Verbose
pwsh -File .\scripts\maintenance\fix-version-ranges.ps1 -Verbose
```

#### Git hook and alias diagnostics

```powershell
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1 -Verbose
pwsh -File .\scripts\git-hooks\setup-global-git-aliases.ps1 -Verbose
pwsh -File .\scripts\git-hooks\invoke-pre-commit-eof-hygiene.ps1 -Verbose
```

#### Expected default output shape

```text
Session start: Runtime install
[STEP] Bootstrap shared runtime assets
[OK] Bootstrap shared runtime assets
[STEP] Run repository healthcheck
[OK] Run repository healthcheck
Runtime install summary
  Overall status: passed
Session end: Runtime install
```

#### Expected detailed output shape

```text
Session start: Runtime healthcheck
[INFO] Repo root: C:\repo
[INFO] Runtime profile: all
[INFO] Output report: C:\repo\.temp\healthcheck-report.json
[INFO] Starting check: validate-all
...
Healthcheck summary
  Passed checks: 2
  Failed checks: 0
Session end: Runtime healthcheck
```

#### Switch map by script family

| Script family | Standard detail switch | Notes |
| --- | --- | --- |
| `scripts/runtime/*.ps1` | Usually `-Verbose`; orchestration/replay/eval entrypoints use `-DetailedOutput` where the output is artifact-heavy. | Default mode still prints the same session markers and summary. |
| `scripts/validation/*.ps1` | Usually `-Verbose`; governance validators with artifact/path-heavy inspection may also expose `-DetailedOutput`. | Default mode stays concise to keep hook/CI output readable. |
| `scripts/security/*.ps1` | Usually `-DetailedLogs`; some support `-Verbose`. | Use detailed logs when the script shells out to scanners or package managers. |
| `scripts/maintenance/*.ps1` | Usually `-Verbose`. | Default mode should stay safe for routine cleanup runs. |
| `scripts/git-hooks/*.ps1` | Usually `-Verbose`. | Helpful when debugging `core.hooksPath`, local/global scope, or staged-file EOF handling. |

#### Practical guidance

- use default mode in normal day-to-day runs, hooks, and onboarding
- use `-Verbose` when you need resolved paths, extra progress lines, or child-step detail
- use `-DetailedLogs` for vulnerability/security flows that shell out to external scanners
- use `-DetailedOutput` for orchestration, replay, evaluation, and artifact-heavy validators
- if a script is called from another script, keep the parent concise by default and opt in to detail explicitly only when debugging
- session markers are deterministic by design so hook logs and CI output stay easy to scan

Short examples:

```powershell
pwsh -File .\scripts\runtime\healthcheck.ps1 -Verbose
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Smoke run" -DetailedOutput
pwsh -File .\scripts\security\Invoke-VulnerabilityAudit.ps1 -DetailedLogs
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
│   ├── install.ps1
│   ├── apply-vscode-templates.ps1
│   ├── new-super-agent-worktree.ps1
│   ├── sync-vscode-global-mcp.ps1
│   ├── sync-vscode-global-snippets.ps1
│   ├── sync-workspace-settings.ps1
│   ├── invoke-super-agent-brainstorm.ps1
│   ├── invoke-super-agent-plan.ps1
│   ├── invoke-super-agent-execute.ps1
│   ├── invoke-super-agent-parallel-dispatch.ps1
│   ├── invoke-super-agent-housekeeping.ps1
│   ├── healthcheck.ps1
│   ├── self-heal.ps1
│   ├── run-agent-pipeline.ps1
│   ├── clean-codex-runtime.ps1
│   └── export-planning-summary.ps1
├── orchestration/
│   ├── engine/
│   │   ├── invoke-codex-dispatch.ps1
│   │   └── invoke-task-worker.ps1
│   └── stages/
│       ├── intake-stage.ps1
│       ├── spec-stage.ps1
│       ├── plan-stage.ps1
│       ├── route-stage.ps1
│       ├── implement-stage.ps1
│       ├── validate-stage.ps1
│       ├── review-stage.ps1
│       └── closeout-stage.ps1
├── governance/
│   ├── set-branch-protection.ps1
│   └── update-shared-script-checksums-manifest.ps1
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

`runtime/bootstrap.ps1` is profile-aware and runtime-location-aware:
- default direct behavior: `-RuntimeProfile all`
- `-RuntimeProfile github` syncs only:
  - `.github/` -> `githubRuntimeRoot`
  - `scripts/` -> `githubRuntimeRoot/scripts`
  - legacy duplicate starter folders are removed from `githubRuntimeRoot/skills` and `copilotSkillsRoot`
  - the repo-owned Copilot agent profile still syncs into `githubRuntimeRoot/agents`, but with a secondary alias that does not compete with `/super-agent`
- `-RuntimeProfile codex` syncs only:
  - `.codex/skills/` -> `agentsSkillsRoot`
  - stale repo-managed duplicates are removed from `codexRuntimeRoot/skills` while unmanaged/system skill folders are preserved
  - `.codex/mcp/` -> `codexRuntimeRoot/shared-mcp`
  - `.codex/scripts/` (root MCP tools) + `scripts/common/` + `scripts/security/` + `scripts/maintenance/` -> `codexRuntimeRoot/shared-scripts`
  - `.codex/orchestration/` -> `codexRuntimeRoot/shared-orchestration`
- `-RuntimeProfile none` performs no runtime projection and is mainly useful for install preview/testing

MCP apply mode updates only `[mcp_servers.*]` sections in `codexRuntimeRoot/config.toml`, preserving the rest.

Runtime-sensitive files such as `codexRuntimeRoot/auth.json`, `codexRuntimeRoot/sessions/`, and `codexRuntimeRoot/log/` are not managed.

### Utility Scripts

| Script | Purpose | Quick example |
|--------|---------|---------------|
| `deploy/deploy-backend-to-vps.ps1` | Interactive Docker deployment pipeline for VPS hosts. | `& .\scripts\deploy\deploy-backend-to-vps.ps1 @params` |
| `doc/validate-xml-documentation.ps1` | Audits `<summary>` XML documentation across C# projects. | `pwsh -File scripts/doc/validate-xml-documentation.ps1 -ProjectPath src/Api` |
| `validation/validate-instructions.ps1` | Validates instruction assets (routing catalog paths, markdown links, and JSON files used by prompts/skills/snippets). | `pwsh -File scripts/validation/validate-instructions.ps1` |
| `validation/validate-agent-orchestration.ps1` | Validates multi-agent contracts (`.codex/orchestration/*`) against schemas and cross-file integrity rules. | `pwsh -File scripts/validation/validate-agent-orchestration.ps1` |
| `validation/validate-planning-structure.ps1` | Validates the versioned planning workspace under `planning/`, including required folders, README, and legacy `.temp/planning` drift detection. | `pwsh -File scripts/validation/validate-planning-structure.ps1 -RepoRoot .` |
| `validation/validate-policy.ps1` | Validates policy contracts declared in `.github/policies/*.json` (required files/directories/hooks). | `pwsh -File scripts/validation/validate-policy.ps1` |
| `validation/validate-release-governance.ps1` | Validates release-governance baseline (`CHANGELOG`, `CODEOWNERS`, branch-protection baseline, governance docs). | `pwsh -File scripts/validation/validate-release-governance.ps1` |
| `validation/validate-readme-standards.ps1` | Validates README structure/formatting using `.github/governance/readme-standards.baseline.json`. | `pwsh -File scripts/validation/validate-readme-standards.ps1` |
| `validation/validate-authoritative-source-policy.ps1` | Validates the centralized official-doc policy, the stack-to-domain map in `.github/governance/authoritative-source-map.json`, and required references from global instruction files and routing. | `pwsh -File scripts/validation/validate-authoritative-source-policy.ps1` |
| `validation/validate-instruction-architecture.ps1` | Validates ownership boundaries between the global core, repository operating model, domain instructions, prompts, templates, skills, and runtime/orchestration assets, including global-core size budgets and deterministic routing constraints. | `pwsh -File scripts/validation/validate-instruction-architecture.ps1` |
| `validation/validate-template-standards.ps1` | Validates shared templates against `.github/governance/template-standards.baseline.json`, including required/forbidden patterns and referenced script/doc paths. | `pwsh -File scripts/validation/validate-template-standards.ps1` |
| `validation/validate-workspace-efficiency.ps1` | Validates `.code-workspace` files against `.github/governance/workspace-efficiency.baseline.json` using the effective combination of global template plus local workspace overrides. Covers redundant settings, Git throttling, watcher/search inheritance, and multi-folder heuristics for Codex/Copilot usage. | `pwsh -File scripts/validation/validate-workspace-efficiency.ps1 -WorkspaceSearchRoot .\workspaces` |
| `validation/validate-compatibility-lifecycle-policy.ps1` | Validates `COMPATIBILITY.md` Support Lifecycle/EOL table semantics (reference date, ordering, EOL + 1 day, status). | `pwsh -File scripts/validation/validate-compatibility-lifecycle-policy.ps1` |
| `validation/validate-powershell-standards.ps1` | Validates `scripts/**/*.ps1` for script help coverage, per-parameter `.PARAMETER` entries, function description comments, approved verbs, and tracked line-ending normalization. | `pwsh -File scripts/validation/validate-powershell-standards.ps1` |
| `validation/validate-shell-hooks.ps1` | Validates `.githooks/*` shell syntax with `sh -n` and optional `shellcheck`. | `pwsh -File scripts/validation/validate-shell-hooks.ps1` |
| `validation/validate-agent-hooks.ps1` | Validates repository-owned VS Code hook JSON and required bootstrap scripts under `.github/hooks/`. | `pwsh -File scripts/validation/validate-agent-hooks.ps1 -WarningOnly:$false` |
| `validation/validate-runtime-script-tests.ps1` | Runs runtime test scripts under `scripts/tests/runtime` without external test frameworks and replays child test diagnostics only when verbose mode is enabled or a test fails. | `pwsh -File scripts/validation/validate-runtime-script-tests.ps1` |
| `validation/validate-dotnet-standards.ps1` | Validates .NET template standards under `.github/templates/*.cs`. | `pwsh -File scripts/validation/validate-dotnet-standards.ps1` |
| `validation/validate-architecture-boundaries.ps1` | Validates architecture boundaries from `.github/governance/architecture-boundaries.baseline.json`. | `pwsh -File scripts/validation/validate-architecture-boundaries.ps1` |
| `validation/validate-instruction-metadata.ps1` | Validates frontmatter metadata for `.github/instructions`, `.github/prompts`, and `.github/chatmodes`. | `pwsh -File scripts/validation/validate-instruction-metadata.ps1` |
| `validation/validate-routing-coverage.ps1` | Validates route coverage between `instruction-routing.catalog.yml` and golden fixtures. | `pwsh -File scripts/validation/validate-routing-coverage.ps1` |
| `validation/validate-agent-skill-alignment.ps1` | Validates consistency among agent manifest, skills, pipeline stages, and eval requiredAgents. | `pwsh -File scripts/validation/validate-agent-skill-alignment.ps1` |
| `validation/validate-agent-permissions.ps1` | Validates alignment between agent contracts and `.github/governance/agent-skill-permissions.matrix.json`. | `pwsh -File scripts/validation/validate-agent-permissions.ps1` |
| `validation/validate-security-baseline.ps1` | Validates `.github/governance/security-baseline.json` (required governance paths, forbidden sensitive files, and secret-like pattern scanning). Runs in warning-only mode by default. | `pwsh -File scripts/validation/validate-security-baseline.ps1` |
| `validation/validate-shared-script-checksums.ps1` | Validates `.github/governance/shared-script-checksums.manifest.json` against current files under configured script roots. | `pwsh -File scripts/validation/validate-shared-script-checksums.ps1` |
| `validation/validate-warning-baseline.ps1` | Validates PSScriptAnalyzer warning volume against `.github/governance/warning-baseline.json`. | `pwsh -File scripts/validation/validate-warning-baseline.ps1` |
| `validation/validate-supply-chain.ps1` | Validates dependency manifests against `.github/governance/supply-chain.baseline.json` and exports local SBOM artifact. | `pwsh -File scripts/validation/validate-supply-chain.ps1` |
| `validation/validate-release-provenance.ps1` | Validates release provenance baseline (`requiredValidationChecks`, `requiredEvidenceFiles`, changelog recency, git traceability, optional audit report). Runs in warning-only mode by default. | `pwsh -File scripts/validation/validate-release-provenance.ps1` |
| `validation/validate-audit-ledger.ps1` | Validates `.temp/audit/validation-ledger.jsonl` hash-chain integrity. | `pwsh -File scripts/validation/validate-audit-ledger.ps1` |
| `validation/validate-all.ps1` | Runs full profile-based suite, warning-only by default, appends hash-chained ledger evidence, and emits performance report at `.temp/audit/validate-all.latest.json`. | `pwsh -File scripts/validation/validate-all.ps1 -ValidationProfile dev` |
| `validation/export-audit-report.ps1` | Runs health baseline and exports consolidated JSON audit report with git metadata and policy inventory. | `pwsh -File scripts/validation/export-audit-report.ps1` |
| `validation/export-enterprise-trends.ps1` | Exports trends dashboard artifacts (`warnings`, `vulnerabilities`, and validation performance) from ledger + latest reports. | `pwsh -File scripts/validation/export-enterprise-trends.ps1` |
| `validation/test-routing-selection.ps1` | Runs deterministic golden tests for static routing behavior based on catalog + fixtures. | `pwsh -File scripts/validation/test-routing-selection.ps1` |
| `governance/set-branch-protection.ps1` | Validates or applies branch protection from `.github/governance/branch-protection.baseline.json` using GitHub CLI. | `pwsh -File scripts/governance/set-branch-protection.ps1 -Apply` |
| `governance/update-shared-script-checksums-manifest.ps1` | Regenerates `.github/governance/shared-script-checksums.manifest.json` with deterministic SHA256 entries for shared script roots. | `pwsh -File scripts/governance/update-shared-script-checksums-manifest.ps1` |
| `git-hooks/setup-git-hooks.ps1` | Configures Git hooks in either repo-local or machine-global scope. `local-repo` sets `core.hooksPath=.githooks` and enables the repository-owned `pre-commit` validation plus `post-commit` sync. `global` persists EOF settings under `%USERPROFILE%\\.codex\\git-hook-eof-settings.json`, installs a managed machine-wide `pre-commit` hook under `%USERPROFILE%\\.codex\\git-hooks`, and sets `git config --global core.hooksPath` so the global hook path is authoritative unless a repo defines its own local override. | `pwsh -File scripts/git-hooks/setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope global` |
| `git-hooks/setup-global-git-aliases.ps1` | Configures manual global Git aliases for runtime-synced helper scripts. Currently installs `git trim-eof`, which runs the shared trim script in `-GitChangedOnly` mode before `git add` when you want manual EOF cleanup in any repository. | `pwsh -File scripts/git-hooks/setup-global-git-aliases.ps1` |
| `common/common-bootstrap.ps1` | Shared helper-loader bootstrap that resolves and imports `console-style`, `repository-paths`, `git-hook-eof-settings`, `runtime-paths`, `codex-runtime-hygiene`, `runtime-execution-context`, `runtime-operation-support`, `runtime-install-profiles`, `mcp-runtime-catalog`, `local-context-index`, and `validation-logging` from repository and mirrored runtime layouts. | `. ./scripts/common/common-bootstrap.ps1 -CallerScriptRoot $PSScriptRoot -Helpers @('console-style','repository-paths')` |
| `common/codex-runtime-hygiene.ps1` | Shared Codex runtime hygiene helper that resolves `.github/governance/codex-runtime-hygiene.catalog.json` and exposes safe local defaults for reasoning effort, multi-agent mode, and session/log cleanup thresholds. | `. ./scripts/common/codex-runtime-hygiene.ps1; Get-CodexRuntimeHygieneSettings -ResolvedRepoRoot .` |
| `common/git-hook-eof-settings.ps1` | Shared EOF hygiene mode helper that resolves `.github/governance/git-hook-eof-modes.json`, persists local-repo or global selections, and returns the effective mode on every commit with precedence `local-repo -> global -> default`. | `. ./scripts/common/git-hook-eof-settings.ps1; Get-EffectiveGitHookEofMode -ResolvedRepoRoot .` |
| `common/mcp-runtime-catalog.ps1` | Shared MCP runtime-catalog helper that resolves `.github/governance/mcp-runtime.catalog.json` and renders the full VS Code projection plus the generated Codex subset without losing richer VS Code-only metadata such as `disabled`, `gallery`, `version`, `env`, and auth inputs. | `. ./scripts/common/mcp-runtime-catalog.ps1; Read-McpRuntimeCatalog -RepoRoot .` |
| `common/local-context-index.ps1` | Shared local RAG/CAG helper that resolves `.github/governance/local-context-index.catalog.json`, builds deterministic chunks, persists `.temp/context-index/index.json`, and scores local retrieval hits for safe continuity reuse. | `. ./scripts/common/local-context-index.ps1; Read-LocalContextIndexCatalog -RepoRoot .` |
| `common/runtime-paths.ps1` | Shared runtime location helper that resolves `.github/governance/runtime-location-catalog.json`, optional machine-local overrides, and effective cross-platform runtime targets for `.github`, `.codex`, `.agents`, `.copilot`, and managed global Git hooks. | `. ./scripts/common/runtime-paths.ps1; Get-EffectiveRuntimeLocations` |
| `common/runtime-execution-context.ps1` | Shared runtime execution contract helper that resolves repo root, runtime profile, effective runtime locations, canonical runtime targets, and source layout once so install/bootstrap/doctor/healthcheck/self-heal/audit export reuse the same context. | `. ./scripts/common/runtime-execution-context.ps1; Resolve-RuntimeExecutionContext -RequestedRepoRoot . -FallbackProfileName all` |
| `common/runtime-operation-support.ps1` | Shared runtime operation helper for output/log path initialization plus standardized runtime `check` and `step` child-script invocation wrappers reused by healthcheck, self-heal, and audit export. | `. ./scripts/common/runtime-operation-support.ps1; Initialize-OperationArtifacts -ResolvedRepoRoot . -PrimaryOutputPath .temp/report.json -DefaultLogFilePrefix demo -LogName demo` |
| `common/runtime-install-profiles.ps1` | Shared runtime profile loader used by install/bootstrap/doctor/healthcheck/self-heal to resolve the versioned profile contract from `.github/governance/runtime-install-profiles.json`. | `. ./scripts/common/runtime-install-profiles.ps1; Resolve-RuntimeInstallProfile -ResolvedRepoRoot . -ProfileName all` |
| `common/repository-paths.ps1` | Shared repository helper for repository/git/solution root discovery, repo-relative and full-path conversion, parent directory handling, verbose diagnostics, and structured execution logging reused across runtime, security, orchestration, and runtime test scripts. | `. ./scripts/common/repository-paths.ps1` |
| `common/validation-logging.ps1` | Shared validation log helper for warning/failure registration and compact validation summaries reused across the validation script family. It relies on `repository-paths.ps1` for the shared verbose helpers. | `. ./scripts/common/validation-logging.ps1` |
| `runtime/doctor.ps1` | Diagnoses drift between repository-managed runtime assets and local `~/.github`/`~/.codex` copies. | `pwsh -File scripts/runtime/doctor.ps1` |
| `runtime/install.ps1` | Runs the profile-driven onboarding flow. Default profile is `none`, so the installer is non-intrusive unless `-RuntimeProfile github`, `codex`, or `all` is passed explicitly. Supports preview mode, parameterized runtime paths, and `-GitHookEofMode manual|autofix` plus `-GitHookEofScope local-repo|global` for hook behavior. For Codex-enabled profiles it also applies safe local runtime preferences through `set-codex-runtime-preferences.ps1`, defaulting to `model_reasoning_effort = "high"` and `[features].multi_agent = true` unless overridden with `-CodexReasoningEffort` or `-CodexMultiAgentMode`. When hook mode is provided without scope during a real run, the installer asks whether the selection should be global and defaults to the less-intrusive local-repo scope. In `global` scope, the installer configures a managed machine-wide `core.hooksPath` and leaves local repo hook paths for explicit overrides only. Warning/error lines carry runtime issue IDs and the script always closes with a deduplicated issue summary plus severity counts. | `$RepoRoot = '<REPO_ROOT>'; pwsh -File (Join-Path $RepoRoot 'scripts/runtime/install.ps1') -RuntimeProfile all -GitHookEofMode autofix -GitHookEofScope global -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig` |
| `runtime/set-codex-runtime-preferences.ps1` | Applies safe local Codex runtime preferences into `config.toml`, currently managing `model_reasoning_effort` and `[features].multi_agent` from the hygiene catalog or explicit overrides. The default contract keeps multi-agent available and leaves strategic subagent use to the repository-owned controller prompts/instructions. | `pwsh -File scripts/runtime/set-codex-runtime-preferences.ps1 -CreateBackup` |
| `runtime/apply-vscode-templates.ps1` | Applies `.vscode/*.tamplate.jsonc` into active `.vscode/settings.json` and `.vscode/mcp.json` files. | `pwsh -File scripts/runtime/apply-vscode-templates.ps1 -Force` |
| `runtime/sync-vscode-global-settings.ps1` | Renders `.vscode/settings.tamplate.jsonc` into the global VS Code user profile `settings.json`, replacing runtime placeholders such as `%USERPROFILE%` and optionally creating a backup first. | `pwsh -File scripts/runtime/sync-vscode-global-settings.ps1 -CreateBackup` |
| `runtime/sync-vscode-global-mcp.ps1` | Renders the canonical MCP runtime catalog from `.github/governance/mcp-runtime.catalog.json` into the global VS Code user profile `mcp.json`, refreshes the ignored local helper `.vscode/mcp-vscode-global.json`, and keeps stable per-server `${input:...}` ids so VS Code can reuse securely stored MCP credentials after the first prompt. | `pwsh -File scripts/runtime/sync-vscode-global-mcp.ps1 -CreateBackup` |
| `runtime/render-mcp-runtime-artifacts.ps1` | Regenerates the tracked MCP runtime projections from `.github/governance/mcp-runtime.catalog.json`: `.vscode/mcp.tamplate.jsonc` and `.codex/mcp/servers.manifest.json`. Use it after catalog edits or in parity checks. | `pwsh -File scripts/runtime/render-mcp-runtime-artifacts.ps1 -RepoRoot .` |
| `runtime/sync-vscode-global-snippets.ps1` | Synchronizes versioned `.vscode/snippets/*.tamplate.code-snippets` files into the global VS Code user profile under `Code/User/snippets`, removing `.tamplate` from target names. | `pwsh -File scripts/runtime/sync-vscode-global-snippets.ps1` |
| `runtime/sync-workspace-settings.ps1` | Generates or refreshes `.code-workspace` files from `.vscode/base.code-workspace` plus the approved local override block derived from `.github/governance/workspace-efficiency.baseline.json`. Preserves folders, removes settings already covered by the global template, and merges workspace-specific extension recommendations with the shared base. | `pwsh -File scripts/runtime/sync-workspace-settings.ps1 -WorkspacePath .\workspaces\api.code-workspace -FolderPath src\Api` |
| `runtime/update-copilot-chat-titles.ps1` | Normalizes persisted GitHub Copilot chat titles to `<project-prefix> - <task summary>` using `%APPDATA%\\Code\\User\\workspaceStorage\\<workspace-id>\\chatSessions\\*.json*`, with optional backups before writing. | `pwsh -File scripts/runtime/update-copilot-chat-titles.ps1 -Apply -CreateBackup` |
| `runtime/clean-vscode-user-runtime.ps1` | Cleans stale VS Code user-runtime artifacts under `Code/User`, including old `workspaceStorage` directories, old Copilot chat sessions/transcripts, old `History` files, old `settings.json.*.bak`/`mcp.json.*.bak` backups, and oversized `GitHub.copilot-chat/local-index*.db` files. Hook-driven runs use a 12-hour throttle window and default to background execution so commits and pulls are not blocked. | `pwsh -File scripts/runtime/clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 0` |
| `runtime/invoke-super-agent-housekeeping.ps1` | Runs safe periodic housekeeping for one workspace. It exports a concise planning handoff first, then cleans persisted Codex and VS Code runtime state, while never attempting to clear the live active context window or UI token meter. Hook-driven dispatch is throttled per workspace every 2 hours by default. | `pwsh -File scripts/runtime/invoke-super-agent-housekeeping.ps1 -WorkspacePath . -Apply` |
| `runtime/healthcheck.ps1` | Runs `validate-all` (profile-aware) plus `runtime-doctor`, emits report/log, and defaults to warning-only mode. Runtime warning/error lines use issue IDs and the final output/report include a deduplicated issue summary with severity counts. | `pwsh -File scripts/runtime/healthcheck.ps1 -ValidationProfile release` |
| `runtime/self-heal.ps1` | Runs controlled repair flow (bootstrap + optional templates) and validates final state via healthcheck. Runtime warning/error lines use issue IDs and the final output/report include a deduplicated issue summary with severity counts. | `pwsh -File scripts/runtime/self-heal.ps1 -Mirror -StrictExtras` |
| `runtime/run-agent-pipeline.ps1` | Executes default multi-agent pipeline with blocked-command, allowed-path, budget, and approval guardrails; supports `script-only` and live `codex-exec` backends; writes `run-artifact.json`, `run-state.json`, `approval-record.json`, and stage artifacts under `.temp/runs/<traceId>/`. Sensitive stages require `-ApprovedStageIds` or `-ApprovedAgentIds` plus `-ApprovedBy` and `-ApprovalJustification`. | `pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Implement and validate change" -ExecutionBackend codex-exec -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved sensitive pipeline stages"` |
| `runtime/new-super-agent-worktree.ps1` | Creates deterministic git worktrees for isolated Super Agent work, with Windows-safe branch/worktree naming and preview support. | `pwsh -File scripts/runtime/new-super-agent-worktree.ps1 -WorktreeName "feature-slice"` |
| `runtime/invoke-super-agent-brainstorm.ps1` | Runs the Super Agent lifecycle through intake and spec only, producing normalized request and active spec artifacts. | `pwsh -File scripts/runtime/invoke-super-agent-brainstorm.ps1 -RequestText "Design the workstream"` |
| `runtime/invoke-super-agent-plan.ps1` | Runs the Super Agent lifecycle through planning and stops after a worker-ready plan is written. | `pwsh -File scripts/runtime/invoke-super-agent-plan.ps1 -RequestText "Write the execution plan"` |
| `runtime/invoke-super-agent-execute.ps1` | Runs the full Super Agent lifecycle end-to-end with the configured execution backend and forwards explicit approval parameters to sensitive stages. | `pwsh -File scripts/runtime/invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan" -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved full lifecycle execution"` |
| `runtime/invoke-super-agent-parallel-dispatch.ps1` | Runs the full Super Agent lifecycle and is intended for safe parallel worker dispatch once dependency-independent batches are present; forwards explicit approval parameters when sensitive stages are allowed to run. | `pwsh -File scripts/runtime/invoke-super-agent-parallel-dispatch.ps1 -RequestText "Implement independent work items" -ApprovedAgentIds specialist,release-engineer -ApprovedBy "thiago.guislotti" -ApprovalJustification "Approved full lifecycle execution"` |
| `orchestration/engine/invoke-codex-dispatch.ps1` | Renders a stage prompt, invokes the local Codex CLI, captures JSON output, and persists dispatch logs/records for live planner, executor, and reviewer stages. | `pwsh -File scripts/orchestration/engine/invoke-codex-dispatch.ps1 -RepoRoot . -TraceId trace-001 -StageId plan -AgentId planner -PromptPath .temp\\planner.md -ResponseSchemaPath .github\\schemas\\agent.stage-plan-result.schema.json -ResultPath .temp\\planner-result.json -DispatchRecordPath .temp\\planner-dispatch.json` |
| `orchestration/engine/invoke-task-worker.ps1` | Executes a single worker-ready task through implementer -> task spec review -> task quality review, with retry and allowed-path enforcement. | `pwsh -File scripts/orchestration/engine/invoke-task-worker.ps1 -RepoRoot . -TraceId trace-001 -TaskRecordPath .temp\\runs\\trace-001\\artifacts\\task-001.json -RunDirectory .temp\\runs\\trace-001 -ExecutionBackend codex-exec` |
| `runtime/clean-codex-runtime.ps1` | Cleans local Codex runtime garbage (`tmp`, `vendor_imports`) and prunes `log`/`sessions` using catalog-driven retention. Default catalog values are log retention `14` days and session retention `30` days by `LastWriteTime`, preserving active conversations by default. Oversized session thresholds and total session-storage budgets remain available only through explicit environment-variable or parameter overrides. Supports `-ExportPlanningSummary` to snapshot active plans before cleaning. | `pwsh -File scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -Apply` |
| `runtime/export-planning-summary.ps1` | Exports a context handoff summary from active planning artifacts (`planning/active/` and `planning/specs/active/`). Generates a structured markdown document with active plans, active specs, and recent git commits to allow sessions to resume from a known stable state. Saves to `.temp/context-handoff-<timestamp>.md` or prints to console with `-PrintOnly`. | `pwsh -File scripts/runtime/export-planning-summary.ps1 -PrintOnly` |
| `runtime/update-local-context-index.ps1` | Builds or refreshes the repository-owned local context index from `.github/governance/local-context-index.catalog.json` under `.temp/context-index/` for safe local RAG/CAG continuity. Reuses unchanged file entries incrementally when hashes match. | `pwsh -File scripts/runtime/update-local-context-index.ps1 -RepoRoot .` |
| `runtime/query-local-context-index.ps1` | Executes deterministic lexical retrieval against the local context index so the Super Agent can reuse relevant repository fragments without replaying large transcripts. | `pwsh -File scripts/runtime/query-local-context-index.ps1 -RepoRoot . -QueryText "context compaction continuity" -JsonOutput` |
| `orchestration/stages/*.ps1` | Stage executors (`plan`, `implement`, `validate`, `review`) consumed by `run-agent-pipeline.ps1`. | `pwsh -File scripts/runtime/run-agent-pipeline.ps1 -RequestText "Smoke run"` |
| `maintenance/clean-build-artifacts.ps1` | Deletes `.build`, `.deployment`, `bin`, and `obj` directories. Supports dry-run and prompts for confirmation. | `pwsh -File scripts/maintenance/clean-build-artifacts.ps1 -DryRun` |

## VS Code Agent Hooks

- Repository-owned VS Code agent hooks live under `.github/hooks/`.
- Runtime sync mirrors them to `%USERPROFILE%\\.github\\hooks`.
- The global VS Code settings template loads hooks from both:
  - `.github/hooks`
  - `~/.github/hooks`
- Current bootstrap events:
  - `SessionStart`
  - `PreToolUse`
  - `SubagentStart`
- Startup controller selection:
  - versioned default: `.github/hooks/super-agent.selector.json`
  - optional local override: `~/.github/hooks/super-agent.selector.local.json`
  - optional environment override: `COPILOT_SUPER_AGENT_SKILL`, `COPILOT_SUPER_AGENT_NAME`
- EOF normalization:
  - `PreToolUse` normalizes supported edit/create tool payloads before disk writes
  - `SessionStart` and `SubagentStart` inject a short continuity summary derived from the latest active plan/spec artifact so a fresh or compacted session can resume from versioned planning state instead of replaying large chat history
  - current supported tools: `createFile`, `insertEdit`, `replaceString`, `multiReplaceString`
  - `applyPatch` still relies on model compliance with the EOF policy because its patch grammar is not safely rewritten by the hook
| `maintenance/generate-http-from-openapi.ps1` | Generates a REST Client .http file from OpenAPI (default) or Swagger JSON. | `pwsh -File scripts/maintenance/generate-http-from-openapi.ps1 -Source http://localhost:5000` |
| `maintenance/fix-version-ranges.ps1` | Normalises PackageReference versions into `[current, limit)` ranges. | `pwsh -File scripts/maintenance/fix-version-ranges.ps1 -Verbose` |
| `maintenance/trim-trailing-blank-lines.ps1` | Removes trailing spaces and blank lines at EOF while respecting the repository EOF policy: files end without final newline unless a future explicit rule says otherwise. Supports `-GitChangedOnly` to limit trimming to files currently reported by `git status`. | `pwsh -File scripts/maintenance/trim-trailing-blank-lines.ps1 -GitChangedOnly` |
| `security/Invoke-VulnerabilityAudit.ps1` | Audits .NET backend package vulnerabilities via `dotnet list package --vulnerable --include-transitive`. | `pwsh -File scripts/security/Invoke-VulnerabilityAudit.ps1 -FailOnSeverities Critical,High` |
| `security/Invoke-FrontendPackageVulnerabilityAudit.ps1` | Audits frontend dependencies using npm/pnpm/yarn and applies severity quality gate. | `pwsh -File scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1 -ProjectPath src/WebApp -FailOnSeverities Critical,High` |
| `security/Invoke-RustPackageVulnerabilityAudit.ps1` | Audits Rust dependencies via `cargo audit --json` with severity quality gate. | `pwsh -File scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1 -ProjectPath . -FailOnSeverities Critical,High` |
| `security/Install-SecurityAuditPrerequisites.ps1` | Validates and auto-installs audit prerequisites (`dotnet`, `cargo`, `cargo-audit`, npm/pnpm/yarn) with optional system package manager support. | `pwsh -File scripts/security/Install-SecurityAuditPrerequisites.ps1 -FrontendPackageManager auto` |
| `security/Invoke-PreBuildSecurityGate.ps1` | Runs unified pre-build vulnerability gate across .NET, frontend, and Rust using stack scripts and consolidated summary artifacts; optionally runs prerequisite setup first. | `pwsh -File scripts/security/Invoke-PreBuildSecurityGate.ps1 -InstallMissingPrerequisites -FailOnSeverities Critical,High` |
| `security/Invoke-CiPreBuildSecuritySnapshot.ps1` | Runs the warning-only pre-build security gate with stack-aware skip detection for CI workflows, so the inline GitHub Actions logic stays minimal and deterministic. | `pwsh -File scripts/security/Invoke-CiPreBuildSecuritySnapshot.ps1 -RepoRoot . -WarningOnly:$true -AllowMissingCargoAudit` |
| `tests/apply-aaa-pattern.ps1` | Applies AAA comments to frontend TypeScript/Vue test files. | `pwsh -File scripts/tests/apply-aaa-pattern.ps1` |
| `tests/check-test-naming.ps1` | Validates required underscore segments in test names. | `pwsh -File scripts/tests/check-test-naming.ps1 Projects "OpenApi.Readers.UnitTests"` |
| `tests/refactor_tests_to_aaa.ps1` | Refactors Rust test files to follow AAA pattern with comments and formatting. | `pwsh -File scripts/tests/refactor_tests_to_aaa.ps1 -TestFile tests/unit/config_tests.rs` |
| `tests/run-coverage.ps1` | Runs tests with coverage and generates HTML/Cobertura reports. | `pwsh -File scripts/tests/run-coverage.ps1 -ProjectsDir tests` |

---

## Build and Tests

```powershell
# lint-like execution test for bootstrap (safe dry usage)
pwsh -File .\scripts\runtime\bootstrap.ps1 -TargetGithubPath .\.temp\github -TargetCodexPath .\.temp\codex

# preview the recommended onboarding flow without mutating runtime files
pwsh -File .\scripts\runtime\install.ps1 -PreviewOnly

# preview the full onboarding flow explicitly
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -PreviewOnly

# all runtime warning/error logs now include IDs such as WRN001 / ERR001
# and finish with a deduplicated issue summary plus severity counts
pwsh -File .\scripts\runtime\install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig

# diagnose runtime drift
pwsh -File .\scripts\runtime\doctor.ps1

# apply VS Code active files from versioned templates
pwsh -File .\scripts\runtime\apply-vscode-templates.ps1 -Force

# render the versioned settings template into the global VS Code user profile
pwsh -File .\scripts\runtime\sync-vscode-global-settings.ps1 -CreateBackup

# render the canonical MCP runtime catalog into the global VS Code user profile
pwsh -File .\scripts\runtime\sync-vscode-global-mcp.ps1 -CreateBackup

# regenerate tracked MCP runtime projections from the canonical catalog
pwsh -File .\scripts\runtime\render-mcp-runtime-artifacts.ps1 -RepoRoot .

# build or refresh the local repository context index for safe RAG/CAG reuse
pwsh -File .\scripts\runtime\update-local-context-index.ps1 -RepoRoot .

# query the local repository context index
pwsh -File .\scripts\runtime\query-local-context-index.ps1 -RepoRoot . -QueryText "MCP source of truth" -JsonOutput

# synchronize canonical VS Code snippets into the global user profile
pwsh -File .\scripts\runtime\sync-vscode-global-snippets.ps1

# generate or refresh a workspace from the shared base and settings baseline
pwsh -File .\scripts\runtime\sync-workspace-settings.ps1 -WorkspacePath .\workspaces\api.code-workspace -FolderPath src\Api

# normalize persisted Copilot chat titles with the current project/workspace prefix
pwsh -File .\scripts\runtime\update-copilot-chat-titles.ps1 -Apply -CreateBackup

# run enterprise healthcheck with strict runtime guarantees
pwsh -File .\scripts\runtime\healthcheck.ps1 -StrictExtras

# auto-repair runtime and validate final state
pwsh -File .\scripts\runtime\self-heal.ps1 -Mirror -StrictExtras

# execute default multi-agent pipeline and produce run artifact
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Run pipeline smoke test"

# execute default multi-agent pipeline with live planner/executor/reviewer dispatch
pwsh -File .\scripts\runtime\run-agent-pipeline.ps1 -RequestText "Run pipeline smoke test" -ExecutionBackend codex-exec

# create an isolated worktree for Super Agent execution
pwsh -File .\scripts\runtime\new-super-agent-worktree.ps1 -WorktreeName "feature-slice" -PreviewOnly

# run Super Agent through brainstorm/spec only
pwsh -File .\scripts\runtime\invoke-super-agent-brainstorm.ps1 -RequestText "Design the workstream" -PreviewOnly

# run Super Agent through planning only
pwsh -File .\scripts\runtime\invoke-super-agent-plan.ps1 -RequestText "Write the execution plan" -PreviewOnly

# run the full Super Agent lifecycle
pwsh -File .\scripts\runtime\invoke-super-agent-execute.ps1 -RequestText "Implement the approved plan" -PreviewOnly

# run the full lifecycle with the safe parallel-dispatch entrypoint
pwsh -File .\scripts\runtime\invoke-super-agent-parallel-dispatch.ps1 -RequestText "Implement independent work items" -PreviewOnly

# trim EOF only for files currently changed in git
pwsh -File .\scripts\maintenance\trim-trailing-blank-lines.ps1 -GitChangedOnly

# preview/runtime cleanup (no deletion)
pwsh -File .\scripts\runtime\clean-codex-runtime.ps1 -IncludeSessions

# apply runtime cleanup using the catalog defaults
pwsh -File .\scripts\runtime\clean-codex-runtime.ps1 -IncludeSessions -Apply

# preview VS Code user-runtime cleanup without the hook throttle
pwsh -File .\scripts\runtime\clean-vscode-user-runtime.ps1 -RecentRunWindowHours 0

# apply VS Code user-runtime cleanup immediately
pwsh -File .\scripts\runtime\clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 0

# export planning continuity and clean persisted runtime state for the active workspace
pwsh -File .\scripts\runtime\invoke-super-agent-housekeeping.ps1 -WorkspacePath . -Apply

# apply safe local Codex runtime defaults explicitly
pwsh -File .\scripts\runtime\set-codex-runtime-preferences.ps1 -CreateBackup

# override the defaults only when you really want a different local profile
pwsh -File .\scripts\runtime\set-codex-runtime-preferences.ps1 -ReasoningEffort xhigh -MultiAgentMode enabled -CreateBackup

# validate instruction assets and static routing references
pwsh -File .\scripts\validation\validate-instructions.ps1

# run full validation suite (hooks baseline)
pwsh -File .\scripts\validation\validate-all.ps1

# validate policy contracts
pwsh -File .\scripts\validation\validate-policy.ps1

# validate multi-agent contracts and pipeline integrity
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1

# run the native Super Agent worktree tests
pwsh -File .\scripts\tests\runtime\super-agent-worktree.tests.ps1 -RepoRoot .

# run the native Super Agent entrypoint tests
pwsh -File .\scripts\tests\runtime\super-agent-entrypoints.tests.ps1 -RepoRoot .

# validate routing catalog coverage against golden fixtures
pwsh -File .\scripts\validation\validate-routing-coverage.ps1

# validate centralized official-doc source routing policy
pwsh -File .\scripts\validation\validate-authoritative-source-policy.ps1

# validate instruction ownership boundaries and global-core architecture
pwsh -File .\scripts\validation\validate-instruction-architecture.ps1

# validate shared templates against the template baseline
pwsh -File .\scripts\validation\validate-template-standards.ps1

# validate VS Code .code-workspace files for efficient Codex/Copilot usage
pwsh -File .\scripts\validation\validate-workspace-efficiency.ps1 -WorkspaceSearchRoot .\workspaces

# validate COMPATIBILITY lifecycle policy
pwsh -File .\scripts\validation\validate-compatibility-lifecycle-policy.ps1

# validate agent, skill, pipeline, and eval alignment
pwsh -File .\scripts\validation\validate-agent-skill-alignment.ps1

# validate release governance contracts
pwsh -File .\scripts\validation\validate-release-governance.ps1

# validate security baseline (paths + secret-like content patterns)
pwsh -File .\scripts\validation\validate-security-baseline.ps1

# validate shared script checksum manifest integrity
pwsh -File .\scripts\validation\validate-shared-script-checksums.ps1

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

# regenerate shared script checksum manifest
pwsh -File .\scripts\governance\update-shared-script-checksums-manifest.ps1

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

# install local Git hooks and opt this clone into automatic staged EOF cleanup
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope local-repo

# install global Git hooks and make the managed machine-wide core.hooksPath authoritative
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope global

# configure the manual global git trim alias
pwsh -File .\scripts\git-hooks\setup-global-git-aliases.ps1

# use the global alias in any git repository before staging
git trim-eof

# inspect help for script contracts
Get-Help .\scripts\runtime\bootstrap.ps1 -Full
```

After setup, hooks behavior is:
- hook path precedence: local `git config --local core.hooksPath` overrides `git config --global core.hooksPath`
- `global` scope installs the managed machine-wide `pre-commit` hook under `%USERPROFILE%\\.codex\\git-hooks`
- `pre-commit`: resolves EOF hygiene from `.git/codex-hook-eof-settings.json`, then `%USERPROFILE%\\.codex\\git-hook-eof-settings.json`, then the catalog default
- `pre-commit` in `manual` mode: does not trim files automatically and continues to validation
- `pre-commit` in `autofix` mode: trims only staged files, re-stages them, and blocks the commit when a file has both staged and unstaged changes because auto-restaging would be unsafe
- repo-local `pre-commit`: then runs `validate-all -ValidationProfile dev -WarningOnly true` (best effort, warning-only)
- global `pre-commit`: runs only EOF hygiene; repository-specific validation/post-* hooks still require a local `.githooks` override
- if `autofix` is configured in `global` scope and the repository does not override `core.hooksPath` locally, you do not need to run `git trim-eof` manually for normal commits
- `git trim-eof` still matters when you want cleanup before staging, when you want to inspect the diff first, or when the repository stays in `manual` mode
- Git has no native `pre-add` hook, so automatic EOF cleanup happens on commit, not on `git add` or the VS Code stage action
- `post-commit`: runs `scripts/runtime/bootstrap.ps1 -Mirror` only when `HEAD` changed runtime-managed source paths under `.github/`, `.codex/`, or `scripts/` (best effort)
- `post-commit`: re-applies safe Codex runtime preferences when `HEAD` changed runtime-managed source paths (best effort)
- `post-commit`: runs `scripts/runtime/validate-vscode-global-alignment.ps1` only when `HEAD` changed `.vscode/` or the VS Code sync/alignment scripts (best effort)
- `post-commit`: runs `scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -Apply` (best effort, using the hygiene catalog defaults unless environment overrides are set)
- `post-commit`: schedules `scripts/runtime/clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 12` in the background (best effort, using the VS Code hygiene catalog defaults unless environment overrides are set)
- VS Code `SessionStart` and `SubagentStart`: dispatch `scripts/runtime/invoke-super-agent-housekeeping.ps1` at most once every 2 hours per workspace (best effort)
- periodic Super Agent housekeeping exports a concise planning summary first, then cleans only persisted Codex and VS Code runtime state
- periodic Super Agent housekeeping does not clear the live active context window or reset the runtime UI token meter
- `post-merge`: runs `validate-all -ValidationProfile release -WarningOnly true` (best effort, warning-only)
- `post-merge`: re-applies safe Codex runtime preferences (best effort)
- `post-merge`: runs `scripts/runtime/clean-codex-runtime.ps1 -IncludeSessions -Apply` (best effort, using the hygiene catalog defaults unless environment overrides are set)
- `post-merge`: schedules `scripts/runtime/clean-vscode-user-runtime.ps1 -Apply -RecentRunWindowHours 12` in the background (best effort, using the VS Code hygiene catalog defaults unless environment overrides are set)
- `post-merge`: does not run runtime bootstrap sync
- `post-checkout`: runs `validate-all -ValidationProfile dev -WarningOnly true` (best effort, warning-only)
- `post-commit` optional MCP apply on canonical catalog or generated MCP projection changes: set `CODEX_APPLY_MCP_ON_POST_COMMIT=1`
- `post-commit` MCP backup control: `CODEX_BACKUP_MCP_CONFIG=1|0` (`1` default)
- `post-commit` mirror control: `CODEX_POST_COMMIT_MIRROR=0|1` (`1` default)
- `post-commit` and `post-merge` runtime preference apply bypass: `CODEX_SKIP_RUNTIME_PREFERENCES_APPLY=1`
- `post-commit` and `post-merge` cleanup bypass: `CODEX_SKIP_RUNTIME_CLEANUP=1`
- `post-commit` and `post-merge` VS Code cleanup bypass: `CODEX_SKIP_VSCODE_RUNTIME_CLEANUP=1`
- `post-commit` and `post-merge` VS Code cleanup background control: `CODEX_VSCODE_RUNTIME_CLEANUP_BACKGROUND=0|1` (`1` default)
- `SUPER_AGENT_HOUSEKEEPING_DISABLE=1`: disables SessionStart/SubagentStart housekeeping dispatch
- `SUPER_AGENT_HOUSEKEEPING_INTERVAL_HOURS=<n>`: interval between housekeeping runs for the same workspace (`2` default)
- `SUPER_AGENT_HOUSEKEEPING_FOREGROUND=1`: runs housekeeping inline instead of detached background execution
- `SUPER_AGENT_HOUSEKEEPING_STATE_PATH=<path>`: overrides the housekeeping state file path
- `SUPER_AGENT_HOUSEKEEPING_RECORD_ONLY_PATH=<path>`: test-only override that records housekeeping intent without touching real runtime state
- `post-commit` and `post-merge` log retention: `CODEX_LOG_RETENTION_DAYS=<n>` (`14` default from the hygiene catalog, by `LastWriteTime`)
- `post-commit` and `post-merge` session cleanup toggle: `CODEX_INCLUDE_SESSIONS_CLEANUP=0|1` (`1` default)
- `post-commit` and `post-merge` session retention: `CODEX_SESSION_RETENTION_DAYS=<n>` (`30` default from the hygiene catalog, by `LastWriteTime`)
- `post-commit` and `post-merge` oversized session threshold: `CODEX_MAX_SESSION_FILE_SIZE_MB=<n>` (disabled by default; opt-in emergency override)
- `post-commit` and `post-merge` oversized session grace: `CODEX_OVERSIZED_SESSION_GRACE_HOURS=<n>` (disabled by default; paired with the oversized threshold override)
- `post-commit` and `post-merge` total session budget: `CODEX_MAX_SESSION_STORAGE_GB=<n>` (disabled by default; opt-in emergency override)
- `post-commit` and `post-merge` session storage grace: `CODEX_SESSION_STORAGE_GRACE_HOURS=<n>` (disabled by default; paired with the storage-budget override)
- `post-commit` and `post-merge` VS Code cleanup throttle: `CODEX_VSCODE_RECENT_RUN_WINDOW_HOURS=<n>` (`12` default)
- `post-commit` and `post-merge` stale workspaceStorage retention: `CODEX_VSCODE_WORKSPACE_STORAGE_RETENTION_DAYS=<n>` (`30` default)
- `post-commit` and `post-merge` chat session retention: `CODEX_VSCODE_CHAT_SESSION_RETENTION_DAYS=<n>` (`14` default)
- `post-commit` and `post-merge` chat editing retention: `CODEX_VSCODE_CHAT_EDITING_RETENTION_DAYS=<n>` (`7` default)
- `post-commit` and `post-merge` transcript retention: `CODEX_VSCODE_TRANSCRIPT_RETENTION_DAYS=<n>` (`14` default)
- `post-commit` and `post-merge` History retention: `CODEX_VSCODE_HISTORY_RETENTION_DAYS=<n>` (`30` default)
- `post-commit` and `post-merge` settings backup retention: `CODEX_VSCODE_SETTINGS_BACKUP_RETENTION_DAYS=<n>` (`30` default)
- `post-commit` and `post-merge` oversized chat session threshold: `CODEX_VSCODE_MAX_CHAT_SESSION_FILE_SIZE_MB=<n>` (`128` default)
- `post-commit` and `post-merge` oversized workspace index threshold: `CODEX_VSCODE_MAX_WORKSPACE_INDEX_SIZE_MB=<n>` (`1024` default)
- `post-commit` and `post-merge` oversized VS Code file grace: `CODEX_VSCODE_OVERSIZED_FILE_GRACE_HOURS=<n>` (`12` default)

Practical examples:

```powershell
# machine-wide EOF autofix for repositories that inherit the global hooks path
pwsh -File .\scripts\git-hooks\setup-git-hooks.ps1 -EofHygieneMode autofix -EofHygieneScope global

# verify the global hook path
git config --global --get core.hooksPath

# verify whether the current repository overrides the global hook path
git config --local --get core.hooksPath

# optional manual cleanup before staging when you want to inspect the diff
git trim-eof
git add .
git commit -m "Apply change"
```

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

- `.codex/scripts/README.md`
- `.github/AGENTS.md`
- `.github/copilot-instructions.md`
- `README.md`