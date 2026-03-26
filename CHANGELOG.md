## [Unreleased] - 2026-03-23

### Added
- **Context Economy and Checkpoint Protocol** formalized as a first-class instruction `context-economy-checkpoint.instructions.md` (44th domain instruction file): defines a three-mode automatic operation model (Execution / Continuous Compression / Structured Checkpoint), a six-block internal state model (Current state / In progress / Completed / Decisions / Pending items / Next step), a compression-trigger list, the canonical CHECKPOINT format, and an English user command vocabulary (`checkpoint`, `compress context`, `update plan`, `show status`, `show progress`, `resume from summary`) with PT-BR convenience aliases documented in `.github/COMMANDS.md`.
- Protocol enforced across all three AI runtimes:
  - **GitHub Copilot**: `AGENTS.md` `# Context Economy and Checkpoint Commands` section; `instruction-routing.catalog.yml` `context-economy` route; `workflow-optimization.instructions.md` `## Context Economy and Checkpoint` section.
  - **Claude Code**: `CLAUDE.md` `## Context Economy and Checkpoint Protocol` section; `.claude/settings.json` `contextEconomy` config block and `UserPromptSubmit` hook for command detection.
  - **OpenAI Codex**: `.codex/skills/super-agent/SKILL.md` `## Context Economy Protocol` section; `context-economy-checkpoint.instructions.md` added to mandatory context in `super-agent-intake-stage.prompt.md`, `planner-stage.prompt.md`, `executor-task.prompt.md`, and `closeout-stage.prompt.md`.
  - **Planning artifact**: `planning/active/plan-context-economy-checkpoint-protocol.md` created to track the workstream.
- Context economy rules deduplicated: canonical detail lives only in `context-economy-checkpoint.instructions.md`; all other files carry a one-paragraph summary plus a reference to the canonical file.

### Changed
- Canonicalized MCP runtime ownership around `.github/governance/mcp-runtime.catalog.json`, added a tracked renderer pipeline for `.vscode/mcp.tamplate.jsonc` and `.codex/mcp/servers.manifest.json`, updated bootstrap/post-commit/install-facing documentation to treat the Codex manifest as a generated subset instead of the primary source of truth, and extended validation/runtime tests to enforce renderer parity.
- Added the first deterministic local RAG/CAG slice through `.github/governance/local-context-index.catalog.json`, `scripts/common/local-context-index.ps1`, `scripts/runtime/update-local-context-index.ps1`, `scripts/runtime/query-local-context-index.ps1`, and housekeeping refresh integration so local repository continuity can be reused from `.temp/context-index/` without replaying large chat transcripts.
- Added an explicit Super Agent clarification gate across intake runtime/schema/instruction surfaces so ambiguous requests now stop cleanly after intake with concise clarification questions only when the ambiguity would materially change planning scope, architecture, runtime behavior, validation, or operational safety.
- Documented `.vscode/profiles/` as the versioned MCP/profile baseline selector surface, documented `infra/github/main.json` as GitHub ruleset/governance infrastructure, and aligned Claude/Codex runtime-sync skills with the same canonical MCP catalog and clarification contract.

## [9.9.9] - 2026-03-20

### Changed
- Aligned the `super-agent` controller contract across Copilot, Codex, and Claude surfaces while separating the visible Copilot aliases: `.codex/skills/super-agent/SKILL.md` and `.claude/skills/super-agent/SKILL.md` keep the canonical starter/controller description, `.github/agents/super-agent.agent.md` now exposes a secondary workspace-controller alias instead of a second `/super-agent`, and runtime bootstrap removes legacy duplicate starter folders from both `%USERPROFILE%\\.github\\skills` and `%USERPROFILE%\\.copilot\\skills` so Copilot slash discovery converges on the shared `%USERPROFILE%\\.agents\\skills\\super-agent` surface.
- Promoted `.vscode/profiles/` from a local-only helper classification to a versioned reusable profile-baseline surface: removed the folder from `.gitignore`, updated `.vscode/README.md` and `.vscode/profiles/README.md` to document checked-in profile selection, and replaced `.vscode/profiles/setup-profiles.ps1` with JSON-driven discovery plus `-ListProfiles` / `-ProfileName` selection support while removing stale references to the missing `profile-vision-engine.json`. `.vscode/mcp-vscode-global.json` remains local-only for now.
- Classified `.vscode/mcp-vscode-global.json` as a local helper/reference surface only, documented that it is not an authoritative runtime input for install/bootstrap/MCP sync, and captured the profile-surface drift cleanup that removed stale `profile-vision-engine.json` references from the checked-in profile docs and setup flow.
- Removed the repository-owned native Copilot `super-agent` skill surface and changed bootstrap/runtime docs so `%USERPROFILE%\\.copilot\\skills` is now treated as a legacy duplicate-cleanup target instead of a projection target: runtime bootstrap deletes stale `super-agent` and `using-super-agent` folders there while keeping `%USERPROFILE%\\.agents\\skills\\super-agent` as the single canonical visible starter/controller surface.
- Added repository-owned Codex runtime hygiene controls to stop runaway local session growth while preserving normal capability: versioned defaults now bias local `config.toml` toward `model_reasoning_effort = "high"` and `[features].multi_agent = true`, install can apply those defaults through `scripts/runtime/set-codex-runtime-preferences.ps1`, and `clean-codex-runtime.ps1` now defaults to stale-session cleanup after 30 days without update from `.github/governance/codex-runtime-hygiene.catalog.json`; oversized-file and total-storage pruning remain available only through explicit override parameters or environment variables, and `post-commit` / `post-merge` keep reapplying runtime preferences plus catalog-driven cleanup without trimming active-session context by default.
- Added planning-anchored continuity bootstrap to the repository-owned VS Code hook surface: `SessionStart` and `SubagentStart` now inject a short continuity summary derived from the latest active plan/spec artifact so fresh or compacted sessions can resume from versioned planning state instead of replaying oversized chat history.
- Added repository-owned VS Code user-runtime hygiene controls to stop runaway Copilot Chat workspace growth: the global settings template now keeps `chat.agent.maxRequests = 100`, `chat.emptyState.history.enabled = false`, and `chat.restoreLastPanelSession = false`; new policy defaults in `.github/governance/vscode-runtime-hygiene.catalog.json` drive `scripts/runtime/clean-vscode-user-runtime.ps1`; and `post-commit` / `post-merge` now schedule stale `workspaceStorage`, `History`, old settings backups, and oversized `GitHub.copilot-chat/local-index*.db` cleanup on a throttled 12-hour background window so hooks do not block normal Git flow.
- Shifted the Super Agent token-efficiency direction to the safe output side only by making Copilot/Codex instructions, skills, and orchestration prompts explicitly quality-first: concise default responses, delta-focused stage summaries, less repeated narration, and a hard rule against trimming required execution context purely to save tokens:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `.github/instructions/super-agent.instructions.md`
  - `.github/instructions/workflow-optimization.instructions.md`
  - `.github/instructions/subagent-planning-workflow.instructions.md`
  - `.github/instructions/repository-operating-model.instructions.md`
  - `.github/skills/super-agent/SKILL.md`
  - `.codex/skills/super-agent/SKILL.md`
  - `.codex/orchestration/prompts/spec-stage.prompt.md`
  - `.codex/orchestration/prompts/planner-stage.prompt.md`
  - `.codex/orchestration/prompts/router-stage.prompt.md`
  - `.codex/orchestration/prompts/executor-task.prompt.md`
  - `.codex/orchestration/prompts/reviewer-stage.prompt.md`
  - `.codex/orchestration/prompts/closeout-stage.prompt.md`
  - `README.md`
  - `scripts/README.md`
  - `planning/active/plan-super-agent-token-quality-and-runtime-sync-cleanup.md`
  - `planning/specs/active/spec-super-agent-token-quality-and-runtime-sync-cleanup.md`
