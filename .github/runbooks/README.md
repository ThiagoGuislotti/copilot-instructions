# Runbooks

> Operational procedures for validation, runtime drift, and release rollback flows.

---

## Introduction

This folder centralizes operational runbooks used by maintainers and agent operators.
Runbooks are short, deterministic, and designed for local execution first.

---

## Features

- ✅ Validation incident response with warning-only and enforcing modes
- ✅ Runtime drift diagnosis and repair workflow
- ✅ Release rollback procedure with governance checkpoints

---

## Contents

- [Introduction](#introduction)
- [Features](#features)
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

No installation is required. Runbooks are markdown procedures.

---

## Quick Start

1. Start with the runbook matching the incident class.
2. Execute commands from repository root.
3. Record outcomes in `.temp/audit/`.

---

## Usage Examples

- Validation incidents: `validation-failures.runbook.md`
- Runtime sync/drift: `runtime-drift.runbook.md`
- Release rollback: `release-rollback.runbook.md`

---

## API Reference

- `validation-failures.runbook.md`: triage and recover from failing checks.
- `runtime-drift.runbook.md`: detect, inspect, and repair runtime drift.
- `release-rollback.runbook.md`: controlled rollback for bad changes.

---

## Build and Tests

Runbooks are validated indirectly by:

```powershell
pwsh -File .\scripts\validation\validate-instructions.ps1
pwsh -File .\scripts\validation\validate-all.ps1
```

---

## Contributing

- Keep procedures deterministic and reproducible.
- Prefer explicit commands over prose-only instructions.
- Keep warning-only defaults unless governance policy changes.

---

## Dependencies

- PowerShell 7+
- Git CLI

---

## References

- `README.md`
- `scripts/README.md`
- `.github/governance/release-governance.md`