---
applyTo: "**/*.{cs,csproj,sln,ps1,psm1,rs,toml,ts,tsx,js,jsx,vue,json,jsonc,yml,yaml,md,sql,Dockerfile,sh}"
priority: high
---

# Build And Deployment Artifact Layout

## Purpose
- Standardize non-versioned repository outputs so generated files do not spread across ad-hoc folders.
- Keep build, publish, packaging, generated client, coverage, and deployment-ready outputs in predictable non-versioned locations.

## Canonical Directories
- `.build/`
  - transient build outputs
  - generated intermediate files
  - generated client assets such as `.http` files
  - local diagnostics that are useful during development but are not deployment packages
- `.deployment/`
  - deployment-ready publish outputs
  - packaged artifacts intended for runtime validation, containerization, or release staging
  - test and coverage exports when they represent deployment/release evidence rather than source assets

## Hard Rules
- Do not invent new top-level non-versioned artifact folders when `.build/` or `.deployment/` is sufficient.
- Do not scatter generated outputs under source folders when the artifact is not source of truth.
- Keep both folders ignored by Git.
- Keep source trees clean after builds, tests, code generation, and packaging.

## Usage Guidance
- Use `.build/` for local build-oriented outputs that can be regenerated cheaply.
- Use `.deployment/` for publish/release/package outputs that represent what would be deployed or attached to delivery artifacts.
- Keep nested organization explicit, for example:
  - `.build/generated/`
  - `.build/http/`
  - `.build/logs/`
  - `.deployment/release/`
  - `.deployment/tests/`
  - `.deployment/packages/`

## .NET Guidance
- Redirect generated and publish outputs to `.build/` or `.deployment/` whenever the project or script supports explicit output paths.
- Prefer:
  - `dotnet build -o .build/...` for temporary build outputs
  - `dotnet publish -o .deployment/...` for deployable outputs

## Maintenance Guidance
- Use `scripts/maintenance/clean-build-artifacts.ps1` to clean `.build/`, `.deployment/`, `bin/`, and `obj/`.
- When creating new scripts or templates that emit generated files, default their outputs into one of these canonical directories unless repository context requires a stronger exception.