- Standardized shared execution-session logging across operational PowerShell entrypoints so default runs now emit deterministic `Session start` / `Session end` markers, verbose-capable scripts consistently expose `-Verbose`, `-DetailedLogs`, or `-DetailedOutput`, and runtime/validation helpers centralize the session lifecycle without duplicating script-local scaffolding:
  - `scripts/common/repository-paths.ps1`
  - `scripts/common/runtime-operation-support.ps1`
  - `scripts/common/validation-logging.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/runtime/run-agent-pipeline.ps1`
  - `scripts/runtime/replay-agent-run.ps1`
  - `scripts/runtime/evaluate-agent-pipeline.ps1`
  - `scripts/git-hooks/setup-git-hooks.ps1`
  - `scripts/git-hooks/setup-global-git-aliases.ps1`
  - `scripts/git-hooks/invoke-pre-commit-eof-hygiene.ps1`
  - `scripts/maintenance/trim-trailing-blank-lines.ps1`
  - `scripts/security/Invoke-VulnerabilityAudit.ps1`
  - `scripts/validation/validate-all.ps1`
  - `scripts/validation/export-audit-report.ps1`
  - `scripts/validation/validate-agent-hooks.ps1`
  - `scripts/validation/validate-planning-structure.ps1`
  - `scripts/tests/runtime/execution-session-logging.tests.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
  - `README.md`
  - `scripts/README.md`
- Expanded `scripts/README.md` with the full execution-session contract, switch map, expected output shape, and concrete examples by runtime, validation, orchestration, git-hook, maintenance, and security script families so operators can consistently choose between concise default runs and detailed diagnostics.
- Archived the umbrella `spec-super-agent-hardening-roadmap.md` in `planning/specs/completed/` after Phase 1 finished and clarified that future Super Agent hardening increments must reopen as phase-specific active specs instead of leaving a long-lived roadmap in `planning/specs/active/`.
- Added smoke-test coverage for closeout-driven README and CHANGELOG updates.
- Clarified the global EOF autofix contract in `README.md` and `scripts/README.md`, including the `core.hooksPath` override limit, the absence of a native Git `pre-add` hook, and when the manual `git trim-eof` alias is still useful even after enabling machine-wide `autofix`.
- Hardened `trim-trailing-blank-lines.tests.ps1` so its temporary git repositories opt out of the machine-global hook path and line-ending policy, keeping runtime test results deterministic even when global EOF autofix is enabled on the workstation.
- Removed duplicate local root/verbose/color helper logic from `clean-build-artifacts.ps1`, `fix-version-ranges.ps1`, and `check-test-naming.ps1` by reusing the shared `console-style.ps1` and `repository-paths.ps1` helpers, and expanded `Resolve-SolutionOrLayoutRoot` to cover solution roots plus `src + .github` layouts.

## [9.9.9] - 2026-03-20

### Changed
- Centralized the shared runtime execution contract so install/bootstrap/doctor/healthcheck/self-heal/audit export now resolve repo root, runtime profile, effective runtime locations, canonical targets, and source layout from one shared helper instead of duplicating target/profile resolution logic:
  - `scripts/common/runtime-execution-context.ps1`
  - `scripts/common/common-bootstrap.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/validation/export-audit-report.ps1`
  - `README.md`
  - `scripts/README.md`
- Added a second shared runtime operation helper so healthcheck/self-heal/audit export now reuse one contract for resolved output/log artifact initialization and managed `check`/`step` child-script invocation, while validation logging now reuses the verbose helpers already centralized in `repository-paths.ps1`:
  - `scripts/common/runtime-operation-support.ps1`
  - `scripts/common/runtime-execution-context.ps1`
  - `scripts/common/validation-logging.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/validation/export-audit-report.ps1`
  - `scripts/README.md`
- Added smoke-test coverage for closeout-driven README and CHANGELOG updates.

## [1.2.0] - 2026-03-20

### Changed
- Added Phase 1 Super Agent hardening through explicit approval gating for sensitive orchestration stages and agents, persisted approval records in run artifacts, and approval parameter forwarding on the execute/parallel entrypoints:
  - `.github/schemas/agent.contract.schema.json`
  - `.github/schemas/agent.run-artifact.schema.json`
  - `.codex/orchestration/agents.manifest.json`
  - `scripts/runtime/run-agent-pipeline.ps1`
  - `scripts/runtime/invoke-super-agent-execute.ps1`
  - `scripts/runtime/invoke-super-agent-parallel-dispatch.ps1`
  - `scripts/validation/validate-agent-orchestration.ps1`
  - `scripts/tests/runtime/agent-orchestration-engine.tests.ps1`
  - `scripts/tests/runtime/super-agent-entrypoints.tests.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
  - `README.md`
  - `scripts/README.md`
- Reduced duplicated validator logging scaffolding by introducing a shared `scripts/common/validation-logging.ps1` helper and moving the validation script family plus `runtime/validate-vscode-global-alignment.ps1` onto the shared warning/failure/verbose contract:
  - `scripts/common/validation-logging.ps1`
  - `scripts/common/repository-paths.ps1`
  - `scripts/validation/*.ps1`
  - `scripts/runtime/validate-vscode-global-alignment.ps1`
  - `scripts/README.md`
- Expanded `scripts/common/repository-paths.ps1` into the shared infrastructure boundary for runtime, security, orchestration, and runtime test scripts by centralizing repository/git/solution root discovery, generic path conversion helpers, verbose logging, and execution issue reporting while removing duplicated helper blocks from the affected script families:
  - `scripts/common/repository-paths.ps1`
  - `scripts/runtime/*.ps1`
  - `scripts/security/*.ps1`
  - `scripts/orchestration/**/*.ps1`
  - `scripts/tests/runtime/*.ps1`
  - `scripts/README.md`
- Added `scripts/common/common-bootstrap.ps1` as the shared helper-loader bootstrap and migrated runtime, validation, orchestration, security, test, governance, git-hook, maintenance, deploy, and documentation scripts onto the same import contract for `console-style`, `repository-paths`, `runtime-paths`, and `validation-logging`:
  - `scripts/common/common-bootstrap.ps1`
  - `scripts/runtime/*.ps1`
  - `scripts/validation/*.ps1`
  - `scripts/orchestration/**/*.ps1`
  - `scripts/security/*.ps1`
  - `scripts/tests/**/*.ps1`
  - `scripts/governance/*.ps1`
  - `scripts/git-hooks/*.ps1`
  - `scripts/maintenance/*.ps1`
  - `scripts/deploy/*.ps1`
  - `scripts/doc/*.ps1`
  - `scripts/README.md`

