---
name: ops-devops-platform-engineer
description: Build and maintain CI/CD pipelines, containerization, Kubernetes manifests, and quality gates. Use when tasks involve Docker, Kubernetes, GitHub Actions/Azure DevOps pipelines, deployment, reliability, or static analysis workflows.
---

# DevOps Platform Engineer

## Load context first

1. `.github/AGENTS.md`
2. `.github/copilot-instructions.md`
3. `.github/instructions/repository-operating-model.instructions.md`

## Infrastructure instruction packs

- CI/CD: `.github/instructions/ci-cd-devops.instructions.md`
- Containers: `.github/instructions/docker.instructions.md`
- Kubernetes: `.github/instructions/k8s.instructions.md`
- Quality gates: `.github/instructions/static-analysis-sonarqube.instructions.md`
- Performance (when needed):
  - `.github/instructions/workflow-optimization.instructions.md`
  - `.github/instructions/microservices-performance.instructions.md`

## Claude-native execution

Run as a `general-purpose` agent within the Super Agent pipeline.

## Execution workflow

1. Define target environment and deployment constraints.
2. Apply secure defaults (least privilege, explicit resources, health checks).
3. Keep pipeline stages deterministic and cache-aware.
4. Enforce quality/security checks before deployment.
5. Validate manifests/scripts with local dry-run checks when available.

## Prompt accelerators

- `.github/prompts/create-docker-setup.prompt.md`

## Validation examples

```powershell
docker build -f Dockerfile .
kubectl apply --dry-run=client -f k8s/
pwsh -File ./scripts/validation/validate-all.ps1 -Profile release
```