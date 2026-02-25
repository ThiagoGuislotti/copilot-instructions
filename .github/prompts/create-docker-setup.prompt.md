---
description: Generate Docker multi-stage build setup with docker-compose and Kubernetes manifests
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile']
---

# Create Docker Setup
Generate complete Docker setup with multi-stage builds, docker-compose, and Kubernetes manifests.

## Instructions
Create Docker setup based on:
- [docker.instructions.md](../instructions/docker.instructions.md)
- [k8s.instructions.md](../instructions/k8s.instructions.md)
- [ci-cd-devops.instructions.md](../instructions/ci-cd-devops.instructions.md)

## Input Variables
- `${input:appName:Application name}` - Application identifier
- `${input:appType:Application type (api/spa/worker)}` - Application category
- `${input:runtime:Runtime (dotnet/node/rust)}` - Programming runtime
- `${input:exposedPort:Exposed port (e.g., 8080)}` - Container port
- `${input:needsDatabase:Needs database? (yes/no)}` - Database requirement

## 1. Multi-Stage Dockerfile

### .NET API
**Location:** `Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["*.sln", "./"]
COPY ["src/${appName}.Api/*.csproj", "src/${appName}.Api/"]
COPY ["src/${appName}.Application/*.csproj", "src/${appName}.Application/"]
COPY ["src/${appName}.Domain/*.csproj", "src/${appName}.Domain/"]
COPY ["src/${appName}.Infrastructure/*.csproj", "src/${appName}.Infrastructure/"]

# Restore dependencies
RUN dotnet restore

# Copy source code
COPY . .

# Build application
WORKDIR "/src/src/${appName}.Api"
RUN dotnet build -c Release -o /app/build --no-restore

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish --no-restore --no-build /p:UseAppHost=false

# Stage 3: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Security: Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Copy published application
COPY --from=publish --chown=appuser:appuser /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${exposedPort}/health || exit 1

# Expose port
EXPOSE ${exposedPort}

# Entry point
ENTRYPOINT ["dotnet", "${appName}.Api.dll"]
```

### Node.js SPA (Vue/Quasar)
**Location:** `Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy source
COPY . .

# Build application
RUN yarn build

# Stage 2: Runtime (Nginx)
FROM nginx:alpine AS runtime
WORKDIR /usr/share/nginx/html

# Copy built assets
COPY --from=build /app/dist/spa .

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Security: Run as non-root
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chmod -R 755 /usr/share/nginx/html

USER nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${exposedPort}/health || exit 1

EXPOSE ${exposedPort}

CMD ["nginx", "-g", "daemon off;"]
```

### Rust Application
**Location:** `Dockerfile`

```dockerfile
# syntax=docker/dockerfile:1
# Stage 1: Build
FROM rust:1.75 AS build
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    musl-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy Cargo files
COPY Cargo.toml Cargo.lock ./

# Create dummy main to cache dependencies
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy source
COPY . .

# Build application
RUN cargo build --release

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Security: Run as non-root
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Copy binary
COPY --from=build --chown=appuser:appuser /app/target/release/${appName} .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/${appName}", "health-check"]

EXPOSE ${exposedPort}

ENTRYPOINT ["/app/${appName}"]
```

## 2. Docker Compose

### docker-compose.yml
**Location:** `docker-compose.yml`

```yaml
version: '3.8'

services:
  ${appName}:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime
    container_name: ${appName}
    ports:
      - "${exposedPort}:${exposedPort}"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:${exposedPort}
      ${needsDatabase === 'yes' ? '- ConnectionStrings__DefaultConnection=Host=db;Database=${appName};Username=postgres;Password=postgres' : ''}
    ${needsDatabase === 'yes' ? 'depends_on:\n      db:\n        condition: service_healthy' : ''}
    networks:
      - ${appName}-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${exposedPort}/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s

${needsDatabase === 'yes' ? `  db:
    image: postgres:16-alpine
    container_name: ${appName}-db
    environment:
      POSTGRES_DB: ${appName}
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - ${appName}-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5` : ''}

networks:
  ${appName}-network:
    driver: bridge

${needsDatabase === 'yes' ? 'volumes:\n  postgres-data:' : ''}
```

### .dockerignore
**Location:** `.dockerignore`