### Fixed
- Made runtime sync/install and Git hook helpers portable across machines and OS layouts by introducing a versioned runtime location catalog plus machine-local overrides, replacing hardcoded `%USERPROFILE%\\.github` / `%USERPROFILE%\\.codex` assumptions with shared `githubRuntimeRoot`, `codexRuntimeRoot`, `agentsSkillsRoot`, and `copilotSkillsRoot` resolution across the runtime toolchain:
  - `.github/governance/runtime-location-catalog.json`
  - `scripts/common/runtime-paths.ps1`
  - `scripts/common/common-bootstrap.ps1`
  - `scripts/common/repository-paths.ps1`
  - `scripts/common/runtime-install-profiles.ps1`
  - `scripts/common/git-hook-eof-settings.ps1`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/runtime/clean-codex-runtime.ps1`
  - `scripts/runtime/sync-vscode-global-settings.ps1`
  - `scripts/runtime/sync-vscode-global-snippets.ps1`
  - `scripts/runtime/validate-vscode-global-alignment.ps1`
  - `scripts/git-hooks/setup-git-hooks.ps1`
  - `scripts/git-hooks/setup-global-git-aliases.ps1`
  - `scripts/git-hooks/invoke-pre-commit-eof-hygiene.ps1`
  - `.codex/scripts/sync-mcp-to-codex-config.ps1`
  - `scripts/validation/export-audit-report.ps1`
  - `README.md`
  - `scripts/README.md`
- Reduced `post-commit` latency by gating expensive work on the actual files changed in `HEAD`, so runtime bootstrap and VS Code global alignment now skip unrelated commits while MCP apply still targets the effective Codex runtime root:
  - `.githooks/post-commit`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/common/runtime-paths.ps1`
  - `README.md`
  - `scripts/README.md`
- Added a configurable EOF hygiene mode for Git hooks so each clone/PC can keep the default `manual` behavior, opt into intrusive staged-file autofix during `pre-commit`, and choose whether the setting is stored per repo clone or globally for the machine, with `global` now configuring a real machine-wide `core.hooksPath` and the effective mode resolved on every commit:
  - `.github/governance/git-hook-eof-modes.json`
  - `scripts/common/git-hook-eof-settings.ps1`
  - `scripts/common/runtime-paths.ps1`
  - `scripts/git-hooks/setup-git-hooks.ps1`
  - `scripts/git-hooks/invoke-pre-commit-eof-hygiene.ps1`
  - `.githooks/pre-commit`
  - `scripts/runtime/install.ps1`
  - `scripts/maintenance/trim-trailing-blank-lines.ps1`
  - `scripts/tests/runtime/git-hook-eof-hygiene.tests.ps1`
  - `scripts/tests/runtime/install-runtime.tests.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
  - `README.md`
  - `scripts/README.md`
- Removed volatile metadata churn from versioned planning artifacts so active plan/spec files no longer rewrite timestamps or trace metadata on repeated stage runs, and moving them to `planning/completed` now preserves file timestamps:
  - `scripts/orchestration/stages/plan-stage.ps1`
  - `scripts/orchestration/stages/spec-stage.ps1`
  - `scripts/orchestration/stages/closeout-stage.ps1`
  - `scripts/tests/runtime/agent-orchestration-engine.tests.ps1`
- Added a repository-owned global Git alias setup flow for manual EOF cleanup across arbitrary repositories and fixed the Windows shell invocation so `git trim-eof` correctly executes the runtime-synced trim script in `-GitChangedOnly` mode:
  - `scripts/git-hooks/setup-global-git-aliases.ps1`
  - `scripts/common/runtime-paths.ps1`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/tests/runtime/git-global-aliases.tests.ps1`
  - `scripts/tests/runtime/install-runtime.tests.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
  - `README.md`
  - `scripts/README.md`
- Fixed fresh clones leaving the repository dirty before any user change because a set of tracked PowerShell scripts were committed with mixed line endings under the repository `*.ps1 eol=crlf` policy:
  - `scripts/deploy/deploy-backend-to-vps.ps1`
  - `scripts/git-hooks/setup-git-hooks.ps1`
  - `scripts/governance/set-branch-protection.ps1`
  - `scripts/maintenance/generate-http-from-openapi.ps1`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/tests/run-coverage.ps1`
  - `scripts/validation/export-audit-report.ps1`
  - `scripts/validation/validate-policy.ps1`
  - `scripts/validation/validate-release-governance.ps1`
- Added a PowerShell standards guardrail to fail when tracked `.ps1` files are stored in Git with mixed or non-normalized index line endings:
  - `scripts/validation/validate-powershell-standards.ps1`
- Fixed shell hook PowerShell boolean invocation so validation no longer fails after `post-merge`, `pre-commit`, or `post-checkout`, including shell-safe quoting for PowerShell boolean literals in POSIX hooks:
  - `.githooks/pre-commit`
  - `.githooks/post-merge`
  - `.githooks/post-checkout`
