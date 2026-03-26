---
name: frontend-vue-quasar-engineer
description: Implement and refactor frontend features using Vue and Quasar with repository architecture, theming, UX, and performance standards. Use when tasks involve components, composables, Pinia, routing, i18n/UI behavior, responsive layouts, or frontend clean architecture changes.
---

# Frontend Vue Quasar Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Keep only mandatory files plus frontend pack.

## Frontend instruction pack

- `.github/instructions/frontend.instructions.md`
- `.github/instructions/vue-quasar.instructions.md`
- `.github/instructions/vue-quasar-architecture.instructions.md`
- `.github/instructions/ui-ux.instructions.md`

## Prompt and chatmode accelerators

- `.github/prompts/create-vue-component.prompt.md`
- `.github/chatmodes/vue-quasar-expert.chatmode.md`

## Execution workflow

1. Preserve clean architecture boundaries and feature isolation.
2. Reuse shared components/composables before creating new abstractions.
3. Enforce responsive and accessibility constraints.
4. Keep UI copy/keys and i18n behavior aligned with repo policy.
5. Run dependency vulnerability audit before frontend build and validate behavior on desktop/mobile scenarios.

## Validation examples

```powershell
$SecurityScriptsRoot = Join-Path $env:USERPROFILE '.codex\shared-scripts\security'
pwsh -File (Join-Path $SecurityScriptsRoot 'Invoke-FrontendPackageVulnerabilityAudit.ps1') -RepoRoot $PWD -ProjectPath src/WebApp -FailOnSeverities Critical,High
pnpm build
pnpm test
```