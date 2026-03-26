# Super Agent Token Quality And Runtime Sync Cleanup

Generated: 2026-03-22

## Objective

Protect output quality while pursuing token savings through safer output-side controls, investigate runtime-sync duplication or garbage under the mirrored `.github` surface that may be causing duplicated Copilot slash commands such as `/super-agent`, and immediately stop local Codex session/runtime blowups plus VS Code Copilot workspace bloat that are consuming excessive disk and likely inflating token use.

## Normalized Request Summary

The user does not want token economy to reduce quality. They also suspect the runtime synchronization flow is leaving garbage or duplicated surfaces under `.github`, based on duplicated command entries visible in VS Code. The risky input/context compaction should stay reverted, and any future optimization should focus on safer output-side economy plus better local RAG/CAG usage. In parallel, local Codex sessions have grown into multi-gigabyte JSONL files dominated by compacted history, encrypted reasoning, and repeated worker/subagent context, while VS Code `workspaceStorage` now contains multi-gigabyte Copilot workspace indexes and huge chat session payloads. The runtime now needs safer defaults and stronger cleanup to prevent both from recurring.

## Design Summary

This follow-up must treat token economy as a quality-preserving optimization, not a blind context-cutting exercise. The reverted input/context compaction should stay reverted unless later evidence proves it harmless. The safer path is output-side economy: shorter default responses, less repeated status text, less duplicated logs, and stronger use of local RAG/CAG so retrieval quality stays high without over-explaining the same state repeatedly. That should be backed by a local incremental index/cache so the system can reuse repository knowledge without rereading everything on each turn.

The urgent runtime slice is separate and mechanical: it does not trim execution context. Instead, it applies safer local Codex defaults that directly reduce runaway session amplification:
- keep the default reasoning effort at a safer repository-owned level
- keep local multi-agent mode enabled, but rely on the repository-owned Super Agent guidance to call subagents strategically instead of for trivial work
- enforce session cleanup primarily by stale age (`LastWriteTime`) so active conversations keep their context by default
- leave oversized-file thresholds and total session-storage budgets available only as explicit override paths for emergency cleanup
- wire these controls into install and runtime hooks so users do not need to remember manual cleanup

The same urgent slice must also harden the VS Code global user runtime:
- lower the managed global chat request budget from repository-owned runaway values to a safer cap
- stop restoring the last chat panel session by default
- stop keeping empty-state chat history by default
- prune stale `workspaceStorage` directories, old Copilot session/transcript files, old `History` files, old `settings.json.*.bak` and `mcp.json.*.bak` files, and oversized `GitHub.copilot-chat/local-index*.db` files
- throttle hook-driven VS Code cleanup so post-commit does not regress into a slow path again

In parallel, the runtime-sync flow still needs a focused audit to identify whether mirrored `.github` content, duplicate adapters, or duplicate agent-surface registration is causing repeated slash-command entries in VS Code.

The instruction and prompt layer can safely enforce the first slice immediately: concise default responses, delta-focused stage summaries, and an explicit prohibition on trimming required execution context by default purely for token savings.

The next safe continuity slice can also ship immediately: the VS Code `SessionStart` and `SubagentStart` bootstrap hooks should inject a short continuity summary derived from the current active plan/spec artifacts. That gives the controller and workers a bounded restart point after context compaction or a new session, without relying on replaying oversized chat history.

The same bootstrap surface can safely own periodic housekeeping as long as it stays bounded: `SessionStart` and `SubagentStart` may dispatch a throttled workspace-local maintenance pass that first exports a concise planning handoff and then cleans only persisted Codex and VS Code runtime state. This must never attempt to clear the live active context window or reset the runtime UI token meter.

The resumed planning slice also needs to absorb four concrete follow-ups discovered after the first hygiene pass:
- `.vscode/profiles/` and `.vscode/mcp-vscode-global.json` now exist as local helper surfaces, but they are not yet clearly classified as runtime source-of-truth, generated artifacts, or removable references
- Copilot is exposing multiple visible `super-agent` entries when typing `/`, which means the duplication audit now needs to isolate the exact registration surfaces and converge them to one canonical visible controller entry
- Claude Code already exposes a repository-owned `super-agent` skill and hook set, so the parity audit must verify it stays aligned with Copilot/Codex and does not keep stale controller behavior
- the Super Agent controller currently routes and plans well, but it still lacks an explicit repository-owned contract for asking concise clarifying questions when ambiguity materially changes plan, architecture, runtime behavior, or validation
- `.codex/mcp/servers.manifest.json` is still only a reduced MCP subset and its current renderer drops `disabled`, `gallery`, `version`, `env`, and richer auth/input fields, so the repository now needs a canonical MCP runtime catalog with derived per-runtime renderers instead of treating any current runtime file as complete
- `infra/github/main.json` is present as a GitHub ruleset artifact and should be documented as governance infrastructure rather than being confused with runtime or MCP configuration

