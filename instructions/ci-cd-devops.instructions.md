---
applyTo: "**/{pipeline,ci,cd,deploy,build,workflow,action}*/**/*.{yml,yaml,json,ps1,sh,dockerfile}"
---
Pipeline: separate build/test/package/deploy stages; parallel where possible; fail-fast; artifact management; environment promotion; rollback; infrastructure as code.
Example: Stages build -> test -> package -> deploy; cache restore; publish artifacts; promote to staging then prod with approvals; IaC via Terraform apply

CI: triggers on PRs; multi-platform builds; test pyramid automation; coverage thresholds; static analysis; dependency and secret scanning.
Example: Trigger on PR to main; matrix windows/ubuntu; enforce coverage >= 80% on new code; run secret scanning and SAST in CI

Build optimization: cached deps; incremental builds; multi-stage dockerfiles; version matrix; artifact storage; build time monitoring; proper resource allocation.
Example: Use dotnet restore cache keyed by csproj hash; build only changed projects; Dockerfiles multi-stage; upload build logs and timings

Testing automation: mandatory unit tests; integration in staging; e2e smoke tests; performance regression; security testing; accessibility; DB migration testing.
Example: xUnit unit tests on build; NUnit integration tests on staging with Testcontainers; Playwright smoke suite; k6 baseline perf; verify DB migrations

Code quality: SonarQube; lint; formatting; complexity; duplication; security hotspots; maintainability rating.
Example: Run sonar-scanner with PR decoration; enforce Quality Gate A for new code; ESLint/StyleCop analyzers; auto-fix format issues

Deployment: blue-green; canary; feature flags; health checks; monitoring alerts; automatic rollback; DB migration coordination.
Example: Blue-green to prod; canary 10% traffic for 30m; feature flags via config; health checks gate promotion; auto-rollback on SLO breach

Environments: IaC (Terraform/ARM); environment parity; config management; secrets management; network isolation; resource tagging.
Example: Terraform plans in PR; workspace per env; Key Vault/Secrets Manager; private subnets; tags cost-center=platform

Kubernetes: manifests/helm; resource limits; probes; service discovery; ingress; PVs; security contexts.
Example: Helm chart with values per env; set resources/probes; Ingress with TLS; ServiceAccount with minimal RBAC; PVs for stateful components

Monitoring: app metrics; infra monitoring; distributed tracing; log aggregation; alerting; SLAs; error tracking.
Example: Export Prometheus metrics; alerts on error rate and latency; trace percentiles; centralize logs; SLO dashboards by env

Security: least privilege; image scanning; dependency auditing; secret rotation; network policies; TLS everywhere; audit logging; compliance.
Example: trivy image scan in pipeline; Dependabot/Azure DevOps auditor; rotate secrets quarterly; enforce TLS; NetworkPolicy deny-all default

GitOps: git-based deploys; declarative configs; automated sync; drift detection; access control; approvals; audit trails; DR.
Example: Argo CD sync policies; protected branches for envs; drift alerts; manual approval gates; DR pipeline for failover

Performance: requests/limits; HPA; cluster autoscaling; CDN; caching; DB optimization; connection pooling.
Example: Validate resource requests in CI; enable HPA configs via Helm; CDN cache headers tested; DB query plan regressions flagged

Backups: automated; cross-region replication; verification; restore testing; DR procedures; RTO/RPO; retention policies.
Example: Nightly backups stored cross-region; weekly restore test job; enforce retention 30/90 days per env; RTO/RPO documented

Observability stack: structured logs; metrics; tracing; error tracking; performance; business metrics; cost; capacity planning.
Example: Central stack with Prometheus/Grafana + OpenTelemetry + ELK/Seq; capture business KPIs; cost dashboards; capacity alerts