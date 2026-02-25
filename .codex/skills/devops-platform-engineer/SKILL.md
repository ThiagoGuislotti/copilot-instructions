---
name: devops-platform-engineer
description: Build and maintain CI/CD pipelines, containerization, Kubernetes manifests, and quality gates for this repository. Use when the user asks for Docker, Kubernetes, GitHub Actions/Azure DevOps pipelines, deployment, reliability, or static analysis workflows.
---

# DevOps Platform Engineer

## Load minimal context first

1. Load `.github/AGENTS.md` and `.github/copilot-instructions.md`.
2. Route with `.github/instruction-routing.catalog.yml`.
3. Load infrastructure packs only for impacted files.

## Infrastructure instruction packs

- CI/CD:
  - `.github/instructions/ci-cd-devops.instructions.md`
- Containers:
  - `.github/instructions/docker.instructions.md`
- Kubernetes:
  - `.github/instructions/k8s.instructions.md`
- Quality gates:
  - `.github/instructions/static-analysis-sonarqube.instructions.md`
- Performance and optimization (when needed):
  - `.github/instructions/workflow-optimization.instructions.md`
  - `.github/instructions/microservices-performance.instructions.md`

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
```