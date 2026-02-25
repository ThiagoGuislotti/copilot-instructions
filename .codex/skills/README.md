# Shared Skills

> Repository-managed skills for Codex routing and runtime sync workflows.

---

## Introduction

This folder stores custom skills used by this repository. Skills are versioned here and synced to local runtime via bootstrap.

---

## Features

- ✅ Skill definitions versioned in source control
- ✅ Predictable installation through root bootstrap
- ✅ Reusable workflows for context routing and runtime sync

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

Sync these skills into local runtime:

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

### Example 1: Route Context Before Task Execution

Use skill: `repo-context-router`

### Example 2: Sync Runtime And Apply MCP

Use skill: `codex-runtime-sync`

---

## API Reference

### Available Skills

- `repo-context-router`
- `codex-runtime-sync`

### Layout

- `<skill-name>/SKILL.md`: skill contract and behavior.

---

## Build and Tests

```powershell
# verify skill files exist
Get-ChildItem .\.codex\skills -Recurse -Filter SKILL.md

# sync and validate local runtime copy
pwsh -File .\scripts\runtime\bootstrap.ps1
```

---

## Contributing

- Keep skill names stable and descriptive.
- Update this README when adding or removing skills.
- Keep instructions concise and deterministic.

---

## Dependencies

- Runtime: PowerShell 7+ for bootstrap sync.
- Codex runtime in `~/.codex`.

---

## References

- `.codex/README.md`
- `.codex/skills/repo-context-router/SKILL.md`
- `.codex/skills/codex-runtime-sync/SKILL.md`
- `scripts/runtime/bootstrap.ps1`
