---
applyTo: "**/{pipeline,ci,cd,deploy,build,workflow,action}*/**/*.{yml,yaml,json,ps1,sh,dockerfile}"
---

# Pipeline
- Separate build/test/package/deploy stages
- parallel where possible
- fail-fast
- artifact management
- environment promotion
- rollback
- infrastructure as code
```yaml
stages:
  - build
  - test
  - package
  - deploy

jobs:
  build:
    steps:
      - task: DotNetCoreCLI@2
        inputs:
          command: 'restore'
          projects: '**/*.csproj'
      - task: DotNetCoreCLI@2
        inputs:
          command: 'build'
          projects: '**/*.csproj'
  test:
    dependsOn: build
    steps:
      - task: DotNetCoreCLI@2
        inputs:
          command: 'test'
          projects: '**/*Tests.csproj'
  package:
    dependsOn: test
    steps:
      - task: DotNetCoreCLI@2
        inputs:
          command: 'publish'
          publishWebProjects: true
          arguments: '--configuration Release --output $(Build.ArtifactStagingDirectory)'
      - task: PublishBuildArtifacts@1
        inputs:
          PathtoPublish: '$(Build.ArtifactStagingDirectory)'
          ArtifactName: 'drop'
          publishLocation: 'Container'
  deploy:
    dependsOn: package
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureRmWebAppDeployment@4
              inputs:
                ConnectionType: 'AzureRM'
                azureSubscription: 'subscription'
                appType: 'webApp'
                WebAppName: 'myapp'
                packageForLinux: '$(System.ArtifactsDirectory)/drop/**/*.zip'
```

# CI
- Triggers on PRs
- multi-platform builds
- test pyramid automation
- coverage thresholds
- static analysis
- dependency and secret scanning
```yaml
trigger:
  - main
  - feature/*

pr:
  - main

pool:
  vmImage: 'ubuntu-latest'

strategy:
  matrix:
    Windows:
      vmImage: 'windows-latest'
    Linux:
      vmImage: 'ubuntu-latest'

steps:
  - task: UseDotNet@2
    inputs:
      version: '8.x'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'restore'
      projects: '**/*.csproj'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'build'
      projects: '**/*.csproj'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'test'
      projects: '**/*Tests.csproj'
      arguments: '--configuration Release --collect "Code coverage"'
  - task: PublishCodeCoverageResults@1
    inputs:
      codeCoverageTool: 'Cobertura'
      summaryFileLocation: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'
      reportDirectory: '$(Agent.TempDirectory)/**/coverage'
      failIfCoverageEmpty: true
  - task: SonarQubePrepare@4
    inputs:
      SonarQube: 'SonarQube'
      scannerMode: 'MSBuild'
      projectKey: 'myproject'
      projectName: 'My Project'
  - task: SonarQubeAnalyze@4
  - task: SonarQubePublish@4
    inputs:
      pollingTimeoutSec: '300'
```

# Build Optimization
- Cached deps
- incremental builds
- multi-stage dockerfiles
- version matrix
- artifact storage
- build time monitoring
- proper resource allocation
```yaml
variables:
  buildConfiguration: 'Release'
  dotnetSdkVersion: '8.x'

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: Cache@2
    inputs:
      key: 'nuget | "$(Agent.OS)" | **/*.csproj'
      restoreKeys: |
        nuget | "$(Agent.OS)"
      path: $(NUGET_PACKAGES)
  - task: UseDotNet@2
    inputs:
      version: $(dotnetSdkVersion)
  - task: DotNetCoreCLI@2
    inputs:
      command: 'restore'
      projects: '**/*.csproj'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'build'
      projects: '**/*.csproj'
      arguments: '--configuration $(buildConfiguration) --no-restore'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'publish'
      projects: '**/*.csproj'
      publishWebProjects: true
      arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)'
      zipAfterPublish: true
  - task: PublishBuildArtifacts@1
    inputs:
      PathtoPublish: '$(Build.ArtifactStagingDirectory)'
      ArtifactName: 'drop'
      publishLocation: 'Container'
```

# Testing Automation
- Mandatory unit tests
- integration in staging
- e2e smoke tests
- performance regression
- security testing
- accessibility
- DB migration testing
```yaml
stages:
  - stage: UnitTests
    jobs:
      - job: UnitTest
        steps:
          - task: UseDotNet@2
            inputs:
              version: '8.x'
          - task: DotNetCoreCLI@2
            inputs:
              command: 'test'
              projects: '**/*UnitTests.csproj'
              arguments: '--configuration Release --collect "XPlat Code Coverage" -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format= Cobertura'
          - task: PublishCodeCoverageResults@1
            inputs:
              codeCoverageTool: 'Cobertura'
              summaryFileLocation: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'
  - stage: IntegrationTests
    dependsOn: UnitTests
    jobs:
      - job: IntegrationTest
        steps:
          - task: UseDotNet@2
            inputs:
              version: '8.x'
          - task: DotNetCoreCLI@2
            inputs:
              command: 'test'
              projects: '**/*IntegrationTests.csproj'
              arguments: '--configuration Release'
  - stage: E2ETests
    dependsOn: IntegrationTests
    jobs:
      - job: E2ETest
        steps:
          - task: UseNode@1
            inputs:
              version: '18.x'
          - script: npm install
          - script: npx playwright test --headed=false
```

