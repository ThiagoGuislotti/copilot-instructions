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
- ✅ Repository-owned Super Agent lifecycle for intake, specs, planning, specialist routing, review, and closeout
- ✅ Single picker-visible `super-agent` starter/controller for deterministic session bootstrap
- ✅ Worktree isolation and closeout automation skills for high-safety execution
- ✅ Build-time dependency vulnerability auditing for .NET, frontend, and Rust stacks

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
Get-ChildItem "$env:USERPROFILE\.agents\skills"
```

---

## Usage Examples

### Example 1: Software Implementation

Use skills: `super-agent`, `brainstorm-spec-architect`, `plan-active-work-planner`, `context-token-optimizer`, then the routed specialist

### Example 2: Testing and Coverage

Use skill: `test-engineer`

### Example 3: Runtime Sync

Use skill: `core-runtime-sync`

### Example 4: Domain Specialists

Use skills: `dev-dotnet-backend-engineer` (inherits `dev-software-engineer`), `dev-frontend-vue-quasar-engineer`, `dev-rust-engineer`, `plan-task-planner`

### Example 5: High-Performance Secure API

Use skills: `sec-api-performance-security-engineer`, `sec-security-vulnerability-engineer`

### Example 6: Security Gate Before Build

Use skills: `dev-software-engineer`, `ops-devops-platform-engineer`, `test-engineer` with:
- `~/.codex/shared-scripts/security/Invoke-PreBuildSecurityGate.ps1`
- `~/.codex/shared-scripts/security/Invoke-VulnerabilityAudit.ps1`
- `~/.codex/shared-scripts/security/Invoke-FrontendPackageVulnerabilityAudit.ps1`
- `~/.codex/shared-scripts/security/Invoke-RustPackageVulnerabilityAudit.ps1`

### Example 7: Reliability, Chaos, and Observability

Use skills: `ops-resilience-chaos-engineer`, `obs-sre-observability-engineer`

### Example 8: Privacy and Compliance

Use skill: `privacy-compliance-engineer`

### Example 9: Isolated Delivery and Closeout

Use skills: `super-agent`, `worktree-isolation-engineer`, `release-closeout-engineer`

---

## API Reference

### Available Skills

- `core-context-router`
- `core-runtime-sync`
- `super-agent`
- `brainstorm-spec-architect`
- `plan-active-work-planner`
- `context-token-optimizer`
- `worktree-isolation-engineer`
- `release-closeout-engineer`
- `dev-software-engineer` (base)
- `test-engineer`
- `review-code-engineer`
- `ops-devops-platform-engineer`
- `docs-release-engineer`
- `dev-dotnet-backend-engineer` (extends `dev-software-engineer`)
- `dev-frontend-vue-quasar-engineer`
- `sec-security-vulnerability-engineer`
- `dev-rust-engineer`
- `plan-task-planner`
- `sec-api-performance-security-engineer`
- `obs-sre-observability-engineer`
- `privacy-compliance-engineer`
- `ops-resilience-chaos-engineer`

### Layout

- `<skill-name>/SKILL.md`: skill contract and execution behavior.
- `<skill-name>/agents/openai.yaml`: skill UI metadata (display name, short description, default prompt).

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
- `.codex/skills/core-context-router/SKILL.md`
- `.codex/skills/core-runtime-sync/SKILL.md`
- `.github/instruction-routing.catalog.yml`
- `scripts/runtime/bootstrap.ps1`