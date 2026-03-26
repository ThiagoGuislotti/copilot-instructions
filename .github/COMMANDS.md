# Context Economy Commands

Canonical commands are English. Portuguese aliases are accepted as convenience shortcuts in any Copilot, Codex, or Claude Code session.

## Command Reference

| English (canonical) | PT-BR alias | Behavior |
|---|---|---|
| `checkpoint` | `gere checkpoint` | Output the full CHECKPOINT block |
| `compress context` | `compacte o contexto` | Apply compression immediately; confirm silently |
| `update plan` | `atualize o planejamento` | Update the active plan artifact (`planning/active/`) with current state |
| `show status` | `mostre estado atual` | Output Current state block only |
| `show progress` | `mostre executados e próximos` | Output Completed + Next step blocks |
| `resume from summary` | `reinicie a partir do resumo` | Drop raw history; resume from last CHECKPOINT |

## Usage Notes
- English commands are the repository standard; use them in code, docs, and instruction files.
- PT-BR aliases work identically — they are convenience shortcuts for chat sessions, not the canonical form.
- See `.github/instructions/context-economy-checkpoint.instructions.md` for the full protocol.