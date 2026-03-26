---
applyTo: "**/Dockerfile*"
priority: medium
---

# Multi-stage Builds
- ALWAYS use template .github/templates/dotnet-dockerfile-template as base for .NET projects
- stages build/publish/base/final
- copy only required artifacts
- fixed NetToolsKit layout (src/, samples/, eng/, .build/)
```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/MyApp/MyApp.csproj", "src/MyApp/"]
RUN dotnet restore "src/MyApp/MyApp.csproj"
COPY . .
WORKDIR "/src/src/MyApp"
RUN dotnet build "MyApp.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "MyApp.csproj" -c Release -o /app/publish

# Final stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

# Security
- Mandatory non-root user (pattern unet:gnet)
- distroless images when possible
- vulnerability scanning
- secrets via environment variables only
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS base
RUN adduser -D -u 1001 unet && addgroup -S gnet && adduser unet gnet
USER unet:gnet
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

# Performance
- Layer caching optimization
- COPY order (dependencies first)
- .dockerignore for exclusions
- minimize base image size
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/MyApp/MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet build -c Release -o /app/build
```

# Resource Limits
- Memory/CPU constraints
- health checks configured
- appropriate restart policies
- network security groups
```yaml
version: '3.8'
services:
  myapp:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
```

# Production Readiness
- Environment variables
- logging config
- monitoring endpoints
- graceful shutdown
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
ENV ASPNETCORE_URLS=http://+:80
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 80
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

# Alpine Variants
- Prefer alpine tags for smaller footprint
- install needed dependencies
- timezone configuration when required
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
RUN apk add --no-cache icu-libs tzdata
ENV TZ=Etc/UTC
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

# Docker Compose
- ALWAYS use template .github/templates/docker-compose-template.yml
- strict order: image → hostname → container_name → restart → deploy → networks → command → healthcheck → ports → volumes → environment
- naming [SERVICE_NAME]-[COMPONENT]-${COMPOSE_PROJECT_NAME}
- network isolation
- volumes for persistent data
- env files
- service dependencies with health checks
See .github/templates/docker-compose-template.yml for full example.

# Orchestration
- Labels for metadata
- resource reservations
- deployment strategies
- rolling updates configuration
```yaml
version: '3.8'
services:
  myapp:
    image: myregistry/myapp:latest
    deploy:
      labels:
        com.company: NetToolsKit
        com.version: "1.0"
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
```

# Dev Workflow
- Separate development Dockerfile
- hot reload
- debugging
- volume mounts for development
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS dev
WORKDIR /src
COPY ["src/MyApp/MyApp.csproj", "."]
RUN dotnet restore
COPY . .
EXPOSE 5000 9229
CMD ["dotnet", "watch", "run", "--urls", "http://+:5000"]
```