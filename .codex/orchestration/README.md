# Multi-Agent Orchestration

> Versioned contracts and baseline artifacts for deterministic multi-agent execution.

---

## Introduction

This folder defines the contract layer for planner, executor, tester, and reviewer collaboration. The objective is to keep multi-agent behavior auditable, reproducible, and validation-driven across local runtime and CI workflows.

---

## Features

- ✅ Versioned agent contracts with explicit roles, tool scopes, and budgets
- ✅ Deterministic pipeline orchestration with stage handoffs and completion criteria
- ✅ Standard run artifacts for traceability and post-run analysis
- ✅ Golden eval fixtures for regression checks on orchestration behavior
- ✅ Schema-based validation integrated with repository quality gates

---

## Contents

- [Introduction](#introduction)
- [Features](#features)
- [Contents](#contents)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Build and Tests](#build-and-tests)
- [Contributing](#contributing)
- [Dependencies](#dependencies)
- [References](#references)

---

## Installation

No additional package installation is required. Use PowerShell 7+ and run commands from repository root.

---

## Quick Start

```powershell
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1
```

---

## Usage Examples

### Example 1: Validate Orchestration Contracts

```powershell
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1
```

### Example 2: Run Full Healthcheck Including Orchestration

```powershell
pwsh -File .\scripts\runtime\healthcheck.ps1 -StrictExtras
```

---

## API Reference

### Contract Files

- `agents.manifest.json`: canonical agent contract (roles, skills, tools, allowed paths, budgets, fallback links).
- `pipelines/default.pipeline.json`: baseline execution graph with stage order, handoffs, and completion criteria.
- `templates/handoff.template.json`: canonical stage handoff artifact shape.
- `templates/run-artifact.template.json`: canonical run summary artifact shape.
- `evals/golden-tests.json`: deterministic orchestration regression fixtures.

### Validation Scope

`scripts/validation/validate-agent-orchestration.ps1` validates:
- JSON schema contracts under `.github/schemas/`
- Cross-file integrity (agent IDs, skills, pipeline stages, handoffs, artifacts)
- Template and eval fixture consistency

---

## Build and Tests

```powershell
# validate orchestration contracts only
pwsh -File .\scripts\validation\validate-agent-orchestration.ps1

# run end-to-end checks including orchestration, policy, and release governance
pwsh -File .\scripts\runtime\healthcheck.ps1 -StrictExtras
```

---

## Contributing

- Keep contract changes additive and versioned.
- Prefer explicit allowlists (`allowedPaths`) over broad wildcards.
- Keep fallback chains deterministic and short.
- Update related schema and validation logic in the same change when required.

---

## Dependencies

- Runtime: PowerShell 7+
- Repository validators: scripts under `scripts/validation/` and `scripts/runtime/`

---

## References

- `.codex/README.md`
- `.github/schemas/agent.contract.schema.json`
- `.github/schemas/agent.pipeline.schema.json`
- `.github/schemas/agent.handoff.schema.json`
- `.github/schemas/agent.run-artifact.schema.json`
- `.github/schemas/agent.evals.schema.json`
- `scripts/validation/validate-agent-orchestration.ps1`