# Code Quality
- SonarQube
- lint
- formatting
- complexity
- duplication
- security hotspots
- maintainability rating
```yaml
steps:
  - task: SonarQubePrepare@4
    inputs:
      SonarQube: 'SonarQube'
      scannerMode: 'MSBuild'
      projectKey: 'myproject'
      projectName: 'My Project'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'build'
      projects: '**/*.csproj'
  - task: SonarQubeAnalyze@4
  - task: SonarQubePublish@4
    inputs:
      pollingTimeoutSec: '300'
  - task: DotNetCoreCLI@2
    inputs:
      command: 'format'
      projects: '**/*.csproj'
      arguments: '--verify-no-changes'
```

# Deployment
- Blue-green
- canary
- feature flags
- health checks
- monitoring alerts
- automatic rollback
- DB migration coordination
```yaml
stages:
  - stage: DeployStaging
    jobs:
      - deployment: DeployStaging
        environment: 'staging'
        strategy:
          blueGreen:
            deploy:
              steps:
                - task: AzureRmWebAppDeployment@4
                  inputs:
                    ConnectionType: 'AzureRM'
                    azureSubscription: 'subscription'
                    appType: 'webApp'
                    WebAppName: 'myapp-staging'
                    packageForLinux: '$(Pipeline.Workspace)/drop/**/*.zip'
            routeTraffic:
              steps:
                - task: AzureAppServiceManage@0
                  inputs:
                    azureSubscription: 'subscription'
                    Action: 'Swap Slots'
                    WebAppName: 'myapp-staging'
                    ResourceGroupName: 'myrg'
                    SourceSlot: 'staging'
  - stage: DeployProduction
    dependsOn: DeployStaging
    jobs:
      - deployment: DeployProduction
        environment: 'production'
        strategy:
          canary:
            increments: [10, 50]
            preDeploy:
              steps:
                - task: AzureRmWebAppDeployment@4
                  inputs:
                    ConnectionType: 'AzureRM'
                    azureSubscription: 'subscription'
                    appType: 'webApp'
                    WebAppName: 'myapp'
                    packageForLinux: '$(Pipeline.Workspace)/drop/**/*.zip'
            deploy:
              steps:
                - script: echo 'Health check passed'
```

# Environments
- IaC (Terraform/ARM)
- environment parity
- config management
- secrets management
- network isolation
- resource tagging
```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "West Europe"
  tags = {
    cost-center = "platform"
  }
}

resource "azurerm_app_service_plan" "example" {
  name                = "asp-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "example" {
  name                = "app-example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  app_service_plan_id = azurerm_app_service_plan.example.id
  site_config {
    linux_fx_version = "DOTNETCORE|8.0"
  }
}
```

# Kubernetes
- Manifests/helm
- resource limits
- probes
- service discovery
- ingress
- PVs
- security contexts
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myregistry/myapp:latest
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          runAsUser: 1001
          runAsGroup: 1001
      serviceAccountName: myapp-sa
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

# Monitoring
- App metrics
- infra monitoring
- distributed tracing
- log aggregation
- alerting
- SLAs
- error tracking
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-alerts
spec:
  groups:
  - name: myapp
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: High error rate detected
```

# Security
- Least privilege
- image scanning
- dependency auditing
- secret rotation
- network policies
- TLS everywhere
- audit logging
- compliance
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
type: Opaque
data:
  password: <base64-encoded>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: myregistry/myapp:latest
        securityContext:
          runAsUser: 1001
          runAsGroup: 1001
```

# GitOps
- Git-based deploys
- declarative configs
- automated sync
- drift detection
- access control
- approvals
- audit trails
- DR
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myrepo
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

# Performance
- Requests/limits
- HPA
- cluster autoscaling
- CDN
- caching
- DB optimization
- connection pooling
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
```

# Backups
- Automated
- cross-region replication
- verification
- restore testing
- DR procedures
- RTO/RPO
- retention policies
```bash
#!/bin/bash
# Backup script
DATE=$(date +%Y%m%d)
BACKUP_DIR="/backups"
DB_NAME="mydb"
pg_dump $DB_NAME > $BACKUP_DIR/$DB_NAME-$DATE.sql
aws s3 cp $BACKUP_DIR/$DB_NAME-$DATE.sql s3://my-backup-bucket/
```

# Observability Stack
- Structured logs
- metrics
- tracing
- error tracking
- performance
- business metrics
- cost
- capacity planning
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Log_Level     info
        Daemon        off
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
    [OUTPUT]
        Name  es
        Match kube.*
        Host  elasticsearch
        Port  9200
        Index myapp-logs
        Type  logs
```