- Fixed Codex runtime cleanup byte aggregation when expired log/session collections are empty:
  - `scripts/runtime/clean-codex-runtime.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
- Extended shell-hook validation to catch unsupported PowerShell boolean argument forms that pass shell syntax checks but fail at runtime:
  - `scripts/validation/validate-shell-hooks.ps1`
- Fixed the shared VS Code formatter baseline so repository-managed settings no longer route JS/TS/HTML/CSS/SCSS/Vue/JSON/Markdown through Prettier by default, avoiding automatic final newline reintroduction against the repository EOF policy:
  - `.vscode/settings.tamplate.jsonc`
  - `scripts/tests/runtime/vscode-global-settings-sync.tests.ps1`
  - `.github/instructions/vscode-workspace-efficiency.instructions.md`
- Hardened `validate-all.ps1` to accept external boolean-like string values for `WarningOnly`, so older shell hooks and stale local clones no longer fail argument binding before the suite starts:
  - `scripts/validation/validate-all.ps1`
- Reconfirmed the shell-safe quoted PowerShell boolean literal convention for Git hooks:
  - `.githooks/pre-commit`
  - `.githooks/post-checkout`
  - `.githooks/post-merge`
  - `scripts/validation/validate-shell-hooks.ps1`
- Reduced false-positive install and healthcheck noise by making the runtime test runner suppress child test fixture output on success and replay it only for verbose runs or real failures:
  - `scripts/validation/validate-runtime-script-tests.ps1`
  - `scripts/README.md`
- Moved repository EOF enforcement closer to the VS Code AI edit origin by adding a repository-owned `PreToolUse` hook that strips terminal newlines from supported edit/create tool payloads before files are written:
  - `.github/hooks/super-agent.bootstrap.json`
  - `.github/hooks/scripts/common.ps1`
  - `.github/hooks/scripts/pre-tool-use.ps1`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
  - `scripts/validation/validate-agent-hooks.ps1`
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `.github/instructions/repository-operating-model.instructions.md`
- Removed duplicate repo-managed skill entries from the VS Code/Codex picker by making `%USERPROFILE%\\.agents\\skills` the canonical visible/runtime target and cleaning stale repo-managed duplicates from `%USERPROFILE%\\.codex\\skills`:
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
- Reduced local post-commit latency without changing the default hook contract by collapsing repository skill projection in `bootstrap.ps1` into a single root sync when `robocopy` is available and by overlapping runtime cleanup with VS Code global alignment validation in `.githooks/post-commit`:
  - `.githooks/post-commit`
  - `scripts/runtime/bootstrap.ps1`
- Hardened the shared VS Code settings baseline against terminal newline reintroduction by keeping format-on-paste and format-on-type disabled, trimming extra final blank lines on save, and removing the shared Go `formatOnSave` override that conflicted with the repository EOF policy:
  - `.vscode/settings.tamplate.jsonc`
  - `.github/instructions/vscode-workspace-efficiency.instructions.md`
  - `scripts/tests/runtime/vscode-global-settings-sync.tests.ps1`
- Made the repository-owned `Super Agent` bootstrap universal across arbitrary workspaces by splitting startup behavior into `workspace-adapter` and `global-runtime` modes, falling back to `.build/super-agent/` when a target repo does not provide local `.github` and `planning/` surfaces:
  - `.github/hooks/scripts/common.ps1`
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `.github/instructions/super-agent.instructions.md`
  - `.github/instructions/subagent-planning-workflow.instructions.md`
  - `.github/instructions/brainstorm-spec-workflow.instructions.md`
  - `.codex/skills/super-agent/SKILL.md`
  - `.codex/skills/using-super-agent/SKILL.md`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
  - `scripts/validation/validate-agent-hooks.ps1`
- Added a visible Super Agent activation banner to the VS Code hook bootstrap contract so the first substantive reply in a session can make the controller state explicit to the user:
  - `.github/hooks/scripts/common.ps1`
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
- Aligned the picker-visible Super Agent skills with the runtime activation contract so `Using Super Agent` and `Super Agent` both declare the visible startup banner expectation:
  - `.codex/skills/using-super-agent/SKILL.md`
  - `.codex/skills/super-agent/SKILL.md`
- Simplified the VS Code Super Agent runtime to match the lighter `superpowers` activation model by keeping SessionStart as the primary visible bootstrap point, preserving the one-time activation banner contract, and removing prompt-level reinforcement plus local hook telemetry:
  - `.github/hooks/super-agent.bootstrap.json`
  - `.github/hooks/scripts/common.ps1`
  - `.github/hooks/scripts/session-start.ps1`
  - `.github/hooks/scripts/subagent-start.ps1`
  - `scripts/validation/validate-agent-hooks.ps1`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
- Simplified the repository-owned Super Agent startup surface to a single visible `super-agent` controller, removing the extra `using-super-agent` picker alias while preserving selector-based override support:
  - `.codex/skills/super-agent/SKILL.md`
  - `.codex/skills/README.md`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
  - `README.md`
  - `scripts/README.md`
- Hardened the Super Agent lifecycle so non-trivial change-bearing work now requires a planning-ready spec before planning can start:
  - `.github/instructions/super-agent.instructions.md`
  - `.github/instructions/brainstorm-spec-workflow.instructions.md`
  - `.github/instructions/subagent-planning-workflow.instructions.md`
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `.codex/skills/super-agent/SKILL.md`
- Added native GitHub Copilot Super Agent surfaces and runtime projection so the shared bootstrap now syncs repository-owned Copilot skills into `%USERPROFILE%\\.copilot\\skills` and exposes a repo-owned agent profile under `.github/agents/`:
  - `.github/skills/super-agent/SKILL.md`
  - `.github/agents/super-agent.agent.md`
  - `scripts/common/runtime-paths.ps1`
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/doctor.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/validation/export-audit-report.ps1`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
- Extended the manual EOF cleanup helper with a Git-status-scoped mode so trimming can be limited to files currently reported as changed instead of scanning the whole repository:
  - `scripts/maintenance/trim-trailing-blank-lines.ps1`
  - `scripts/tests/runtime/trim-trailing-blank-lines.tests.ps1`
- Added a shared runtime issue registry so `install.ps1`, `healthcheck.ps1`, and `self-heal.ps1` now assign stable `WRN###` / `ERR###` IDs to logged warnings and errors and always finish with a deduplicated issue summary plus severity counts:
  - `scripts/common/repository-paths.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/tests/runtime/install-runtime.tests.ps1`
  - `scripts/README.md`
- Updated governance thresholds and validation-ledger handling so the current runtime/instruction size and analyzer baseline no longer produce avoidable warning-only noise, and broken local ledgers are archived before a new chain starts:
  - `.github/governance/instruction-ownership.manifest.json`
  - `.github/governance/warning-baseline.json`
  - `scripts/validation/validate-all.ps1`

### Added
- Added a versioned brainstorm/spec layer before execution planning:
  - `.github/instructions/brainstorm-spec-workflow.instructions.md`
  - `.github/schemas/agent.stage-spec-result.schema.json`
  - `.codex/orchestration/prompts/spec-stage.prompt.md`
  - `scripts/orchestration/stages/spec-stage.ps1`
  - `.codex/skills/brainstorm-spec-architect/SKILL.md`
  - `.codex/skills/brainstorm-spec-architect/agents/openai.yaml`
- Added a dedicated specification workspace under `planning/specs/` with active and completed spec handling.
- Added closeout automation planning record:
  - `planning/active/plan-closeout-readme-changelog-automation.md`
- Added repository-owned VS Code agent hook bootstrap assets:
  - `.github/hooks/super-agent.bootstrap.json`
  - `.github/hooks/scripts/common.ps1`
  - `.github/hooks/scripts/session-start.ps1`
  - `.github/hooks/scripts/subagent-start.ps1`
- Added a canonical artifact layout instruction:
  - `.github/instructions/artifact-layout.instructions.md`
