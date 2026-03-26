---
name: dev-frontend-vue-quasar-engineer
description: Implement and refactor frontend features using Vue and Quasar with repository architecture, theming, UX, and performance standards. Use when tasks involve components, composables, Pinia, routing, i18n/UI behavior, responsive layouts, or frontend clean architecture changes.
---

# Frontend Vue Quasar Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Frontend instruction pack

- `.github/instructions/frontend.instructions.md`
- `.github/instructions/vue-quasar.instructions.md`
- `.github/instructions/vue-quasar-architecture.instructions.md`
- `.github/instructions/ui-ux.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent within the Super Agent pipeline.

## Execution workflow

1. Preserve clean architecture boundaries and feature isolation.
2. Reuse shared components/composables before creating new abstractions.
3. Enforce responsive and accessibility constraints.
4. Keep UI copy/keys and i18n behavior aligned with repo policy.
5. Run targeted validation before claiming completion.

## Prompt accelerators

- `.github/prompts/create-vue-component.prompt.md`

## Validation examples

```powershell
pnpm build
pnpm test
```