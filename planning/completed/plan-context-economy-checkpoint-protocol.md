# Context Economy and Checkpoint Protocol Plan

Generated: 2026-03-23 10:00
LastUpdated: 2026-03-26 05:17

## Status

- State: completed
- Spec: none (scope is concrete enough to proceed without a separate spec)
- Current slice: **tasks 1–7 completed** [2026-03-26 05:17]; workstream closed after commit confirmation

## Objective And Scope

Formalize and persist the "Prompt Mestre" context-economy protocol as a first-class instruction and planning artifact for this repository. The protocol defines how agents must automatically manage context compression, checkpointing, and continuity without being asked — and how the planning system tracks state using the six-block checkpoint format.

**In scope:**
- Add a new instruction file (`context-economy-checkpoint.instructions.md`) that encodes the protocol rules
- Add the checkpoint command vocabulary to `copilot-instructions.md` and `AGENTS.md`
- Extend the active output-economy section in `workflow-optimization.instructions.md` with the three-mode (Execute / Compress / Checkpoint) model
- Add the formal CHECKPOINT structure to `super-agent.instructions.md` under a new `## Context Boundary Monitoring — Checkpoint Format` section, complementary to the existing context boundary section
- Update `planning/README.md` to document the new plan

**Out of scope:**
- Local RAG/CAG index (covered in task 4 of `plan-super-agent-token-quality-and-runtime-sync-cleanup.md`)
- Changes to runtime scripts

## Normalized Request Summary

User-provided "Prompt Mestre" defines a permanent context-economy and checkpoint protocol that agents must follow automatically. Key rules:
1. Treat conversation history as disposable; maintain compact operational memory
2. Auto-compress on: task completion, phase transition, long context, topic shift
3. Maintain six internal state blocks: Estado atual / Em execução / Executado / Decisões / Pendências / Próximo passo
4. Operate in three simultaneous modes: Execution, Continuous Compression, Structured Checkpoint
5. Expose checkpoint only on demand, on phase transition, or for safe continuity
6. Support explicit user commands: "gere checkpoint", "compacte o contexto", "atualize o planejamento", "mostre estado atual", "mostre executados e próximos", "reinicie a partir do resumo"

This protocol aligns with and extends the existing Output Economy Rules already present in `super-agent.instructions.md` and `workflow-optimization.instructions.md`. It adds the checkpoint-trigger model, state-block structure, and command vocabulary that were previously implicit.

## Ordered Tasks

1. [2026-03-23 10:30] Create `.github/instructions/context-economy-checkpoint.instructions.md` ✓
2. [2026-03-23 10:30] Add `## Context Economy and Checkpoint Commands` to `.github/AGENTS.md` ✓
3. [2026-03-23 10:30] Extend `## Token Efficiency` in `workflow-optimization.instructions.md` with three-mode model ✓
4. [2026-03-23 10:30] Add `### In-session context compression` + `### CHECKPOINT format` to `super-agent.instructions.md` ✓
5. [2026-03-23 10:30] Register `context-economy` route in `.github/instruction-routing.catalog.yml` ✓
6. [2026-03-23 10:30] Validation — `validate-instructions.ps1` — passed (0 failures, 0 warnings, 23/23 routing golden tests) ✓
7. [2026-03-26 05:17] Closeout — commit message + CHANGELOG — completed ✓

## Decisions

- [2026-03-23] New standalone instruction file preferred over patching multiple files alone, because the protocol needs its own `applyTo` surface and a single authoritative location
- [2026-03-23] Three-mode model (Execute/Compress/Checkpoint) is the canonical framing from Prompt Mestre
- [2026-03-23] Checkpoint commands are added to AGENTS.md (not copilot-instructions.md) because AGENTS.md is the agent contract surface

## Risks / Pendências

- Routing catalog format needs verification before adding new entry (task 5 may require reading existing catalog first)
- Must not duplicate output-economy rules already in `super-agent.instructions.md`; additions must be additive/complementary

## Próximo Passo

None. Future refinements to context economy should reopen as a new targeted workstream instead of extending this completed plan.