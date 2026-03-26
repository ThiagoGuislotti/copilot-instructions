# GitHub Change Validation Checklist

**Changed file**: `.github/[FILE_PATH]`
**Date**: `YYYY-MM-DD`
**Change type**: `[Added | Changed | Fixed | Removed]`

## Scope Review
- [ ] Change scope and impacted files are identified
- [ ] Related instructions, prompts, templates, routes, or schemas were reviewed
- [ ] Backward-compatibility impact was assessed

## Documentation and Mapping
- [ ] `.github/copilot-instructions.md` was updated when global guidance changed
- [ ] `README.md` was updated when usage, onboarding, or repository structure changed
- [ ] `CHANGELOG.md` was updated when the change should remain in versioned history
- [ ] Cross-references and links were verified

## Validation
- [ ] `pwsh -File scripts/validation/validate-instruction-metadata.ps1 -RepoRoot .`
- [ ] `pwsh -File scripts/validation/validate-instructions.ps1 -RepoRoot .`
- [ ] Additional targeted validation was executed when the change affected scripts, templates, routing, or governance artifacts
- [ ] EOF and trailing-whitespace rules were verified

## Change Notes
- Context: [CONTEXT]
- Risk: [RISK_OR_NONE]
- Follow-up: [FOLLOW_UP_OR_NONE]