The first resumed cleanup slice is now materially implemented:
- `.vscode/profiles/` is promoted to a versioned reusable profile-baseline surface with explicit local selection support, while `.vscode/mcp-vscode-global.json` remains a local helper/reference artifact for now
- the runtime sync contract no longer projects `.github/skills/super-agent` into any Copilot-visible runtime skill root; instead, bootstrap removes legacy `super-agent` and `using-super-agent` folders from both `%USERPROFILE%\\.github\\skills` and `%USERPROFILE%\\.copilot\\skills` so the shared `%USERPROFILE%\\.agents\\skills\\super-agent` surface stays canonical for slash discovery
- the repo-owned `.github/agents/super-agent.agent.md` profile remains available for Copilot, but with a secondary workspace-controller alias instead of a second visible `/super-agent`
- the repository-owned `.github/skills/super-agent/SKILL.md` surface is removed to avoid keeping a second competing native Copilot-visible starter under version control
- the canonical MCP runtime catalog now lives at `.github/governance/mcp-runtime.catalog.json`, and both `.vscode/mcp.tamplate.jsonc` and `.codex/mcp/servers.manifest.json` are treated as generated projections
- the initial local RAG/CAG slice now exists as a deterministic incremental index under `.temp/context-index/`, maintained by `scripts/runtime/update-local-context-index.ps1`, queried by `scripts/runtime/query-local-context-index.ps1`, and refreshed by `invoke-super-agent-housekeeping.ps1`
- the Super Agent intake/controller contract now includes explicit clarification gating with `clarificationRequired`, `canProceedSafely`, `clarificationReason`, and `clarificationQuestions`

## External Reference Baseline

Use `mksglu/context-mode` as the reference baseline for the future local RAG/CAG slice. The repository documents two core ideas that are directly relevant here:
- context reduction should happen at the source/tool boundary instead of after raw payloads already polluted the model context
- session continuity should be persisted locally and retrieved selectively on resume/compaction instead of replaying the whole transcript

Reference:
- `https://github.com/mksglu/context-mode`

The future local RAG/CAG design in this repository should evaluate these ideas first:
1. local-first persistence only, no cloud dependency for continuity state
2. searchable continuity state for tasks, edits, decisions, and errors
3. retrieval of only relevant continuity fragments after compaction or restart
4. explicit continuity recovery before the agent rereads large raw artifacts

The repository should not copy `context-mode` blindly. Its plugin/hook architecture is platform-specific. We only want to adopt the durable design patterns that fit the repository-owned Super Agent runtime, planning-first continuity model, and local runtime sync contracts.

## Key Decisions

1. Quality remains the primary objective; token economy is acceptable only when it preserves or improves task quality.
2. Input/context compaction is rolled back for now and must not return by default without explicit evidence.
3. The next safe optimization target is output economy: shorter default responses, less duplicated wording, and less repeated orchestration/log narration.
4. Local RAG/CAG usage should be preferred over larger repeated textual restatement when the answer can rely on retrieved local context safely.
5. The local retrieval layer should eventually use an incremental index/cache with add/update/delete invalidation instead of full rereads.
6. The duplicated `/super-agent` entries are treated as a runtime-sync hygiene defect until proven otherwise.
7. Sync cleanup should prefer one canonical runtime authority per surface and should avoid duplicated adapter/agent registration between repo-local and mirrored runtime folders.
8. Local Codex runtime defaults must bias toward predictable cost and disk growth without disabling strategic multi-agent behavior.
9. Runtime cleanup must protect active sessions by default, with stale-session retention as the normal path and oversized-file or storage-budget pruning reserved for explicit overrides.
10. VS Code user-runtime cleanup must protect recent active work by using retention windows plus grace windows and by throttling repeated scans.
11. Session bootstrap continuity should come from the active plan/spec artifacts so context compaction can recover from versioned repository state instead of large chat transcripts.
12. `.vscode/profiles/` is a versioned reusable baseline surface with explicit local selection, while `.vscode/mcp-vscode-global.json` must still be classified before it influences runtime sync, MCP enablement, or token-economy behavior.
13. Copilot should expose one canonical visible `super-agent` controller entry after runtime-sync cleanup; duplicate visible entries are a defect.
14. Claude Code must keep the same Super Agent lifecycle and clarification behavior as Copilot/Codex, with portable hook/settings configuration.
15. Super Agent intake must ask concise clarification questions only when ambiguity materially changes plan, execution, runtime safety, or validation.
16. The future local RAG/CAG implementation must explicitly document which `context-mode` patterns were adopted, adapted, or rejected.
17. MCP configuration must use one canonical rich runtime catalog with per-runtime renderers; `.vscode/mcp.tamplate.jsonc` and the Codex manifest are both generated outputs from that catalog.
18. Repository documentation must classify `infra/github/main.json` as GitHub governance/ruleset infrastructure.

