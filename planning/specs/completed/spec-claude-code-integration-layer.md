# Claude Code Integration Layer

Generated: 2026-03-23

## Objective

Create a Claude Code native integration layer for this repository that activates the existing workspace-adapter governance model without duplicating `.github/` content. The layer must map Claude Code's native primitives (CLAUDE.md, Agent tool types, Skill tool, memory system, settings.json hooks) to the existing Super Agent lifecycle and orchestration pipeline defined in `.github/`.

## Normalized Request Summary

The user wants Claude Code to participate in the same structured workflow that Copilot and Codex use — Super Agent lifecycle, planning surfaces, specialist routing, quality gates — but adapted to Claude Code's own native primitives. No content duplication from `.github/`. No new governance. Only a bridge layer that activates what already exists.

## Design Summary

The integration layer has four components:

1. **CLAUDE.md (root)**: Minimal workspace-adapter declaration. Loads `.github/AGENTS.md` and `.github/copilot-instructions.md` as authoritative. Defines language policy, EOF policy, memory policy, and Claude-native agent type mapping. Does not duplicate instruction content.

2. **`.claude/skills/`**: Skill adapter files (markdown with frontmatter) following the same pattern as `.codex/skills/`. Maps each pipeline role to a Claude agent type and points to existing `.github/instructions/` files. Skills: `super-agent`, `brainstorm-spec-architect`, `plan-active-work-planner`, `context-token-optimizer`, `dev-software-engineer`, `review-code-engineer`.

3. **`.claude/settings.json`**: Project-level hooks. Stop hook surfaces closeout reminder (commit message + planning update). PostToolUse hook for Bash/git commit surfaces post-commit sync reminder.

4. **Memory policy**: Documented in CLAUDE.md. Defines what the Claude memory system should persist about this workspace across sessions (active plan/spec paths, workspace mode, user feedback).

## Key Decisions

1. CLAUDE.md is the only root-level addition — no duplication of `.github/` files.
2. `.claude/skills/` follows `.codex/skills/` structure — consistent authoring pattern across runtimes.
3. Claude Agent tool type mapping: `Plan` → brainstormer + planner, `Explore` → router, `general-purpose` → specialist/tester/reviewer.
4. Settings.json hooks are informational (echo/print) not blocking — they remind, they do not gate.
5. Memory policy focuses on project state (active plan/spec) and feedback, not code patterns (those are in git).
6. No `.claude/orchestration/` — Claude uses the Agent tool natively; no pipeline JSON needed.

## Alternatives Considered

- **Full instruction copy into CLAUDE.md**: Rejected — causes duplication drift and violates the no-repeat constraint.
- **Single monolithic CLAUDE.md with all skill content**: Rejected — too large, harder to maintain, not aligned with Codex skill pattern.
- **Blocking hooks (approval gates)**: Rejected — hooks in Claude Code settings.json are better used as informational reminders; approval gates are handled by the Super Agent lifecycle itself.

## Acceptance Criteria

1. `CLAUDE.md` exists at repo root, activates workspace-adapter mode, references `.github/AGENTS.md` and `.github/copilot-instructions.md` as authoritative, defines agent type mapping and memory policy.
2. `.claude/skills/` contains 6 skill files with correct frontmatter and pipeline role mapping.
3. `.claude/settings.json` exists with Stop and PostToolUse hooks.
4. No content from `.github/instructions/` is duplicated in any new file.
5. EOF policy preserved: no trailing newlines.

## Planning Readiness

Ready. No unresolved design decisions. Proceed to planning.

## Recommended Specialist Focus

- `docs-release-engineer` — CLAUDE.md and skill file authoring
- `ops-devops-platform-engineer` — settings.json hooks