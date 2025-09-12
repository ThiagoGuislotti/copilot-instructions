---
applyTo: "**/Dockerfile*"
---
Multi-stage builds: use template .github/templates/dotnet-dockerfile-template as base for .NET projects; stages build/publish/base/final; copy only required artifacts; fixed NetToolsKit layout (src/, samples/, eng/, .build/).
Example: Use mcr.microsoft.com/dotnet/sdk:8.0 as build and mcr.microsoft.com/dotnet/aspnet:8.0-alpine as final; COPY only published output from /app/publish; ENTRYPOINT ["dotnet","Project.dll"]

Security: mandatory non-root user (pattern unet:gnet); distroless images when possible; vulnerability scanning; secrets via environment variables only.
Example: RUN adduser -D -u 1001 unet && addgroup -S gnet && adduser unet gnet; USER unet:gnet; scan image in CI with trivy

Performance: layer caching optimization; COPY order (dependencies first); .dockerignore for exclusions; minimize base image size.
Example: COPY *.csproj and RUN dotnet restore first; .dockerignore excludes bin/ obj/ .git/ node_modules/; consolidate RUN layers

Resource limits: memory/CPU constraints; health checks configured; appropriate restart policies; network security groups.
Example: HEALTHCHECK CMD wget -qO- http://localhost/health/live || exit 1; set container memory limit 512m and cpus 1.0 in compose

Production readiness: environment variables; logging config; monitoring endpoints; graceful shutdown.
Example: configure ASPNETCORE_URLS and Serilog via env; expose /health/ready and /metrics; handle SIGTERM for graceful shutdown

Alpine variants: prefer alpine tags for smaller footprint; install needed dependencies; timezone configuration when required.
Example: RUN apk add --no-cache icu-libs tzdata; set TZ=Etc/UTC; verify size reduction vs non-alpine

Docker Compose: use template .github/templates/docker-compose-template.yml; strict order: image → hostname → container_name → restart → deploy → networks → command → healthcheck → ports → volumes → environment; naming [SERVICE_NAME]-[COMPONENT]-${COMPOSE_PROJECT_NAME}; network isolation; volumes for persistent data; env files; service dependencies with health checks.
Orchestration: labels for metadata; resource reservations; deployment strategies; rolling updates configuration.

Example: com.company=NetToolsKit labels; update_config parallelism 1 delay 10s; deploy resources limits cpus 1.0 memory 512m
Dev workflow: separate development Dockerfile; hot reload; debugging; volume mounts for development.
Example: Dockerfile.dev uses dotnet watch; mount src volume; expose 9229 for debugger; disable trimming