## Alternatives Considered

1. Keep tightening context caps immediately.
   - Rejected because the user explicitly does not want quality risk.
2. Ignore the duplicate command entries as a VS Code quirk.
   - Rejected because the screenshot indicates a plausible repo-owned sync/config duplication that should be audited.
3. Optimize only by switching to cheaper models immediately.
   - Rejected because that still requires quality proof and does not address duplicated output or orchestration verbosity.
4. Keep `multi_agent = true` as the global local default.
   - Accepted for the local runtime because the user wants subagents available; the remaining control point is strategic use, not blanket disablement.

## Assumptions And Constraints

- The risky input/context token-economy implementation is rolled back and should remain rolled back unless explicitly revisited.
- A future local index/cache should be deterministic, incremental, and delete-safe.
- The duplicate slash-command behavior is likely related to mirrored `.github` runtime sync, local adapter duplication, or overlapping agent/skill registration.
- `.vscode/profiles/README.md` and `setup-profiles.ps1` already reference `profile-vision-engine.json`, but that file is absent from the folder, so the profile surface currently contains drift that must be resolved before broader adoption.
- The follow-up should remain repo-owned and deterministic.
- The output-economy and local-index portions remain deferred until the user decides to resume them.
- The Codex runtime blowup controls are safe to implement immediately because they do not trim required execution context.
- The user has now resumed the planning of the local RAG/CAG slice and expects the deferred items above to be sequenced for execution.

## Risks

- Over-aggressive input/context optimization can reduce task quality or omit needed domain context.
- Output-side economy can still regress operator clarity if summaries become too short or hide failures.
- A stale local index/cache can return outdated context unless invalidation on add/update/delete is reliable.
- Promoting `.vscode` helper surfaces without clarifying ownership could create more duplicate MCP or controller registrations.
- Promoting `.codex/mcp/servers.manifest.json` to source-of-truth prematurely would regress VS Code MCP fidelity because the current renderer cannot preserve the full contract.
- Runtime sync may be projecting duplicate command/agent surfaces into VS Code and confusing discovery.
- Clarification-question behavior can become noisy if it is not gated to material ambiguity only.
- If the duplicated command source is not isolated precisely, cleanup could remove a valid runtime surface accidentally.
- If runtime cleanup thresholds are too aggressive, they could remove older large sessions the user still wanted to inspect.

## Acceptance Criteria

1. A follow-up plan exists that explicitly treats quality preservation as a hard requirement for any future token-economy change.
2. The future implementation focuses first on output-side economy: shorter defaults, less duplication, and better local RAG/CAG usage.
3. The future implementation defines a local incremental index/cache with add/update/delete invalidation for safer retrieval reuse.
4. The future runtime-sync audit isolates the exact source of duplicated slash commands or `.github` garbage.
5. The future cleanup defines one canonical registration path per mirrored surface and removes duplicated registration safely.
6. README and runtime docs are updated when that cleanup eventually lands.
7. Codex runtime install/onboarding applies safer local reasoning defaults while keeping multi-agent available by default and without trimming required execution context.
8. Codex session cleanup defaults now enforce stale-session retention after 30 days without update, with documented environment overrides for optional oversized-file and storage-budget emergency cleanup.
9. Managed global VS Code settings stop favoring runaway Copilot chat history/restore/request budgets.
10. VS Code user-runtime cleanup defaults now enforce age plus oversized-file caps with documented environment overrides and a throttled hook execution window.
11. Session bootstrap hooks inject a short continuity summary that references the latest active plan/spec artifact and tells the agent to resume from those artifacts first after context compaction.
12. Session bootstrap hooks can trigger safe periodic housekeeping no more than once per workspace interval, exporting planning continuity first and then cleaning only persisted runtime state.
13. The planning artifacts explicitly cover classification of `.vscode/profiles/` and `.vscode/mcp-vscode-global.json` before they are allowed to influence runtime sync or MCP enablement.
14. The planning artifacts explicitly cover isolating and removing duplicate visible `super-agent` entries in Copilot slash discovery.
15. The planning artifacts explicitly cover Claude Code Super Agent parity review.
16. The planning artifacts explicitly cover adding concise clarification-question behavior to the Super Agent controller surfaces.
17. The planning artifacts explicitly cover introducing one canonical MCP runtime catalog plus derived VS Code/Codex/Claude renderers without losing VS Code-only metadata.
18. The planning artifacts explicitly cover documenting `infra/github/main.json` as governance/ruleset infrastructure.

## Planning Readiness Statement

Planning is ready. The workstream is clear enough to sequence, and the deferred local RAG/CAG + controller-parity slice is now resumed for execution planning.

## Recommended Specialist Focus

- Primary: `ops-devops-platform-engineer`
- Secondary: `docs-release-engineer`
- Review focus: `review-code-engineer`