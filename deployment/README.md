# MCP Ballerina Server Deployment

This directory contains comprehensive Kubernetes deployment configurations for the MCP Ballerina Server, including both raw Kubernetes manifests and Helm charts.

## 📁 Directory Structure

```
deployment/
├── kubernetes/                 # Raw Kubernetes manifests
│   ├── namespace.yaml         # Namespace and resource quotas
│   ├── rbac.yaml             # Service account and RBAC
│   ├── configmap.yaml        # Configuration files
│   ├── secret.yaml           # Sensitive configuration
│   ├── pvc.yaml             # Persistent volume claims
│   ├── deployment.yaml       # Main application deployment
│   ├── service.yaml          # Service definitions
│   ├── ingress.yaml          # Ingress configurations
│   ├── hpa.yaml             # Horizontal/Vertical Pod Autoscaling
│   ├── servicemonitor.yaml   # Prometheus monitoring
│   ├── network-policy.yaml   # Network security policies
│   └── kustomization.yaml    # Kustomize configuration
├── helm/                     # Helm chart
│   └── mcp-ballerina/
│       ├── Chart.yaml        # Chart metadata
│       ├── values.yaml       # Default configuration
│       ├── templates/        # Kubernetes templates
│       │   ├── _helpers.tpl  # Template helpers
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── ingress.yaml
│       │   └── tests/        # Helm tests
│       └── README.md
├── gitops/                   # GitOps configurations
│   └── argocd-application.yaml # ArgoCD application
└── README.md                 # This file
```

## 🚀 Quick Start

### Using Kubernetes Manifests

1. **Apply the manifests directly:**
   ```bash
   kubectl apply -f deployment/kubernetes/
   ```

2. **Or use Kustomize:**
   ```bash
   kubectl apply -k deployment/kubernetes/
   ```

### Using Helm Chart

1. **Install from local chart:**
   ```bash
   helm install mcp-ballerina deployment/helm/mcp-ballerina \
     --namespace mcp-ballerina \
     --create-namespace
   ```

2. **Install with custom values:**
   ```bash
   helm install mcp-ballerina deployment/helm/mcp-ballerina \
     --namespace mcp-ballerina \
     --create-namespace \
     --values custom-values.yaml
   ```

3. **Upgrade deployment:**
   ```bash
   helm upgrade mcp-ballerina deployment/helm/mcp-ballerina \
     --namespace mcp-ballerina
   ```

## 🔧 Configuration

### Environment Variables

Key configuration options:

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_OPTS` | `-Xmx1536m -Xms512m -XX:+UseG1GC` | JVM options |
| `SERVER_PORT` | `8080` | Application port |
| `METRICS_PORT` | `9090` | Metrics endpoint port |
| `LOG_LEVEL` | `INFO` | Logging level |
| `ENVIRONMENT` | `production` | Runtime environment |

### Helm Values

Key Helm configuration options:

```yaml
# Deployment
deployment:
  replicaCount: 3
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi

# Autoscaling
autoscaling:
  hpa:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70

# Ingress
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: mcp-ballerina.example.com
      paths:
        - path: /
          pathType: Prefix

# Dependencies
postgresql:
  enabled: true
  auth:
    database: mcp_ballerina
    username: mcp_user

redis:
  enabled: true
  auth:
    enabled: true
