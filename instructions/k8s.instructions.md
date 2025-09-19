---
applyTo: "**/{k8s,kubernetes,manifests,helm,charts,deploy,deployment,cluster}*/**/*.{yaml,yml}"
---

# Security
- Pod Security Standards (restricted)
- SecurityContext non-root (runAsNonRoot: true, runAsUser: 1001)
- ReadOnlyRootFilesystem when possible
- NetworkPolicies for isolation
- minimal RBAC
- per-app ServiceAccount
- secrets via volumes not env vars
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
  containers:
  - name: app
    image: nginx
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secret
  volumes:
  - name: secret-vol
    secret:
      secretName: mysecret
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: backend
```

# Resources
- always set requests/limits
- QoS Guaranteed for critical workloads
- ResourceQuotas per namespace
- LimitRanges for defaults
- HPA/VPA for scaling
- PodDisruptionBudgets for availability
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-example
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

# Health Checks
- livenessProbe for auto-restart
- readinessProbe for traffic routing
- startupProbe for slow apps
- appropriate timeouts
- HTTP/TCP/exec probes as needed
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: health-pod
spec:
  containers:
  - name: app
    image: nginx
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
    startupProbe:
      httpGet:
        path: /health/startup
        port: 80
      failureThreshold: 30
      periodSeconds: 10
```

# Configuration
- ConfigMaps for non-sensitive config
- Secrets for sensitive data
- environment-specific configs
- hot reload when possible
- volume mounts for large files
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  appsettings.json: |
    {
      "Logging": {
        "LogLevel": {
          "Default": "Information"
        }
      }
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  password: cGFzc3dvcmQ=  # base64 encoded
---
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
spec:
  containers:
  - name: app
    image: nginx
    envFrom:
    - configMapRef:
        name: app-config
    - secretRef:
        name: app-secret
    volumeMounts:
    - name: config-vol
      mountPath: /app/config
  volumes:
  - name: config-vol
    configMap:
      name: app-config
```

# Networking
- appropriate Service types (ClusterIP/NodePort/LoadBalancer)
- Ingress for HTTP routing
- TLS termination
- DNS policies
- service mesh for complex microservices
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: myapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
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
            name: my-service
            port:
              number: 80
```

# Storage
- PersistentVolumes for durable data
- appropriate StorageClasses
- backup strategies
- correct access modes (ReadWriteOnce/ReadWriteMany)
- volume snapshots
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 10Gi
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: csi-aws-vsc
  source:
    persistentVolumeClaimName: my-pvc
```

# Observability
- structured logging to stdout/stderr
- Prometheus metrics endpoints
- distributed tracing
- log aggregation
- dashboards
- alerting
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: observability-pod
spec:
  containers:
  - name: app
    image: nginx
    ports:
    - containerPort: 9090
      name: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-monitor
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    path: /metrics
```

# Deployment
- rolling updates by default
- blue-green for zero downtime
- canary for critical releases
- rollback strategies
- health checks during deploy
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  template:
    spec:
      containers:
      - name: app
        image: nginx
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
```

# Scaling
- HorizontalPodAutoscaler based on CPU/memory/custom metrics
- VerticalPodAutoscaler for right-sizing
- cluster autoscaling
- pod affinity/anti-affinity
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-custom
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: 100
---
apiVersion: v1
kind: Pod
metadata:
  name: affinity-pod
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - myapp
        topologyKey: kubernetes.io/hostname
```

# Production Readiness
- multi-zone
- disaster recovery
- backups
- security scanning
- compliance
- cost optimization
- capacity planning
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-deployment
spec:
  replicas: 3
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: myapp
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

# Development
- local dev with skaffold/telepresence
- staging environments
- feature branches
- CI/CD integration
- test automation
- environment parity
```bash
# Example with Skaffold
skaffold dev --port-forward
```

# Troubleshooting
- kubectl debugging
- log aggregation
- tracing
- performance profiling
- resource monitoring
- event analysis
```bash
kubectl debug my-pod --image=busybox --target=my-container
kubectl top pod
kubectl describe pod my-pod
kubectl get events --sort-by=.metadata.creationTimestamp
```