# Runtime Skill Deduplication

Generated: 2026-03-20
Completed: 2026-03-20

## Scope
- Remove duplicate picker-visible repository skills caused by syncing the same repo-owned skills into both `~/.codex/skills` and `~/.agents/skills`.
- Keep repository-owned skills visible once in VS Code while preserving unmanaged user and system skills.
- Update runtime sync, doctor, tests, docs, and planning records.

## Ordered Tasks
1. Identify where runtime sync and doctor currently treat repo-owned skills as dual-target assets.
2. Change runtime projection so repository-managed skills are canonical in `~/.agents/skills` and are no longer mirrored into `~/.codex/skills`.
3. Add cleanup for previously projected duplicate repo-owned skills from `~/.codex/skills` without deleting unmanaged/system skill folders.
4. Update tests and docs to reflect the single visible-skill target.
5. Re-run runtime sync and validation, confirm duplicates are removed, and close out the plan.

## Findings
- VS Code/Codex picker duplication came from the same repo-managed skills being present under both `%USERPROFILE%\\.codex\\skills` and `%USERPROFILE%\\.agents\\skills`.
- The canonical visible/runtime target for repo-managed skills is now `%USERPROFILE%\\.agents\\skills`.
- `%USERPROFILE%\\.codex\\skills` is now reserved for unmanaged/system content such as `.system`, and bootstrap removes stale repo-managed duplicates from that path.
- Runtime doctor now compares repo-managed skills against `%USERPROFILE%\\.agents\\skills` only and separately checks that duplicate repo-managed folders are absent from `%USERPROFILE%\\.codex\\skills`.

## Validation Checklist
- `passed` `pwsh -NoLogo -NoProfile -File scripts/runtime/bootstrap.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/runtime/doctor.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-planning-structure.ps1 -RepoRoot . -WarningOnly:$false`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Specialist
- Runtime sync / skill discovery

## Closeout
- Update `README.md`, `scripts/README.md`, `.codex/skills/README.md`, and `CHANGELOG.md`
- Return a detailed commit message