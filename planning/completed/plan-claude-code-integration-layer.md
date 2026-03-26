# Claude Code Integration Layer Plan

Generated: 2026-03-23

## Status

- State: completed
- Spec: `planning/specs/active/spec-claude-code-integration-layer.md`
- Specialists: `docs-release-engineer`, `ops-devops-platform-engineer`

## Objective

Create Claude Code native bridge layer (CLAUDE.md + .claude/) that activates the existing workspace-adapter governance model without duplicating `.github/` content.

## Ordered Tasks

### Phase 1: Core adapter (completed 2026-03-23)
1. `CLAUDE.md` ✓
2. `.claude/skills/super-agent/SKILL.md` ✓
3. `.claude/skills/brainstorm-spec-architect/SKILL.md` ✓
4. `.claude/skills/plan-active-work-planner/SKILL.md` ✓
5. `.claude/skills/context-token-optimizer/SKILL.md` ✓
6. `.claude/skills/dev-software-engineer/SKILL.md` ✓
7. `.claude/skills/review-code-engineer/SKILL.md` ✓
8. `.claude/settings.json` ✓

### Phase 2: Install system + README + domain coverage

9. `.github/governance/runtime-location-catalog.json` — add `claudeRuntimeRoot`
10. `.github/governance/runtime-install-profiles.json` — add `claude` profile, add `claude` flag to all profiles
11. `scripts/common/runtime-install-profiles.ps1` — add `EnableClaudeRuntime`
12. `scripts/common/runtime-paths.ps1` — add `Resolve-ClaudeRuntimePath` + update `Get-EffectiveRuntimeLocations`
13. `scripts/common/runtime-execution-context.ps1` — add `RequestedTargetClaudePath` + `ClaudeSkillsRoot` to Targets
14. `scripts/runtime/install.ps1` — add `TargetClaudePath` param + Claude install step
15. `scripts/runtime/sync-claude-skills.ps1` — new minimal sync script
16. `.claude/skills/dev-software-engineer/SKILL.md` — expand to all 43 domain instructions
17. `README.md` — add Claude Code support (profiles table, integration matrix, install examples, layers)

## Validation

- All new files exist with correct frontmatter
- No `.github/` content duplicated
- EOF: no trailing newlines on any file
- Install step runs cleanly with `-RuntimeProfile claude`
- README accurately describes Claude Code support

## Checkpoints

- Spec is planning-ready: yes
- Phase 1 files created: ✓
- Phase 2 completed: 2026-03-23
- Planning artifact updated at completion: 2026-03-23 ✓