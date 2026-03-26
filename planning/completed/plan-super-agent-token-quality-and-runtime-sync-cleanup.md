# Super Agent Token Quality And Runtime Sync Cleanup Plan

Generated: 2026-03-22 00:00
LastUpdated: 2026-03-26 05:17

## Status

- State: completed
- Spec: `planning/specs/completed/spec-super-agent-token-quality-and-runtime-sync-cleanup.md`
- Current safe slice implemented: instruction/prompt-level output economy, quality-first routing guidance, session-start continuity summaries, throttled housekeeping with planning export, runtime overflow fixes, context boundary monitoring, dating policy, progress logging, Stop hook for planning export, hardcoded-path removal, `.vscode` profile-base promotion, and Copilot `super-agent` deduplication across canonical skill plus secondary agent alias surfaces
- Current urgent slice completed: tasks 1a–1h below
- Current implementation slice completed: canonical MCP runtime catalog/renderers, initial local incremental RAG/CAG index, explicit intake clarification gate, and phase-1 definitions/projection separation for provider skills, GitHub instruction/runtime surfaces, and VS Code profiles are now in place
- Current safe retrieval slice completed: SessionStart/SubagentStart now inject short local indexed file references when available, `export-planning-summary.ps1` emits suggested indexed references, and housekeeping refreshes the local context index before exporting the handoff ✓ [2026-03-26 00:30]
- Completion: canonical MCP runtime ownership, initial local incremental RAG/CAG continuity retrieval, clarification-gated Super Agent intake, runtime hygiene, and the phase-1 definitions/projection separation are implemented and validated end-to-end; Rust/Cargo migration and repository cleanup remain intentionally out of scope for a future workstream

## Objective And Scope

Prepare the deferred follow-up that will keep quality-first behavior, avoid risky input/context trimming, and instead target safer output-side token economy plus an audit of the mirrored `.github` runtime-sync flow for duplicate or garbage command surfaces in VS Code. In the immediate slice, stop Codex local-session disk and token blowups and prune VS Code Copilot workspace trash by applying safer runtime defaults and stale-session cleanup that preserves active context. The resumed slice must also close the current MCP source-of-truth gap between `.vscode/mcp.tamplate.jsonc` and `.codex/mcp/servers.manifest.json` by planning one canonical runtime catalog with per-runtime renderers instead of continuing manual divergence.

Use `mksglu/context-mode` as the external reference baseline for the future local RAG/CAG implementation. Reuse its strong ideas where they fit this repository-owned runtime model: source-side context reduction instead of output post-processing, local-first persistence, searchable session continuity, and retrieval of only relevant continuity fragments after compaction or restart. Do not copy its platform/plugin architecture blindly; adapt only the durable patterns that fit this repository and its runtime contracts.

## Normalized Request Summary

The user does not want token-economy behavior to reduce quality. They want risky input/context compaction undone and the next optimization wave to focus on safer output-side economy, including shorter default responses, less duplication, and better local RAG/CAG usage. They also suspect the `.github` runtime sync may be leaving duplicate or garbage surfaces, visible as repeated `/super-agent` command entries in VS Code. In parallel, Codex local sessions are consuming extreme disk and likely amplifying token use through long reasoning chains and unbounded local session retention, while VS Code `Code/User/workspaceStorage` is accumulating multi-gigabyte Copilot state such as `GitHub.copilot-chat/local-index*.db` and huge `chatSessions/*.jsonl` files. The immediate safe fix is to enforce saner runtime defaults plus stale-session cleanup for both local runtimes without disabling strategic multi-agent use.

Fresh observations for the resumed slice on 2026-03-25:
- `.vscode/profiles/` and `.vscode/mcp-vscode-global.json` now exist locally and appear to describe optional VS Code profile + MCP activation surfaces that were not yet folded into the runtime source-of-truth model.
- the old `.vscode/profiles/setup-profiles.ps1` entrypoint was replaced by `scripts/runtime/setup-vscode-profiles.ps1`, and the stale `profile-vision-engine.json` references have already been removed from the versioned profile baseline.
- Copilot currently exposes multiple visible `super-agent` slash surfaces, so the duplication audit must now treat both workspace-local and mirrored/global runtime registration as concrete suspects instead of a hypothetical defect.
- Claude Code already has a `super-agent` skill and custom hooks under `.claude/settings.json`; this surface needs parity review so it does not drift from Copilot/Codex.
- The current routing prompt already allows clarifying questions, but the Super Agent intake/controller layer does not yet have a strong explicit rule to ask concise clarification questions when ambiguity materially changes planning or execution.
- `.codex/mcp/servers.manifest.json` is still a reduced subset that cannot safely replace `.vscode/mcp.tamplate.jsonc` because the current renderer drops `disabled`, `gallery`, `version`, `env`, and richer auth/input fields; the resumed planning slice now needs a canonical MCP catalog plus derived renderers.
- `infra/github/main.json` is now present and should be documented later as a GitHub ruleset artifact so it is not mistaken for runtime or MCP source-of-truth.