- Added validation coverage for repository-owned agent hooks:
  - `scripts/validation/validate-agent-hooks.ps1`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`
- Added shared repository runtime helper:
  - `scripts/common/repository-paths.ps1`
- Added CI wrapper for the warning-only pre-build security snapshot:
  - `scripts/security/Invoke-CiPreBuildSecuritySnapshot.ps1`
  - `scripts/tests/runtime/ci-security-snapshot.tests.ps1`
- Added a picker-visible repository starter alias for the repo-owned lifecycle controller:
  - `.codex/skills/using-super-agent/SKILL.md`
  - `.codex/skills/using-super-agent/agents/openai.yaml`
- Added a versioned startup-controller selector for repository-owned VS Code hooks so the bootstrap can keep `Super Agent` as the default while allowing untracked local or environment overrides:
  - `.github/hooks/super-agent.selector.json`
  - `scripts/validation/validate-agent-hooks.ps1`
  - `scripts/tests/runtime/vscode-agent-hooks.tests.ps1`

### Changed
- Updated the global transparency contract so every substantive terminal-facing completion message must explicitly report the controller and any specialists or subagents used, or state that no specialist/delegated agent was used:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
- Tightened the same transparency contract so the final `Agents used:` line must render each reported agent name in backticks, such as `Super Agent`:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
- Upgraded the repository-owned orchestration lifecycle from:
  - `intake -> plan -> route -> implement -> validate -> review -> closeout`
  to:
  - `intake -> spec -> plan -> route -> implement -> validate -> review -> closeout`
- Updated closeout contracts so release closeout can apply documentation updates directly when the workstream is ready for commit:
  - `.github/schemas/agent.stage-closeout-result.schema.json`
  - `.codex/orchestration/prompts/closeout-stage.prompt.md`
  - `scripts/orchestration/stages/closeout-stage.ps1`
- Extended closeout outputs with structured release artifacts:
  - `readme-updates`
  - `changelog-update`
- Updated orchestration contracts and docs:
  - `.codex/orchestration/agents.manifest.json`
  - `.codex/orchestration/pipelines/default.pipeline.json`
  - `.codex/orchestration/templates/run-artifact.template.json`
  - `.codex/orchestration/README.md`
- Updated repository guidance and planning rules:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `.github/instruction-routing.catalog.yml`
  - `.github/instructions/repository-operating-model.instructions.md`
  - `.github/instructions/subagent-planning-workflow.instructions.md`
  - `.github/instructions/super-agent.instructions.md`
  - `planning/README.md`
  - `planning/specs/README.md`
  - `README.md`
- Updated the VS Code global settings template to load repository-owned hooks from `~/.github/hooks` in addition to workspace `.github/hooks`:
  - `.vscode/settings.tamplate.jsonc`
- Deduplicated push-time CI validation coverage:
  - `validate-agent-system.yml` remains the push-time owner for healthcheck and `validate-all`
  - `enterprise-trends-dashboard.yml` is now schedule/manual only
  - `dependency-risk-observability.yml` and `enterprise-trends-dashboard.yml` now share the same warning-only CI security snapshot wrapper
- Hardened MCP config sync for mixed server manifests so onboarding with `-ApplyMcpConfig` no longer fails when some servers expose `command/args` while others expose `url` only:
  - `.codex/scripts/sync-mcp-to-codex-config.ps1`
  - `scripts/tests/runtime/mcp-config-sync.tests.ps1`
- Hardened planner handoff contracts so work items now carry target paths, explicit commands, expected checkpoints, and commit checkpoint guidance:
  - `.github/schemas/agent.stage-plan-result.schema.json`
  - `.codex/orchestration/prompts/planner-stage.prompt.md`
  - `.codex/skills/plan-active-work-planner/SKILL.md`
  - `.codex/skills/plan-task-planner/SKILL.md`
  - `scripts/orchestration/stages/plan-stage.ps1`
  - `scripts/orchestration/stages/implement-stage.ps1`
  - `scripts/tests/runtime/agent-orchestration-engine.tests.ps1`
- Consolidated shared helper usage in critical scripts:
  - `scripts/runtime/bootstrap.ps1`
  - `scripts/runtime/install.ps1`
  - `scripts/runtime/apply-vscode-templates.ps1`
  - `scripts/runtime/healthcheck.ps1`
  - `scripts/runtime/self-heal.ps1`
  - `scripts/runtime/run-agent-pipeline.ps1`
  - `scripts/validation/export-audit-report.ps1`
- Updated runtime bootstrap documentation and smoke coverage so repository-owned local skills are documented and verified in both `~/.codex/skills` and picker-visible `~/.agents/skills` projections:
  - `.codex/skills/README.md`
  - `README.md`
  - `scripts/README.md`
  - `scripts/tests/runtime/runtime-scripts.tests.ps1`
- Tightened the PowerShell authoring contract so function description comments must explain purpose and clarify parameter expectations, side effects, or returned values when behavior is not obvious:
  - `.github/instructions/powershell-script-creation.instructions.md`
- Updated runtime and skill documentation so repo-managed skills are documented as canonical under `%USERPROFILE%\\.agents\\skills` rather than mirrored visibly in `%USERPROFILE%\\.codex\\skills`:
  - `README.md`
  - `scripts/README.md`
  - `.codex/skills/README.md`
- Updated repository-owned VS Code hook bootstrap context so SessionStart and SubagentStart now announce the selected startup controller and respect this override order:
  - repository default from `.github/hooks/super-agent.selector.json`
  - local untracked override from `~/.github/hooks/super-agent.selector.local.json`
  - environment override from `COPILOT_SUPER_AGENT_SKILL` and `COPILOT_SUPER_AGENT_NAME`
  - files updated:
    - `.github/hooks/scripts/common.ps1`
    - `README.md`
    - `scripts/README.md`

### Removed
- Removed placeholder `.gitkeep` files from the planning workspace:
  - `planning/active/.gitkeep`
  - `planning/completed/.gitkeep`
  - `planning/specs/active/.gitkeep`
  - `planning/specs/completed/.gitkeep`

### Feedback Integration
- File: `scripts/orchestration/stages/closeout-stage.ps1` | context: release closeout automation | problem: closeout only suggested README and changelog actions and did not update repository docs | solution: added structured README rewrite payloads, structured changelog update payloads, safe repository-relative write enforcement, and output evidence artifacts | workspace-impact: closeout can now finish documentation updates together with commit guidance when the workstream is ready.
- File: `scripts/validation/validate-planning-structure.ps1` | context: planning workspace hygiene | problem: planning structure depended on placeholder `.gitkeep` files to keep empty folders tracked | solution: changed the planning contract to create subdirectories on demand and removed placeholder-file requirements from validation and runtime tests | workspace-impact: cleaner planning workspace with fewer artificial artifacts and less git noise.

## [1.1.8] - 2026-03-10

### Changed
- Updated commit guidance to require semantic commit prefixes for suggested commit messages and ready-to-commit notifications:
  - `feat:`
  - `fix:`
  - `docs:`
  - `refactor:`
  - `test:`
  - `chore:`
  - `perf:`
  - `build:`
  - `ci:`
- Updated instruction files:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`

## [1.1.7] - 2026-03-10

### Changed
- Updated commit workflow guidance so agents now:
  - return a suggested commit message when a logical item is finished
  - explicitly signal when the current state is ready to commit
  - surface stable intermediate commit checkpoints during large tasks
- Updated instruction files:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`

## [1.1.6] - 2026-02-27

### Added
- Added unified pre-build security gate script:
  - `scripts/security/Invoke-PreBuildSecurityGate.ps1`
- Added frontend dependency vulnerability audit script:
  - `scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1`
- Added Rust dependency vulnerability audit script:
  - `scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1`
- Added runtime-shared security scripts distribution:
  - `.codex/scripts/common/console-style.ps1`
  - `.codex/scripts/security/Invoke-PreBuildSecurityGate.ps1`
  - `.codex/scripts/security/Invoke-VulnerabilityAudit.ps1`
  - `.codex/scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1`
  - `.codex/scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1`
- Added dedicated security skill:
  - `.codex/skills/security-vulnerability-engineer/SKILL.md`
  - `.codex/skills/security-vulnerability-engineer/agents/openai.yaml`

### Changed
- Updated .NET audit script summary/examples:
  - `scripts/security/Invoke-VulnerabilityAudit.ps1`
- Updated build-oriented skills to enforce dependency vulnerability audit before build/package:
  - `.codex/skills/software-engineer/SKILL.md`
  - `.codex/skills/dotnet-backend-engineer/SKILL.md`
  - `.codex/skills/frontend-vue-quasar-engineer/SKILL.md`
  - `.codex/skills/rust-engineer/SKILL.md`
  - `.codex/skills/devops-platform-engineer/SKILL.md`
  - `.codex/skills/test-engineer/SKILL.md`
- Updated security instruction with practical SCA automation commands:
  - `.github/instructions/security-vulnerabilities.instructions.md`
- Extended security route triggers for dependency-audit terms:
  - `.github/instruction-routing.catalog.yml`
- Updated documentation references:
  - `scripts/README.md`
  - `.codex/scripts/README.md`
  - `.codex/skills/README.md`
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`

