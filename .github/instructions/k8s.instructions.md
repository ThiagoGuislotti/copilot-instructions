---
applyTo: "**/{k8s,kubernetes,manifests,helm,charts,deploy,deployment,cluster}*/**/*.{yaml,yml}"
---
Security: Pod Security Standards (restricted); SecurityContext non-root (runAsNonRoot: true, runAsUser: 1001); ReadOnlyRootFilesystem when possible; NetworkPolicies for isolation; minimal RBAC; per-app ServiceAccount; secrets via volumes not env vars.
Example: api Deployment runs as user 1001 with readOnlyRootFilesystem: true; NetworkPolicy allows only namespace backend to access service; mount secret via volume

Resources: always set requests/limits; QoS Guaranteed for critical workloads; ResourceQuotas per namespace; LimitRanges for defaults; HPA/VPA for scaling; PodDisruptionBudgets for availability.
Example: requests: cpu 100m/memory 128Mi; limits: cpu 500m/memory 512Mi; HPA targets 50% CPU between 1 and 5 replicas; PDB minAvailable: 1

Health checks: livenessProbe for auto-restart; readinessProbe for traffic routing; startupProbe for slow apps; appropriate timeouts; HTTP/TCP/exec probes as needed.
Example: readinessProbe httpGet /health/ready initialDelaySeconds 10 periodSeconds 5; livenessProbe httpGet /health/live; startupProbe httpGet /health/startup failureThreshold 30

Configuration: ConfigMaps for non-sensitive config; Secrets for sensitive data; environment-specific configs; hot reload when possible; volume mounts for large files.
Example: ConfigMap appsettings overrides non-sensitive keys; Secret holds connectionString; mount large CA bundle via volume; use envFrom for simple key/value

Networking: appropriate Service types (ClusterIP/NodePort/LoadBalancer); Ingress for HTTP routing; TLS termination; DNS policies; service mesh for complex microservices.
Example: ClusterIP for internal services; Ingress with TLS via cert-manager; set external-dns annotation; restrict access by path rules

Storage: PersistentVolumes for durable data; appropriate StorageClasses; backup strategies; correct access modes (ReadWriteOnce/ReadWriteMany); volume snapshots.
Example: PVC 10Gi RWO on gp2; enable VolumeSnapshotClass; nightly backup job copies to object storage

Observability: structured logging to stdout/stderr; Prometheus metrics endpoints; distributed tracing; log aggregation; dashboards; alerting.
Example: expose /metrics; ServiceMonitor for scraping; OpenTelemetry sidecar or SDK; centralize logs in ELK/Seq; alerts on error rate

Deployment: rolling updates by default; blue-green for zero downtime; canary for critical releases; rollback strategies; health checks during deploy.
Example: strategy RollingUpdate maxUnavailable 25% maxSurge 25%; canary 10% via ingress weight; use preStop hook to drain connections before termination

Scaling: HorizontalPodAutoscaler based on CPU/memory/custom metrics; VerticalPodAutoscaler for right-sizing; cluster autoscaling; pod affinity/anti-affinity.
Example: HPA based on cpu and custom requests_per_second; anti-affinity to spread across nodes; cluster-autoscaler enabled

Production readiness: multi-zone; disaster recovery; backups; security scanning; compliance; cost optimization; capacity planning.
Example: deploy to 3 zones; nightly DR restore test; image scanning in pipeline; resource quotas and budgets; rightsizing with VPA reports

Development: local dev with skaffold/telepresence; staging environments; feature branches; CI/CD integration; test automation; environment parity.
Example: skaffold dev for local loop; ephemeral review apps per PR; staging mirrors prod config with smaller resources; integration tests run in CI namespace

Troubleshooting: kubectl debugging; log aggregation; tracing; performance profiling; resource monitoring; event analysis.
Example: kubectl debug ephemeral container with busybox; kubectl top pod for resource checks; inspect events and describe on failures