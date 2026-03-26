# Super Agent Runtime Visibility and PowerShell Documentation

Generated: 2026-03-20
Completed: 2026-03-20

## Scope
- Make the repository-owned `Super Agent` visible in the Codex/VS Code skill picker.
- Enforce mandatory descriptions and parameter documentation for PowerShell scripts and functions.
- Validate runtime sync, standards enforcement, and documentation updates.

## Ordered Tasks
1. Diagnose why the picker shows external `superpowers` skills but not the repository-owned `Super Agent`.
2. Fix runtime projection so repository-owned skills are visible in the picker without breaking existing personal skill packs.
3. Measure the current PowerShell function documentation gap.
4. Implement stricter PowerShell standards for function descriptions and parameter documentation.
5. Remediate any newly failing repository scripts required by the stricter standard.
6. Re-run runtime and validation checks, then update docs and changelog.

## Findings
- The repository-owned `super-agent` skill was already present in `~/.codex/skills` and projected into `~/.agents/skills`, but the picker needed a more explicit starter alias to compete with external `superpowers` starter skills in the visible search results.
- A repository-owned `using-super-agent` alias now exists in `.codex/skills/using-super-agent` and is projected into `~/.agents/skills/using-super-agent` during bootstrap so the picker exposes a first-class repository bootstrap entry point.
- PowerShell documentation enforcement now covers all tracked scripts under `scripts/**/*.ps1`, not just a narrow subset of critical folders.
- The PowerShell standards contract now requires script help with per-script parameter coverage and a description comment above every function declaration, with guidance to explain parameter expectations and side effects when behavior is non-obvious.

## Validation Checklist
- `passed` `pwsh -NoLogo -NoProfile -File scripts/runtime/bootstrap.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- `passed` `pwsh -NoLogo -NoProfile -File scripts/validation/validate-instructions.ps1 -RepoRoot .`

## Specialist
- Runtime projection / PowerShell standards

## Closeout
- Update `README.md`, `scripts/README.md`, `.codex/skills/README.md`, and `CHANGELOG.md`
- Return a detailed commit message