### Feedback Integration
- File: `scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1` | context: frontend package audit automation | problem: no dedicated vulnerability gate script for npm/pnpm/yarn before build | solution: introduced manager-aware audit with severity gate and report artifacts | workspace-impact: consistent frontend SCA gate and reproducible evidence.
- File: `scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1` | context: rust package audit automation | problem: no dedicated Rust vulnerability gate before cargo build/test | solution: introduced cargo-audit based script with normalized severity handling and summary artifacts | workspace-impact: standardized Rust SCA gate with explicit fail thresholds.

## [1.1.5] - 2026-02-27

### Added
- Added script-authoring assets:
  - `.github/templates/powershell-script-template.ps1`
  - `.github/prompts/create-powershell-script.prompt.md`
- Added missing .NET hosted-worker template:
  - `.github/templates/background-service-template.cs`

### Changed
- Updated PowerShell template and prompt references:
  - `.github/instructions/powershell-script-creation.instructions.md`
  - `.github/instructions/prompt-templates.instructions.md`
  - `.github/instruction-routing.catalog.yml`
  - `README.md` (Prompt Templates section)

### Feedback Integration
- File: `.github/templates/powershell-script-template.ps1` | context: PowerShell script scaffolding | problem: no canonical script template for `scripts/*` workflows | solution: created a template with repo-root resolution, dry-run support, warning tracking, and deterministic summary output | workspace-impact: consistent and faster script authoring with lower drift.

## [1.1.4] - 2026-02-26

### Added
- Added cross-layer security instruction:
  - `.github/instructions/security-vulnerabilities.instructions.md`
  - covers API, frontend, backend, and database vulnerability prevention aligned with current OWASP and NIST baselines.
- Added routing coverage fixture for security route:
  - `scripts/validation/fixtures/routing-golden-tests.json`

### Changed
- Updated static routing catalog with dedicated security route:
  - `.github/instruction-routing.catalog.yml`
  - new route id `security-vulnerabilities` with OWASP/security-focused triggers.
- Updated instruction references to include the new security instruction:
  - `.github/AGENTS.md`
  - `.github/copilot-instructions.md`
  - `README.md` instruction matrix

### Feedback Integration
- File: `.github/instructions/security-vulnerabilities.instructions.md` | context: secure development baseline | problem: security guidance was fragmented across domain files | solution: consolidated a dedicated OWASP/NIST-aligned instruction for API, frontend, backend, and database | workspace-impact: clearer security posture and consistent vulnerability prevention guidance.

## [1.1.3] - 2026-02-25

### Added
- Added `agents/openai.yaml` metadata to all repository-managed skills under `.codex/skills/*` for better UI discovery and explicit default prompts.
- Added deterministic routing golden tests:
  - `scripts/validation/test-routing-selection.ps1`
  - `scripts/validation/fixtures/routing-golden-tests.json`
- Added runtime diagnostics script:
  - `scripts/runtime/doctor.ps1` for drift detection between repo source-of-truth and local `~/.github` / `~/.codex`.
- Added PowerShell authoring instruction:
  - `instructions/powershell-script-creation.instructions.md`

### Changed
- Extended `scripts/validation/validate-instructions.ps1` with skill lint:
  - validates `SKILL.md` frontmatter (`name`, `description`)
  - validates skill-folder/name consistency
  - validates `agents/openai.yaml` contract fields
  - enforces skill file size guardrail and emits skill summary
  - runs routing golden tests as part of validation
- Updated `.githooks/post-commit` with optional MCP apply when `.codex/mcp/servers.manifest.json` changes (enabled with `CODEX_APPLY_MCP_ON_POST_COMMIT=1`).
- Updated `scripts/git-hooks/setup-git-hooks.ps1` output to document post-commit MCP env flags.

### Feedback Integration
- File: scripts/validation/validate-instructions.ps1 | context: instruction quality gates | problem: skill contracts and routing behavior were not regression-tested | solution: added skill lint + golden routing tests in validation pipeline | workspace-impact: higher confidence and deterministic context selection
- File: scripts/runtime/doctor.ps1 | context: runtime sync reliability | problem: no quick drift diagnosis between repo and local runtime | solution: introduced doctor diagnostics with optional auto-fix via bootstrap | workspace-impact: faster troubleshooting and safer local runtime hygiene

## [1.1.2] - 2026-01-29

### Changed
- Require XML documentation for all types and members (public/internal/private) in dotnet-csharp instructions, excluding test methods.

### Feedback Integration
- File: instructions/dotnet-csharp.instructions.md | context: XML documentation scope | problem: Instruction limited XML docs to public APIs | solution: Require XML docs for all accessibility levels except test methods | workspace-impact: Consistent documentation coverage across codebase

## [1.1.1] - 2026-01-05

### Changed
- Added explicit Rust documentation quality expectations to rust-code-organization and rust-testing instruction files.

### Feedback Integration
- File: instructions/rust-code-organization.instructions.md | context: Rust documentation guidance | problem: Doc comment completeness expectations were implicit | solution: Added self-explanatory doc comment standards and missing_docs lint guidance | workspace-impact: Clearer documentation quality baseline

## [1.1.0] - 2025-12-06

### Changed
- Consolidated VS Code workspace settings into single auto-loading configuration:
  - Merged `.github/.vscode/settings.copilot.jsonc` into `.github/.vscode/settings.json`
  - Enhanced header documentation with file structure breakdown and line range references
  - Simplified file tree documentation using wildcards (*.chatmode.md, *.instructions.md)
  - Replaced user-specific paths with portable %USERPROFILE% environment variable
  - Added comprehensive Copilot & AI Chat Configuration section with visual separators (lines 321-490)
  - Consolidated all Copilot enable settings, chat modes, MCP servers, and custom instructions

### Added
- Custom chat mode definitions for specialized development workflows (5 files):
  - `backend-csharp-expert.chatmode.md` - Backend development with C#/.NET expertise
  - `database-orm-expert.chatmode.md` - Database and ORM pattern guidance
  - `devops-infrastructure-expert.chatmode.md` - DevOps and infrastructure automation
  - `rust-expert.chatmode.md` - Rust language and ecosystem best practices
  - `vue-quasar-expert.chatmode.md` - Vue.js/Quasar frontend development
