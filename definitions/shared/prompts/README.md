# Shared Prompt Assets

`definitions/shared/prompts/` contains reusable prompt libraries that are not
owned by one provider runtime.

## Coverage

- `poml/` -> projected into `.github/prompts/poml/` as the shared POML prompt
  library consumed by GitHub/Copilot prompt workflows and future tooling

## Rules

- Keep reusable prompt libraries here when they are not specific to one
  provider/runtime.
- Provider trees should only own provider-specific prompt entrypoints.