## Ordered Tasks

1. Apply safe Codex and VS Code runtime defaults and cleanup controls ✓ [2026-03-23 00:00]
   - [2026-03-22 00:00] Task 1 (runtime hygiene catalog, codex/vscode hygiene scripts, set-codex-runtime-preferences, install, hooks) — completed in prior session ✓ [2026-03-22 00:00]
   - [2026-03-23 00:00] 1a. Fix Int32 overflow in `clean-codex-runtime.ps1` — `[int]` → `[long]` for `MaxFileSizeBytes`, `MaxSessionFileSizeMB`, `MaxSessionStorageGB`, and `Resolve-OptionalNumericHygieneSetting` ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1b. Add `export-planning-summary.ps1` — standalone context handoff export script, auto-detects repo root, writes to `.temp/context-handoff-<ts>.md` or prints with `-PrintOnly` ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1c. Add `-ExportPlanningSummary` param to `clean-codex-runtime.ps1` and `clean-vscode-user-runtime.ps1` — exports handoff before applying cleanup ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1d. Fix empty-array bugs in `clean-vscode-user-runtime.ps1` — `Test-HasPlannedAncestor` call guarded when `$staleWorkspaceDirectoryPaths.Count -eq 0`; same in `Compress-RemovalPlan` ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1e. Fix hanging at `[7/7]` in `clean-vscode-user-runtime.ps1` — removed recursive `Get-PathStat` pre-scan loop; replaced `Invoke-RemovalPlan` directory size with `[long] 0`; added 7-step progress markers ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1f. Add Stop hook to `.claude/settings.json` — auto-exports planning summary when active plans exist at session close ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1g. Remove all hardcoded `\Users\tguis` paths — `architecture-boundaries.baseline.json`, `CLAUDE.md`, `install.ps1` examples, `.claude/settings.json` Bash permission ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 1h. Update `runtime-scripts.tests.ps1` — cover new params (`ExportPlanningSummary`, `RepoRoot`) in both cleanup scripts plus `export-planning-summary.ps1` functional test ✓ [2026-03-23 00:00]

2. Define safe output-economy rules and context boundary monitoring ✓ [2026-03-23 00:00]
   - [2026-03-22 00:00] Output economy rules, quality-first routing — completed in prior session ✓ [2026-03-22 00:00]
   - [2026-03-23 00:00] 2a. Add `## Context Boundary Monitoring` to `super-agent.instructions.md` — planning-first continuity, handoff export usage, cleanup commands, per-runtime session-end semantics ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 2b. Add `## Dating Policy (Mandatory)` to `subagent-planning-workflow.instructions.md` — `[YYYY-MM-DD HH:mm]` on all tasks, `Generated`/`LastUpdated` fields, example format ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 2c. Add `## Dating Policy (Mandatory)` to `brainstorm-spec-workflow.instructions.md` — `Generated`, key-decision timestamps, planning-readiness `Updated` line ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 2d. Add `## Iterative In-Session Directive Exception` to `subagent-planning-workflow.instructions.md` — clarifies when retroactive plan updates replace upfront spec/plan ✓ [2026-03-23 00:00]
   - [2026-03-23 00:00] 2e. Update `scripts/README.md` — add `export-planning-summary.ps1` to directory tree and API reference table ✓ [2026-03-23 00:00]