- Reusable prompt templates for common development tasks (7 files):
  - `create-api-endpoint.prompt.md` - RESTful API endpoint scaffolding
  - `create-docker-setup.prompt.md` - Docker containerization setup
  - `create-ef-migration.prompt.md` - Entity Framework migration creation
  - `create-rust-module.prompt.md` - Rust module scaffolding
  - `create-vue-component.prompt.md` - Vue component creation with Quasar
  - `generate-pr-description.prompt.md` - Pull request description generation
  - `refactor-to-clean-architecture.prompt.md` - Clean Architecture refactoring guidance
- Code snippets for Copilot command shortcuts:
  - `.github/.vscode/snippets/copilot.code-snippets` - Quick access snippets for Copilot workflows

### Fixed
- VS Code not auto-loading Copilot configuration from `.jsonc` extension file
  - VS Code only auto-loads `settings.json` by default; `.jsonc` files require explicit reference
  - All Copilot settings now in main workspace settings.json for immediate availability

## [1.0.9] - 2025-11-28

### Added
- Comprehensive executive summary document for stakeholder communication:
  - Complete repository overview with 26 instruction files detailed
  - Multi-stack technology coverage (.NET/C#, Rust, Vue.js/Quasar, Docker, Kubernetes)
  - 2 custom chat modes (clean-architecture-review, instruction-writer)
  - 5 POML templates for automated code generation
  - 15+ code templates for .NET, Rust, and infrastructure
  - Measurable benefits documentation (60-70% productivity improvement in test generation)
  - Recent metrics showcasing 87% reduction in POML validation errors
  - Day-to-day usage guide with practical examples
  - Recommended next steps for short, medium, and long-term expansion
  - Official references and standards documentation
  - Complete technology stack matrix covering all supported platforms

### Changed
- Enhanced README.md with multi-stack project description:
  - Updated description from ".NET projects" to "software projects covering .NET, Rust, Vue.js, and DevOps"
  - Expanded Features section highlighting multi-stack coverage
  - Reorganized Quick Start with examples for different technology stacks
  - Updated Usage Examples with diverse scenarios (.NET refactoring, Rust test generation, Vue component creation)
  - Restructured Instruction Files table by technology domain
  - Generalized Dependencies section for multiple SDKs
  - Removed Directory Structure section for cleaner documentation

### Fixed
- POML template validation issues with significant error reduction:
  - unit-test-generator.poml: Reduced from 40 to 10 errors (75% reduction)
  - changelog-entry.poml: Reduced from 48 to 1 error (98% reduction)
  - Corrected POML schema structure (removed XML declaration, changed root to `<poml>`)
  - Fixed metadata format from XML attributes to JSON structure
  - Simplified output-format to avoid special character parsing issues
  - Remaining errors confirmed as false positives from VS Code POML Reader extension
- Removed all FluentAssertions references from test templates:
  - Updated dotnet-unit-test-template.cs with native xUnit/NUnit assertions
  - Updated dotnet-integration-test-template.cs with native NUnit assertions (13 replacements)
  - Updated generate-unit-tests.prompt.md documentation
  - Updated POML README.md with correct assertion patterns

### Documentation
- Created resumo-instrucoes-copilot.txt executive summary (14 comprehensive sections)
- Updated all POML-related documentation to reflect correct schema patterns
- Enhanced template documentation with clear usage examples and validation status

## [1.0.8] - 2025-09-20

### Changed
- Complete formatting standardization across remaining instruction files:
  - Applied # headers and bullet point formatting to 10 additional instruction files
  - Added comprehensive code examples with appropriate language specifications
  - Enhanced structural consistency and readability
  - Files updated: `pr.instructions.md`, `powershell-execution.instructions.md`, `feedback-changelog.instructions.md`, `effort-estimation-ucp.instructions.md`, `e2e-testing.instructions.md`, `prompt-templates.instructions.md`, `readme.instructions.md`, `static-analysis-sonarqube.instructions.md`, `workflow-optimization.instructions.md`
- All instruction files now follow consistent Markdown hierarchy and formatting standards

## [1.0.7] - 2025-09-19

### Changed
- Complete section standardization across five instruction files:
  - Converted all section headers from "Section:" format to "# Section" format
  - Standardized all lists to use bullet points for improved readability
  - Added comprehensive code examples in appropriate languages (C#, YAML, SQL, CSS, HTML, JavaScript, Vue)
  - Enhanced formatting consistency and hierarchical structure
  - Files updated: `clean-architecture-code.instructions.md`, `microservices-performance.instructions.md`, `orm.instructions.md`, `ui-ux.instructions.md`, `vue-quasar.instructions.md`

## [1.0.6] - 2025-09-18

### Changed
- Comprehensive markdown heading hierarchy standardization across all instruction files:
  - Converted section headers from "Section:" format to "# Section" format for professional presentation
  - Applied consistent heading structure (# for main sections, ## for subsections, ### for detailed breakdowns)
  - Standardized formatting in `frontend.instructions.md`, `backend.instructions.md`, `database.instructions.md`, `docker.instructions.md`, and `ci-cd-devops.instructions.md`
  - Enhanced readability and navigation consistency across entire instruction documentation system
  - Maintained all technical content while improving structural organization and visual hierarchy

## [1.0.5] - 2025-09-18

### Changed
- Simplified formatting across all VS Code customization files:
  - Removed markdown title markers (hashtags) from custom chat modes and prompt files
  - Cleaned formatting in all `.chatmode.md` and `.prompt.md` files for minimal, distraction-free content
- Integrated context preservation guidelines into `AGENTS.md`:
  - Added session continuity strategies and execution flow patterns
  - Included quality gates and command usage patterns
  - Consolidated context preservation rules directly into agent policy file
  - Removed separate `context-preservation.instructions.md` file

## [1.0.4] - 2025-09-18

### Added
- Context preservation instruction for AI assistants (`instructions/context-preservation.instructions.md`):
  - Comprehensive execution patterns for maintaining architectural integrity
  - Session continuity strategies inspired by GitHub's spec-kit methodology
  - Quality gates and validation checklists for development workflows
  - Integration with existing repository standards and Clean Architecture principles

## [1.0.3] - 2025-09-18

### Added
- Enhanced VS Code workspace configuration with AI/Chat tools support:
  - Added `chat.enable` and `chat.agent.maxRequests` settings in `.vscode/settings.json`
  - Extended ChatGPT integration capabilities
- Comprehensive `.gitignore` file with Visual Studio and .NET build artifacts exclusion patterns
- Documentation completeness with expanded references section in `README.md`:
  - Official Microsoft documentation links for GitHub Copilot
  - Expert articles on prompt crafting and instruction optimization
- Custom Chat Modes for specialized development workflows:
  - `chatmodes/instruction-writer.chatmode.md` — specialized mode for creating/editing instruction files
  - `chatmodes/clean-architecture-review.chatmode.md` — code review mode focused on Clean Architecture compliance
- Reusable Prompt Files for common development tasks:
  - `prompts/generate-changelog.prompt.md` — automated CHANGELOG entry generation
  - `prompts/create-dotnet-class.prompt.md` — .NET class creation following repository templates
  - `prompts/generate-unit-tests.prompt.md` — comprehensive unit test generation

### Changed
- Updated `templates/changelog-entry-template.md` to reflect actual CHANGELOG writing patterns:
  - Removed emoji-based categorization in favor of clean text format
  - Added pattern guidelines and formatting rules
  - Aligned with established repository conventions
- Restructured instruction files with enhanced formatting and code examples:
  - `backend.instructions.md` — improved organization for Clean Architecture, CQRS, Events, API design, Security, and Testing patterns
  - `clean-architecture-code.instructions.md` — comprehensive examples for SOLID principles, domain modeling, dependency management, and testing strategies
  - `database.instructions.md` — detailed SQL examples, performance tuning, security practices, and monitoring guidance
  - `frontend.instructions.md` — clear sections for architecture, HTTP handling, performance optimization, and security practices
  - `microservices-performance.instructions.md` — comprehensive sections covering service boundaries, resource efficiency, monitoring, and deployment
  - `orm.instructions.md` — enhanced separation of domain, mapping, repositories, queries, and observability concerns
  - `ui-ux.instructions.md` — improved accessibility guidelines, responsive design patterns, and UX best practices
  - `vue-quasar.instructions.md` — specific examples for SFC, composables, routing, and performance optimization
  - `dotnet-csharp.instructions.md` — enhanced code organization patterns, testing templates, and XML documentation guidelines
- Updated template consistency and naming conventions:
  - `dotnet-class-template.cs` — PascalCase placeholders and enhanced XML documentation structure
  - `dotnet-interface-template.cs` — implicit usings support and cleaner namespace organization
  - `dotnet-integration-test-template.cs` — Native NUnit assertions integration and comprehensive test scenarios
  - `dotnet-unit-test-template.cs` — framework-agnostic design supporting both xUnit and NUnit with native assertions

## [1.0.2] - 2025-09-17

### Added
- Enhanced `templates/dotnet-class-template.cs` with comprehensive static members organization:
  - Added `#region Constants` for constant fields (string and integer types)
  - Added `#region Static Variables` for static readonly fields and Lazy dependencies
  - Added `#region Static Properties` for static properties with custom getters/setters
  - Updated usage comments with examples for all new placeholders
  - Improved template documentation with clear separation between variables and properties

### Changed
- Updated template usage guide with new placeholder explanations:
  - `[CONSTANT_NAME]`, `[CONSTANT_VALUE]`, `[CONSTANT_NAME_INT]`, `[CONSTANT_VALUE_INT]`
  - `[STATIC_VARIABLE_DESCRIPTION]`, `[StaticVariableName]`, `[STATIC_VARIABLE_VALUE]`, `[staticDependencyName]`
  - `[STATIC_PROPERTY_DESCRIPTION]`, `[StaticPropertyName]`, `[PropertyAccessor]`, `[PropertySetter]`, `[StaticBooleanProperty]`

## [1.0.1] - 2025-09-14

### Added
- Updated `.github/copilot-instructions.md` with "STYLE (EOF and whitespace)" rules:
  - Do not leave a trailing blank line at the end of files.
  - For files under `.github/instructions/*.md` and Copilot/Codex instruction outputs: do NOT include a final newline (consistent with `AGENTS.md`).
  - For other files, follow `.editorconfig` rules (final newline usually enforced); always avoid trailing whitespace.

## [1.0.0] - 2025-09-13

### Added
- Core docs:
  - `AGENTS.md` — Agent policies, context selection and workflow.
  - `copilot-instructions.md` — Global rules and domain mapping for the repository.
  - `README.md` — Overview, quick start and contribution guidance.

- Instructions (`instructions/`):
  - `backend.instructions.md` — Backend development conventions.
  - `ci-cd-devops.instructions.md` — CI/CD pipeline standards and practices.
  - `clean-architecture-code.instructions.md` — Universal Clean Architecture principles.
  - `copilot-instruction-creation.instructions.md` — Rules to author/edit instruction files.
  - `database.instructions.md` — Database design and performance guidance.
  - `docker.instructions.md` — Containerization best practices.
  - `dotnet-csharp.instructions.md` — .NET/C# specific conventions and patterns.
  - `e2e-testing.instructions.md` — E2E and integration testing guidance.
  - `effort-estimation-ucp.instructions.md` — Estimation guidance (UCP).
  - `feedback-changelog.instructions.md` — Feedback workflow and changelog guidelines.
  - `frontend.instructions.md` — Frontend performance and quality standards.
  - `k8s.instructions.md` — Kubernetes manifests and Helm best practices.
  - `microservices-performance.instructions.md` — Performance, caching and resiliency.
  - `orm.instructions.md` — ORM mapping and repository conventions.
  - `powershell-execution.instructions.md` — PowerShell execution and safety rules.
  - `pr.instructions.md` — Pull request structure and requirements.
  - `prompt-templates.instructions.md` — Prompt templates guidelines.
  - `readme.instructions.md` — README authoring rules.
  - `static-analysis-sonarqube.instructions.md` — Static analysis and quality gates.
  - `ui-ux.instructions.md` — UI/UX and accessibility standards.
  - `vue-quasar.instructions.md` — Vue + Quasar specific guidance.
  - `workflow-optimization.instructions.md` — Workflow and token efficiency rules.

- Templates (`templates/`):
  - `changelog-entry-template.md` — Changelog entry template.
  - `copilot-instruction-creation.instructions-template.md` — Instruction authoring template.
  - `docker-compose-template.yml` — Docker Compose base template.
  - `dotnet-class-template.cs` — .NET class with XML docs.
  - `dotnet-dockerfile-template` — .NET Dockerfile base template.
  - `dotnet-integration-test-template.cs` — .NET integration test template.
  - `dotnet-interface-template.cs` — .NET interface template.
  - `dotnet-unit-test-template.cs` — .NET unit test template.
  - `effort-estimation-poc-mvp-template.md` — Effort estimation (POC/MVP) template.
  - `github-change-checklist-template.md` — Checklist for changes in this repo.
  - `readme-template.md` — Standard README template.

- VS Code folder (`.vscode/`):
  - `snippets/copilot.code-snippets` — Custom instructions, commit/PR guidance, applied instructions block, quality gates, progress update, changelog entry, README mapping row.
  - `snippets/codex-cli.code-snippets` — Codex safe command; orchestration decision; task snippets (backend, frontend, ui-ux, infra, db, testing, readme, prompt, k8s, docker, ci-cd, sonar, performance, e2e, orm, ps, instruction, PR).
  - `settings.json` — Workspace settings.

### Changed
- Standardized snippet texts to English.
- Updated paths to match repo structure (`instructions/`, `templates/`); removed obsolete `.github/` references.
- Enforced mandatory context for Copilot (AGENTS.md, `copilot-instructions.md`, core instructions).
- Fixed minor validation issues (backticks, descriptions).
- add a versioned runtime-install profile catalog with explicit `none`, `github`, `codex`, and `all` modes so onboarding can stay non-intrusive by default
- make `install.ps1` default to profile `none` and require explicit opt-in for GitHub/Copilot runtime sync, Codex runtime sync, or the full onboarding flow
- make `bootstrap.ps1`, `doctor.ps1`, `healthcheck.ps1`, and `self-heal.ps1` runtime-profile aware while keeping their standalone default at `all`
- document the new profile model clearly in the repository README and scripts README, including explicit examples for `none`, `github`, `codex`, and `all`