```
# Git
.git
.gitignore
.gitattributes

# Docker
Dockerfile*
docker-compose*
.dockerignore

# Documentation
README.md
docs/
*.md

# IDE
.vs/
.vscode/
.idea/
*.swp
*.swo

# Build artifacts
**/bin/
**/obj/
**/node_modules/
**/dist/
**/target/
*.log

# Test files
**/tests/
**/*.test.*
**/*.spec.*

# CI/CD
.github/
.gitlab-ci.yml
azure-pipelines.yml
```

## 3. Kubernetes Manifests

### deployment.yaml
**Location:** `k8s/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${appName}
  labels:
    app: ${appName}
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${appName}
  template:
    metadata:
      labels:
        app: ${appName}
        version: v1
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: ${appName}
        image: ${registry}/${appName}:latest
        imagePullPolicy: Always
        ports:
        - containerPort: ${exposedPort}
          protocol: TCP
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: ASPNETCORE_URLS
          value: "http://+:${exposedPort}"
        ${needsDatabase === 'yes' ? '- name: ConnectionStrings__DefaultConnection\n          valueFrom:\n            secretKeyRef:\n              name: ' + appName + '-secrets\n              key: db-connection-string' : ''}
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: ${exposedPort}
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: ${exposedPort}
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
```

### service.yaml
**Location:** `k8s/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ${appName}
  labels:
    app: ${appName}
spec:
  type: ClusterIP
  selector:
    app: ${appName}
  ports:
  - name: http
    port: 80
    targetPort: ${exposedPort}
    protocol: TCP
```

### ingress.yaml
**Location:** `k8s/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${appName}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${appName}.example.com
    secretName: ${appName}-tls
  rules:
  - host: ${appName}.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${appName}
            port:
              number: 80
```

### configmap.yaml
**Location:** `k8s/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${appName}-config
data:
  app-settings: |
    {
      "Logging": {
        "LogLevel": {
          "Default": "Information",
          "Microsoft.AspNetCore": "Warning"
        }
      }
    }
```

### secrets.yaml (Template)
**Location:** `k8s/secrets.yaml.template`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${appName}-secrets
type: Opaque
stringData:
  ${needsDatabase === 'yes' ? 'db-connection-string: "REPLACE_WITH_ACTUAL_CONNECTION_STRING"' : 'api-key: "REPLACE_WITH_ACTUAL_API_KEY"'}
```

## 4. Build & Run Scripts

### build.sh
**Location:** `scripts/build.sh`

```bash
#!/bin/bash
set -e

APP_NAME="${appName}"
REGISTRY="${registry}"
VERSION="${version:-latest}"

echo "Building Docker image..."
docker build -t ${REGISTRY}/${APP_NAME}:${VERSION} .

echo "Tagging as latest..."
docker tag ${REGISTRY}/${APP_NAME}:${VERSION} ${REGISTRY}/${APP_NAME}:latest

echo "Build complete!"
echo "Image: ${REGISTRY}/${APP_NAME}:${VERSION}"
```

### deploy.sh
**Location:** `scripts/deploy.sh`

```bash
#!/bin/bash
set -e

APP_NAME="${appName}"
NAMESPACE="${namespace:-default}"

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/configmap.yaml -n ${NAMESPACE}
kubectl apply -f k8s/secrets.yaml -n ${NAMESPACE}
kubectl apply -f k8s/deployment.yaml -n ${NAMESPACE}
kubectl apply -f k8s/service.yaml -n ${NAMESPACE}
kubectl apply -f k8s/ingress.yaml -n ${NAMESPACE}

echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE}

echo "Deployment complete!"
```

## Quality Checklist
- [ ] Multi-stage Dockerfile with minimal runtime image
- [ ] Non-root user in container (security)
- [ ] Health checks configured
- [ ] .dockerignore excludes build artifacts
- [ ] docker-compose.yml with networks and volumes
- [ ] Kubernetes manifests with resource limits
- [ ] Liveness and readiness probes
- [ ] Security context (no privilege escalation)
- [ ] ConfigMaps for configuration
- [ ] Secrets for sensitive data (template only)
- [ ] Build and deploy scripts executable

Generate complete Docker setup following DevOps best practices.