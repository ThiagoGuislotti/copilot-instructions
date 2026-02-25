# Shared Skills

> Repository-managed skills for Codex execution, routing, testing, review, DevOps, and docs workflows.

---

## Introduction

This folder stores versioned Codex skills aligned with `.github/instructions`. Skills are synced to local runtime through bootstrap.

---

## Features

- ✅ Skills versioned in source control
- ✅ Runtime sync through root bootstrap
- ✅ Reusable workflows mapped to repository instruction packs

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

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1
```

---

## Quick Start

```powershell
pwsh -File .\scripts\runtime\bootstrap.ps1
Get-ChildItem "$env:USERPROFILE\.codex\skills"
```

---

## Usage Examples

### Example 1: Software Implementation

Use skill: `software-engineer`

### Example 2: Testing and Coverage

Use skill: `test-engineer`

### Example 3: Runtime Sync

Use skill: `codex-runtime-sync`

### Example 4: Domain Specialists

Use skills: `dotnet-backend-engineer`, `frontend-vue-quasar-engineer`, `rust-engineer`, `task-planner`

---

## API Reference

### Available Skills

- `repo-context-router`
- `codex-runtime-sync`
- `software-engineer`
- `test-engineer`
- `code-review-engineer`
- `devops-platform-engineer`
- `docs-release-engineer`
- `dotnet-backend-engineer`
- `frontend-vue-quasar-engineer`
- `rust-engineer`
- `task-planner`

### Layout

- `<skill-name>/SKILL.md`: skill contract and execution behavior.

---

## Build and Tests

```powershell
# Verify skill definitions
Get-ChildItem .\.codex\skills -Recurse -Filter SKILL.md

# Sync to local runtime
pwsh -File .\scripts\runtime\bootstrap.ps1
```

---

## Contributing

- Keep skill names stable and descriptive.
- Keep `SKILL.md` concise and reference existing instruction files.
- Update this README when adding or removing skills.

---

## Dependencies

- Runtime: PowerShell 7+ for bootstrap sync.
- Codex runtime in `~/.codex`.

---

## References

- `.codex/README.md`
- `.codex/skills/repo-context-router/SKILL.md`
- `.codex/skills/codex-runtime-sync/SKILL.md`
- `.github/instruction-routing.catalog.yml`
- `scripts/runtime/bootstrap.ps1`