```

## 🏗️ Architecture Features

### Production Best Practices

- **Security:**
  - Non-root containers with read-only file systems
  - Security contexts and Pod Security Standards
  - Network policies for traffic isolation
  - RBAC with least privilege access

- **Reliability:**
  - Multi-replica deployment with anti-affinity
  - Pod Disruption Budgets
  - Comprehensive health checks (liveness, readiness, startup)
  - Graceful shutdown handling

- **Scalability:**
  - Horizontal Pod Autoscaling (HPA)
  - Vertical Pod Autoscaling (VPA) support
  - KEDA integration for advanced scaling
  - Resource quotas and limits

- **Observability:**
  - Prometheus metrics with ServiceMonitor
  - Structured JSON logging
  - Distributed tracing ready
  - Comprehensive alerting rules

### High Availability

- **Multi-AZ Deployment:** Pod anti-affinity rules spread pods across availability zones
- **Load Balancing:** Service mesh integration with Nginx sidecar
- **Database:** PostgreSQL with replication support
- **Cache:** Redis with master-replica configuration
- **Storage:** Multiple persistent volumes with appropriate storage classes

## 📊 Monitoring & Alerting

### Prometheus Metrics

The deployment includes ServiceMonitor configuration for Prometheus to scrape:

- Application metrics on `:9090/metrics`
- JVM metrics (memory, GC, threads)
- HTTP request metrics (latency, throughput, errors)
- Business metrics (MCP operations, connections)

### Default Alerts

Pre-configured alerting rules monitor:

- High error rates (>10% for 5 minutes)
- High response times (95th percentile >1s for 5 minutes)
- High CPU usage (>80% for 10 minutes)
- High memory usage (>90% for 10 minutes)
- Pod crash looping or not ready
- Service unavailability

### Grafana Dashboards

Dashboard templates are available for:
- Application overview and health
- Performance metrics and trends
- Infrastructure resource usage
- Alert status and history

## 🔐 Security

### Network Security

- **Network Policies:** Restrict traffic between pods and namespaces
- **Ingress Security:** Rate limiting, CORS, security headers
- **TLS Encryption:** End-to-end encryption with cert-manager integration

### Container Security

- **Image Scanning:** Base images are regularly scanned for vulnerabilities
- **Non-root Execution:** All containers run as non-root users
- **Read-only Filesystems:** Root filesystems are read-only where possible
- **Capability Dropping:** All unnecessary Linux capabilities are dropped

### Secrets Management

- **Kubernetes Secrets:** Sensitive data stored in Kubernetes secrets
- **External Secrets Operator:** Integration with external secret management systems
- **Vault Integration:** HashiCorp Vault support for secret rotation

## 🚢 GitOps Integration

### ArgoCD

The deployment includes ArgoCD Application configurations for:

- **Automated Sync:** Automatic deployment of changes from Git
- **Multi-Environment:** Separate configurations for dev/staging/prod
- **Rollback Support:** Easy rollback to previous versions
- **Health Monitoring:** Application health status in ArgoCD UI

### Deployment Strategies

- **Blue-Green:** Zero-downtime deployments with traffic switching
- **Canary:** Gradual rollout with traffic splitting
- **Rolling Update:** Default Kubernetes rolling update strategy

## 🧪 Testing

### Helm Tests

```bash
helm test mcp-ballerina --namespace mcp-ballerina
```

Tests include:
- Service connectivity
- Health endpoint responses
- API functionality
- Database connectivity
- Metrics endpoint availability

### Load Testing

Example load test using k6:

```javascript
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let response = http.get('https://mcp-ballerina.example.com/health');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
}
```

## 🔄 Maintenance

### Regular Tasks

1. **Update Dependencies:**
   ```bash
   helm dependency update deployment/helm/mcp-ballerina
   ```

2. **Backup Persistent Data:**
   ```bash
   kubectl create job --from=cronjob/backup-job backup-manual-$(date +%s)
   ```

3. **Monitor Resource Usage:**
   ```bash
   kubectl top pods -n mcp-ballerina
   kubectl describe hpa mcp-ballerina -n mcp-ballerina
   ```

4. **Review Logs:**
   ```bash
   kubectl logs -f deployment/mcp-ballerina -n mcp-ballerina -c mcp-ballerina
   ```

### Troubleshooting

Common issues and solutions:

1. **Pods Not Starting:**
   - Check resource limits and node capacity
   - Verify image pull secrets and registry access
   - Review security context and PodSecurityPolicy

2. **High Memory Usage:**
   - Adjust JVM heap settings in `JAVA_OPTS`
   - Review application memory leaks
   - Consider vertical pod autoscaling

3. **Database Connection Issues:**
   - Verify PostgreSQL service and endpoints
   - Check network policies and security groups
   - Review connection pool configuration

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [KEDA Documentation](https://keda.sh/docs/)

## 🆘 Support

For issues and questions:
- Create an issue in the [GitHub repository](https://github.com/example/mcp-ballerina/issues)
- Contact the platform team: platform-team@company.com
- Slack channel: #mcp-ballerina-support