3. Define local RAG/CAG-first response guidance plus clarifying-question behavior
- [2026-03-25 00:00] Resume this slice with explicit clarification behavior instead of silent assumptions on ambiguous requests.
  - [2026-03-26 00:30] 3a. Aligned GitHub/Codex/Claude Super Agent instructions and skills to explicitly prefer the repository-owned local context index for targeted continuity recall instead of replaying large chat history, while preserving the clarification gate as a material-ambiguity stop ✓ [2026-03-26 00:30]
  - [2026-03-26 00:30] 3b. Updated bootstrap continuity to inject short `Local context refs:` suggestions from the repository-owned local context index when an index already exists, keeping plan/spec artifacts primary and indexed references secondary ✓ [2026-03-26 00:30]
   - Target paths:
     - `.github/AGENTS.md`
     - `.github/copilot-instructions.md`
     - `.github/instructions/repository-operating-model.instructions.md`
     - `.github/instructions/super-agent.instructions.md`
     - `.codex/orchestration/prompts/super-agent-intake-stage.prompt.md`
     - `.github/skills/super-agent/SKILL.md`
     - `.codex/skills/super-agent/SKILL.md`
     - `.claude/skills/super-agent/SKILL.md`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instruction-architecture.ps1 -RepoRoot . -WarningOnly:$false`
   - Checkpoints:
     - local repository retrieval stays preferred over repeated restatement
     - future guidance makes output shorter without trimming required working context
     - Copilot and Codex guidance stay aligned
     - Super Agent asks concise clarification questions when ambiguity changes plan, architecture, runtime behavior, or validation
     - Claude skill contract stays aligned with the same clarification behavior

4. Design a local incremental index for RAG/CAG and canonicalize MCP runtime source-of-truth
   - [2026-03-25 00:00] 4a. Promoted `.vscode/profiles/` to a versioned profile-baseline surface, removed its `.gitignore` exclusion, replaced the hardcoded setup script with JSON discovery + explicit profile selection, and removed stale `profile-vision-engine.json` references; `.vscode/mcp-vscode-global.json` remains a local helper surface for now ✓ [2026-03-25 00:00]
   - [2026-03-25 00:00] 4b. Treat `https://github.com/mksglu/context-mode` as the reference baseline for the local RAG/CAG slice: source-side context savings, local persistence, searchable continuity state, and retrieval of only relevant continuity on resume/compaction must be evaluated first before inventing a parallel design ✓ [2026-03-25 00:00]
   - [2026-03-25 18:30] 4c. Implemented the canonical MCP runtime catalog at `.github/governance/mcp-runtime.catalog.json` plus shared renderers/helpers for VS Code and Codex projections ✓ [2026-03-25 18:30]
   - [2026-03-25 18:30] 4d. Added renderer-parity validation so `.vscode/mcp.tamplate.jsonc` and `.codex/mcp/servers.manifest.json` are both treated as generated outputs from the canonical catalog instead of hand-maintained primaries ✓ [2026-03-25 18:30]
   - [2026-03-25 18:30] 4e. Implemented the initial local incremental context index (`update-local-context-index.ps1`, `query-local-context-index.ps1`) and wired housekeeping to refresh it before cleanup ✓ [2026-03-25 18:30]
   - [2026-03-26 00:30] 4e.1. Enriched `export-planning-summary.ps1` with `Suggested Local References` derived from the local context index so planning handoffs can point directly to the next best repository files without replaying large transcripts ✓ [2026-03-26 00:30]
   - [2026-03-25 19:00] 4f. Started structural definitions/projection cleanup by moving the VS Code profile entrypoint into `scripts/runtime/setup-vscode-profiles.ps1`, introducing `definitions/providers/{codex,claude}/skills/` plus `definitions/providers/vscode/profiles/` as authoritative non-code sources, and rendering `.codex/skills/`, `.claude/skills/`, and `.vscode/profiles/` through dedicated renderers instead of editing provider surfaces directly ✓ [2026-03-25 19:00]
   - Target paths:
     - `.github/governance/**`
     - `.vscode/profiles/**`
     - `.vscode/mcp.tamplate.jsonc`
     - `.vscode/mcp-vscode-global.json`
     - `.codex/mcp/servers.manifest.json`
     - `scripts/runtime/render-vscode-mcp-template.ps1`
     - `scripts/runtime/sync-codex-mcp-config.ps1`
     - `definitions/providers/github/**`
     - `.claude/**`
     - `scripts/runtime/**`
     - `scripts/common/**`
     - `.temp/` or future runtime cache/index location
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/runtime/doctor.ps1 -RepoRoot . -RuntimeProfile all -DetailedOutput`
   - Checkpoints:
     - `.vscode/profiles` is treated as a versioned reusable baseline with explicit local selection support through `scripts/runtime/setup-vscode-profiles.ps1`
     - `.vscode/mcp-vscode-global.json` is still classified as a local helper artifact until a runtime contract promotes it
     - the local index design explicitly documents which `context-mode` ideas are adopted, adapted, or rejected
     - index design covers add/update/delete invalidation
     - retrieval can reuse local code/instruction/planning summaries without rereading everything
     - one canonical local cache/index location is defined
     - one canonical MCP runtime catalog is defined with explicit VS Code full-fidelity fields and Codex/Claude projection rules
     - the Codex MCP manifest is treated as a generated subset instead of the primary source of truth
     - future README work documents `infra/github/main.json` as GitHub governance/ruleset configuration, not MCP/runtime config

5. Audit mirrored `.github` runtime-sync duplication plus Claude parity ✓ [2026-03-26 05:17]
   - [2026-03-25 00:00] 5a. Isolated duplicated Copilot `super-agent` visibility to overlapping legacy starter surfaces and switched bootstrap from projecting `.github/skills` into `copilotSkillsRoot` to removing legacy `super-agent` / `using-super-agent` entries from both `githubRuntimeRoot/skills` and `copilotSkillsRoot`, leaving the shared `%USERPROFILE%\\.agents\\skills` surface canonical ✓ [2026-03-25 00:00]
   - [2026-03-26 05:17] 5b. Claude runtime docs/skills/settings remained aligned with the same canonical MCP catalog, clarification behavior, and continuity guidance after the local RAG/CAG and controller cleanup slice; any future Claude-only MCP projection work must reopen as a new targeted workstream ✓ [2026-03-26 05:17]
   - Target paths:
     - `scripts/runtime/bootstrap.ps1`
     - `scripts/runtime/install.ps1`
     - `scripts/runtime/doctor.ps1`
     - `scripts/common/runtime-paths.ps1`
     - `.github/hooks/**`
     - `.github/agents/**`
     - `.github/skills/**`
     - `.claude/settings.json`
     - `.claude/skills/**`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/runtime/doctor.ps1 -RepoRoot . -RuntimeProfile all -DetailedOutput`
     - `pwsh -NoLogo -NoProfile -File scripts/runtime/install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig -GitHookEofMode autofix -GitHookEofScope global`
   - Checkpoints:
     - the exact sources of the three visible Copilot `super-agent` slash surfaces are isolated
     - one canonical visible Copilot `super-agent` entry remains after cleanup
     - the exact source of duplicated `/super-agent` discovery is isolated
     - the canonical visible `/super-agent` starter remains the shared `.agents/skills` surface while the repo-owned Copilot agent profile uses a secondary alias
     - local vs mirrored runtime ownership is mapped clearly
     - any garbage or duplicate registration paths are identified safely
     - Claude `super-agent` skill, settings, hooks, and runtime sync remain aligned with the same controller contract after cleanup

6. Define cleanup and validation strategy ✓ [2026-03-26 05:17]
   - [2026-03-26 05:17] 6a. Completed docs + validation closeout: canonical sync authority is documented, `infra/github/main.json` is documented as GitHub governance/ruleset infrastructure, clarification/runtime duplication coverage exists in the runtime tests, and `validate-all` plus full `install` are green ✓ [2026-03-26 05:17]
   - Target paths:
     - `README.md`
     - `scripts/README.md`
     - `.vscode/README.md`
     - `.vscode/profiles/README.md`
     - `CHANGELOG.md`
     - `infra/github/main.json`
     - `scripts/tests/runtime/**`
     - `scripts/validation/**`
   - Commands:
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
     - `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
   - Checkpoints:
     - future cleanup has runtime tests covering command-surface duplication
     - future cleanup has runtime tests covering `.vscode` profile/MCP source-of-truth decisions
     - future cleanup has runtime tests covering clarification-question behavior in Super Agent intake surfaces ✓ [2026-03-25 18:30]
     - docs explain the canonical sync authority clearly
     - docs explain `infra/github/main.json` as a repository governance artifact
     - install/runtime sync remains green after cleanup

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instruction-architecture.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/doctor.ps1 -RepoRoot . -RuntimeProfile all -DetailedOutput`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`
- `pwsh -NoLogo -NoProfile -File scripts/runtime/install.ps1 -RuntimeProfile all -CreateSettingsBackup -ApplyMcpConfig -BackupMcpConfig -GitHookEofMode autofix -GitHookEofScope global`

## Risks And Fallbacks

- Risk: concise output becomes too terse and hides failures or operator guidance.
  - Fallback: keep full summaries mandatory and move detail behind verbose/detailed switches only.
- Risk: local RAG/CAG guidance gets interpreted as license to trim needed working context.
  - Fallback: keep retrieval/local-context guidance focused on answer construction, not on shrinking required execution context by default.
- Risk: `.vscode/profiles` and `mcp-vscode-global.json` are helpful local references but not true runtime source-of-truth, so integrating them blindly could add more duplicated surfaces.
  - Fallback: classify them first and only promote the canonical artifacts into the runtime flow.
- Risk: duplicated slash commands come from both repo-local and mirrored runtime surfaces.
  - Fallback: map discovery paths first and remove only one duplicated registration path at a time.
- Risk: adding clarification behavior could regress into noisy questioning on trivial requests.
  - Fallback: gate questions to only ambiguity that materially changes planning, execution, validation, or runtime safety.
- Risk: cleanup accidentally removes a legitimate runtime entry or a still-relevant local session.
  - Fallback: gate cleanup behind targeted runtime tests plus doctor/install validation.

## Recommended Specialists

- Implementation: `ops-devops-platform-engineer`
- Documentation: `docs-release-engineer`
- Review: `review-code-engineer`

## Closeout Expectations

- Workstream completed on 2026-03-26 after runtime/install validation returned clean.
- README/changelog language keeps quality preservation explicit and classifies `infra/github/main.json` correctly as governance infrastructure.
- Any future Rust/Cargo engine work, deeper retrieval-quality tuning, or repository cleanup must reopen as separate targeted workstreams instead of extending this completed plan.