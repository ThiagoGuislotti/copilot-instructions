---
applyTo: "**/*.{cs,csproj,ps1,rs,toml,ts,tsx,js,jsx,vue,json,jsonc,yml,yaml,md,sql}"
priority: high
---

# Purpose
- Define the single repository-wide policy for resolving technical uncertainty with repository context first and authoritative documentation second.
- Keep the stack-to-domain mapping centralized in `.github/governance/authoritative-source-map.json`.
- Prevent duplicated official documentation domain lists across domain instruction files.

# Resolution Order
1. Use repository context first for project-specific rules, architecture, scripts, templates, conventions, and operational decisions.
2. If the question depends on external platform, framework, library, API, or tool behavior, consult the official documentation for the active stack.
3. If the official documentation is incomplete, consult the official maintainer repository or project documentation.
4. Community sources are fallback only and must not override repository rules or official vendor guidance.

# When External Lookup Is Required
- Version-specific or recently changed behavior
- Security, authentication, authorization, privacy, compliance, or cryptography guidance
- Infrastructure, platform, SDK, CLI, framework, or tooling behavior
- Performance tuning guidance that depends on vendor/runtime specifics
- API behavior, limits, defaults, or deployment/runtime constraints

# Official Source Map
- Use `.github/governance/authoritative-source-map.json` as the single source of truth for stack-specific official domains.
- Prefer the narrowest matching stack entry instead of a broad vendor-wide search.
- Do not copy or restate official documentation domain lists inside other instruction files unless an exception is explicitly justified.

# Response Rules
- State whether the conclusion came from repository context, official documentation, or inference.
- If repository context conflicts with official documentation, follow repository context for internal rules and use official documentation only for external platform behavior.
- For high-risk topics, prefer authoritative documentation over memory.
- When authoritative documentation is unavailable or insufficient, say so explicitly before relying on inference or community material.

# Official Domains by Context
- For the exact stack-to-domain mapping, use `.github/governance/authoritative-source-map.json`.
- Typical examples:
  - `.NET`, `C#`, `ASP.NET Core`, `EF Core`, `PowerShell`, Azure -> `learn.microsoft.com`
  - GitHub Copilot -> `docs.github.com`
  - VS Code -> `code.visualstudio.com`
  - Rust -> `doc.rust-lang.org`, `rust-lang.org`
  - Vue -> `vuejs.org`
  - Quasar -> `quasar.dev`
  - Docker -> `docs.docker.com`
  - Kubernetes -> `kubernetes.io`
  - PostgreSQL -> `postgresql.org`
  - OpenAI -> `platform.openai.com`, `help.openai.com`

# Validation Checklist
- [ ] Repository context was checked first for project-specific rules
- [ ] Official documentation was used for external technical behavior when needed
- [ ] The official domain came from `.github/governance/authoritative-source-map.json`
- [ ] Community material was used only as fallback
- [ ] Final answer identifies the source type (`repo context`, `official docs`, or `inference`)