# Runtime Install Profile Activation Plan

Generated: 2026-03-21

## Status

- State: completed
- Owner: Super Agent
- Completed: 2026-03-21
- Result: installer default is now non-intrusive (`none`), runtime activation is profile-driven through the versioned catalog, and README/scripts README document explicit `github`, `codex`, and `all` opt-in flows.

## Objective And Scope

Introduce a versioned runtime profile catalog and make the repository install/onboarding flow honor it so runtime activation is explicit instead of implicit.

## Normalized Request Summary

The user wants a single configuration-file-backed pattern that defines what gets enabled during installation. The supported profiles should be `none` (default), `github`, `codex`, and `all`, and the install command should accept the desired profile explicitly. The documentation must make this behavior obvious.

## Design Decision

- Add a versioned JSON catalog that defines runtime profiles and the repository default.
- Use `none` as the catalog default for `install.ps1`.
- Keep `bootstrap.ps1`, `doctor.ps1`, `healthcheck.ps1`, and `self-heal.ps1` backward-compatible by defaulting their profile parameter to `all` when invoked directly.
- Treat `github` as the GitHub/Copilot runtime surface only.
- Treat `codex` as the Codex/.agents/shared-scripts/orchestration runtime surface only.
- Treat editor-global settings/snippets, local git hooks, and global git aliases as opt-in extras that are only enabled by profile `all`.

## Ordered Tasks

1. Create the versioned runtime profile catalog and shared loader helper
   - Target paths:
     - `.github/governance/runtime-install-profiles.json`
     - `scripts/common/runtime-install-profiles.ps1`
   - Checkpoints:
     - supported profiles are explicit
     - default profile is `none`
     - scripts can resolve profile definitions consistently

2. Apply the profile contract to install/bootstrap/runtime checks
   - Target paths:
     - `scripts/runtime/install.ps1`
     - `scripts/runtime/bootstrap.ps1`
     - `scripts/runtime/doctor.ps1`
     - `scripts/runtime/healthcheck.ps1`
     - `scripts/runtime/self-heal.ps1`
   - Checkpoints:
     - install default preview is non-intrusive
     - install can opt into `github`, `codex`, or `all`
     - bootstrap and doctor only touch/check enabled runtime surfaces for the selected profile

3. Update runtime tests and docs
   - Target paths:
     - `scripts/tests/runtime/install-runtime.tests.ps1`
     - `scripts/tests/runtime/runtime-scripts.tests.ps1`
     - `README.md`
     - `scripts/README.md`
     - `CHANGELOG.md`
   - Checkpoints:
     - tests cover `none`, `github`, `codex`, and `all`
     - docs clearly explain the default and example commands

## Validation Checklist

- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`

## Risks And Fallbacks

- Risk: `none` default may surprise users expecting the old install behavior.
  - Fallback: document the explicit `-RuntimeProfile all` path prominently in README examples.
- Risk: partial profiles can cause doctor/healthcheck false positives if they still audit disabled surfaces.
  - Fallback: pass the selected profile through the runtime diagnostics scripts and scope mappings by profile.
- Risk: global alias setup depends on Codex shared scripts.
  - Fallback: only enable global aliases under `all`, where the Codex runtime surface is guaranteed to exist.

## Closeout Expectations

- Move this plan to `planning/completed/` after implementation and validation.
- Return a commit message that explains the new runtime profile contract and default behavior.

## Validation Results

- Passed: `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/install-runtime.tests.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/tests/runtime/runtime-scripts.tests.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-powershell-standards.ps1 -RepoRoot . -SkipScriptAnalyzer`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-readme-standards.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/governance/update-shared-script-checksums-manifest.ps1 -RepoRoot .`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-runtime-script-tests.ps1 -RepoRoot . -WarningOnly:$false`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-shared-script-checksums.ps1 -RepoRoot . -WarningOnly:$false`
- Passed: `pwsh -NoLogo -NoProfile -File scripts/validation/validate-all.ps1 -RepoRoot . -ValidationProfile dev`