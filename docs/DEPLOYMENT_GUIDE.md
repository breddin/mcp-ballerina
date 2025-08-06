# MCP Ballerina Server Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Methods](#deployment-methods)
4. [Docker Deployment](#docker-deployment)
5. [Kubernetes Deployment](#kubernetes-deployment)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Monitoring & Observability](#monitoring--observability)
8. [Security Considerations](#security-considerations)
9. [Troubleshooting](#troubleshooting)
10. [Production Checklist](#production-checklist)

## Overview

The MCP Ballerina Server can be deployed using multiple methods depending on your infrastructure and requirements. This guide covers Docker, Kubernetes, and cloud-native deployments with comprehensive monitoring and security.

### Architecture Overview
```
┌─────────────────────────────────────────┐
│            Load Balancer                 │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│           Ingress Controller             │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│        MCP Ballerina Pods (3+)          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐│
│  │   Pod 1  │ │   Pod 2  │ │   Pod 3  ││
│  └──────────┘ └──────────┘ └──────────┘│
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Supporting Services              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌────────┐│
│  │Redis │ │Postgres│ │Prometheus│ │Grafana││
│  └──────┘ └──────┘ └──────┘ └────────┘│
└─────────────────────────────────────────┘
```

## Prerequisites

### System Requirements
- **CPU**: 4+ cores (8+ recommended for production)
- **Memory**: 8GB minimum (16GB+ recommended)
- **Storage**: 50GB SSD minimum
- **Network**: 1Gbps+ network connectivity

### Software Requirements
- Docker 20.10+ and Docker Compose 2.0+
- Kubernetes 1.24+ (for K8s deployment)
- Helm 3.8+ (for Helm deployment)
- kubectl configured with cluster access
- GitHub account with repository access

### Ports
- `8080`: HTTP API
- `8443`: HTTPS API
- `9090`: Metrics endpoint
- `8090`: WebSocket collaboration
- `5005`: Debug port (development only)

## Deployment Methods

### Quick Start Options

#### 1. Local Development
```bash
# Using Docker Compose
cd deployment/docker
docker-compose -f docker-compose.dev.yml up

# Access at http://localhost:8080
```

#### 2. Production Docker
```bash
# Using production compose
cd deployment/docker
./scripts/deploy.sh production

# Access at https://localhost:8443
```

#### 3. Kubernetes
```bash
# Using Helm
cd deployment/helm/mcp-ballerina
helm install mcp-ballerina . -n mcp-ballerina --create-namespace

# Using kubectl
kubectl apply -k deployment/kubernetes/
```

## Docker Deployment

### Building the Image

```bash
# Build production image
docker build -t mcp-ballerina:latest .

# Build with specific version
docker build -t mcp-ballerina:1.0.0 \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') .

# Multi-architecture build
docker buildx build --platform linux/amd64,linux/arm64 \
  -t mcp-ballerina:latest --push .
```

### Running with Docker

#### Standalone Container
```bash
# Basic run
docker run -d \
  --name mcp-ballerina \
  -p 8080:8080 \
  -p 9090:9090 \
  mcp-ballerina:latest

# With environment variables
docker run -d \
  --name mcp-ballerina \
  -p 8080:8080 \
  -e DB_HOST=postgres \
  -e REDIS_URL=redis://redis:6379 \
  -e LOG_LEVEL=INFO \
  -v $(pwd)/config:/app/config \
  -v mcp-data:/app/data \
  mcp-ballerina:latest

# With resource limits
docker run -d \
  --name mcp-ballerina \
  --memory="2g" \
  --memory-swap="2g" \
  --cpus="2" \
  -p 8080:8080 \
  mcp-ballerina:latest
```

### Docker Compose Deployment

#### Development Stack
```bash
cd deployment/docker

# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f mcp-ballerina

# Scale services
docker-compose -f docker-compose.dev.yml up -d --scale mcp-ballerina=3

# Stop services
docker-compose -f docker-compose.dev.yml down
```

#### Production Stack
```bash
cd deployment/docker

# Generate SSL certificates
./scripts/generate-certs.sh

# Start production stack
docker-compose up -d

# Check health
docker-compose exec mcp-ballerina health-check

# View metrics
open http://localhost:3000  # Grafana
open http://localhost:9091  # Prometheus
```

### Docker Swarm Deployment
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml mcp-ballerina

# Scale service
docker service scale mcp-ballerina_server=5

# Update service
docker service update \
  --image mcp-ballerina:1.0.1 \
  mcp-ballerina_server
```

## Kubernetes Deployment

### Using kubectl

#### Basic Deployment
```bash
# Create namespace
kubectl create namespace mcp-ballerina

# Apply configurations
kubectl apply -f deployment/kubernetes/namespace.yaml
kubectl apply -f deployment/kubernetes/configmap.yaml
kubectl apply -f deployment/kubernetes/secret.yaml
kubectl apply -f deployment/kubernetes/deployment.yaml
kubectl apply -f deployment/kubernetes/service.yaml
kubectl apply -f deployment/kubernetes/ingress.yaml

# Check deployment status
kubectl get all -n mcp-ballerina

# View logs
kubectl logs -f deployment/mcp-ballerina -n mcp-ballerina
```

#### Using Kustomize
```bash
# Deploy to development
kubectl apply -k deployment/kubernetes/overlays/development

# Deploy to production
kubectl apply -k deployment/kubernetes/overlays/production

# Dry run
kubectl apply -k deployment/kubernetes/ --dry-run=client -o yaml
```

### Using Helm

#### Install Chart
```bash
cd deployment/helm/mcp-ballerina

# Install with default values
helm install mcp-ballerina . -n mcp-ballerina --create-namespace

# Install with custom values
helm install mcp-ballerina . \
  -f values.production.yaml \
  -n mcp-ballerina \
  --create-namespace

# Install with overrides
helm install mcp-ballerina . \
  --set image.tag=1.0.1 \
  --set replicaCount=5 \
  --set ingress.enabled=true \
  --set ingress.host=mcp.example.com
```

#### Upgrade Deployment
```bash
# Upgrade with new values
helm upgrade mcp-ballerina . \
  -f values.production.yaml \
  --atomic \
  --cleanup-on-fail

# Rollback if needed
helm rollback mcp-ballerina

# View history
helm history mcp-ballerina
```

### Advanced Kubernetes Features

#### Horizontal Pod Autoscaling
```bash
# Apply HPA
kubectl apply -f deployment/kubernetes/hpa.yaml

# Check HPA status
kubectl get hpa -n mcp-ballerina

# Manual scale
kubectl scale deployment mcp-ballerina --replicas=5 -n mcp-ballerina
```

#### Network Policies
```bash
# Apply network policies
kubectl apply -f deployment/kubernetes/network-policy.yaml

# Verify policies
kubectl describe networkpolicy -n mcp-ballerina
```

#### Pod Disruption Budgets
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: mcp-ballerina-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: mcp-ballerina
```

### GitOps with ArgoCD

```bash
# Apply ArgoCD application
kubectl apply -f deployment/gitops/argocd-application.yaml

# Sync application
argocd app sync mcp-ballerina

# Check sync status
argocd app get mcp-ballerina
```

## CI/CD Pipeline

### GitHub Actions Workflows

The project includes comprehensive CI/CD pipelines:

#### Continuous Integration
```yaml
# .github/workflows/ci.yml
- Build and test on every push
- Multi-OS and multi-version testing
- Security scanning with Trivy
- Code coverage reporting
- Artifact publishing
```

#### Release Automation
```yaml
# .github/workflows/release.yml
- Semantic versioning
- Automated changelog generation
- Docker image building and pushing
- GitHub release creation
- Ballerina Central publishing
```

### Setting up CI/CD

1. **Configure Secrets**:
```bash
# Add to GitHub repository secrets
DOCKER_USERNAME
DOCKER_PASSWORD
BALLERINA_CENTRAL_TOKEN
CODECOV_TOKEN
SONAR_TOKEN
```

2. **Enable Workflows**:
```bash
# Ensure workflows are enabled
gh workflow enable ci.yml
gh workflow enable release.yml
gh workflow enable quality.yml
```

3. **Trigger Deployment**:
```bash
# Create release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Manual workflow trigger
gh workflow run deploy.yml -f environment=production
```

## Monitoring & Observability

### Metrics Collection

#### Prometheus Setup
```bash
# Deploy Prometheus
kubectl apply -f deployment/monitoring/prometheus/

# Access Prometheus UI
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
open http://localhost:9090
```

#### Key Metrics
- `mcp_ballerina_requests_total` - Total requests
- `mcp_ballerina_request_duration_seconds` - Request latency
- `mcp_ballerina_errors_total` - Error count
- `mcp_ballerina_cache_hit_rate` - Cache effectiveness
- `mcp_ballerina_websocket_connections` - Active connections

### Grafana Dashboards

```bash
# Import dashboard
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @deployment/monitoring/grafana/dashboards/mcp-ballerina-dashboard.json
```

### Logging

#### Structured Logging
```ballerina
// Application logs in JSON format
{
  "timestamp": "2025-01-06T10:30:00Z",
  "level": "INFO",
  "component": "mcp-ballerina",
  "message": "Request processed",
  "trace_id": "abc123",
  "duration_ms": 45
}
```

#### Log Aggregation with ELK
```bash
# Deploy ELK stack
docker-compose -f docker-compose.monitoring.yml up -d

# Access Kibana
open http://localhost:5601
```

### Distributed Tracing

```bash
# Deploy Jaeger
kubectl apply -f deployment/monitoring/jaeger/

# Access Jaeger UI
kubectl port-forward svc/jaeger-query 16686:16686
open http://localhost:16686
```

### Alerting

#### Alert Rules
```yaml
# Configured in deployment/monitoring/prometheus/alerts.yml
- Service down alerts
- High error rate alerts
- Performance degradation alerts
- Resource exhaustion alerts
- Security alerts
```

#### Alert Channels
```bash
# Configure Alertmanager
kubectl apply -f deployment/monitoring/alertmanager/

# Supported channels:
- Email
- Slack
- PagerDuty
- Webhook
```

## Security Considerations

### Container Security

1. **Non-root User**:
```dockerfile
USER ballerina:ballerina
```

2. **Read-only Filesystem**:
```yaml
securityContext:
  readOnlyRootFilesystem: true
```

3. **Security Scanning**:
```bash
# Scan image with Trivy
trivy image mcp-ballerina:latest

# Scan with Grype
grype mcp-ballerina:latest
```

### Network Security

1. **TLS Configuration**:
```yaml
ingress:
  tls:
    - secretName: mcp-ballerina-tls
      hosts:
        - mcp.example.com
```

2. **Network Policies**:
```yaml
# Restrict traffic to/from pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mcp-ballerina-netpol
spec:
  podSelector:
    matchLabels:
      app: mcp-ballerina
  policyTypes:
    - Ingress
    - Egress
```

### Secrets Management

1. **Kubernetes Secrets**:
```bash
# Create secret
kubectl create secret generic mcp-ballerina-secrets \
  --from-literal=db-password=secret \
  --from-literal=api-key=key123

# Use in deployment
envFrom:
  - secretRef:
      name: mcp-ballerina-secrets
```

2. **External Secrets**:
```yaml
# Using External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
```

### RBAC Configuration

```yaml
# Minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mcp-ballerina-role
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
```

## Troubleshooting

### Common Issues

#### Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n mcp-ballerina

# Check events
kubectl get events -n mcp-ballerina --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n mcp-ballerina --previous
```

#### High Memory Usage
```bash
# Check memory usage
kubectl top pods -n mcp-ballerina

# Increase limits
kubectl set resources deployment mcp-ballerina \
  --limits=memory=4Gi -n mcp-ballerina
```

#### Connection Issues
```bash
# Test service connectivity
kubectl run debug --image=busybox -it --rm --restart=Never -- \
  wget -O- http://mcp-ballerina:8080/health

# Check service endpoints
kubectl get endpoints -n mcp-ballerina
```

### Debug Mode

```bash
# Enable debug logging
kubectl set env deployment/mcp-ballerina LOG_LEVEL=DEBUG -n mcp-ballerina

# Port forward for debugging
kubectl port-forward deployment/mcp-ballerina 5005:5005 -n mcp-ballerina

# Attach debugger to localhost:5005
```

### Performance Tuning

```bash
# Adjust JVM settings
kubectl set env deployment/mcp-ballerina \
  JAVA_OPTS="-Xmx2g -Xms1g -XX:+UseG1GC" -n mcp-ballerina

# Scale horizontally
kubectl scale deployment mcp-ballerina --replicas=10 -n mcp-ballerina

# Enable caching
kubectl set env deployment/mcp-ballerina \
  CACHE_ENABLED=true \
  CACHE_SIZE=1000 -n mcp-ballerina
```

## Production Checklist

### Pre-deployment
- [ ] Security scanning completed
- [ ] Load testing performed
- [ ] Backup strategy defined
- [ ] Monitoring configured
- [ ] Alerting rules set up
- [ ] Documentation updated
- [ ] Runbook created

### Deployment
- [ ] Use specific image tags (not latest)
- [ ] Configure resource limits
- [ ] Enable health checks
- [ ] Set up auto-scaling
- [ ] Configure PDB
- [ ] Enable TLS
- [ ] Set up ingress rules

### Post-deployment
- [ ] Verify health endpoints
- [ ] Check metrics collection
- [ ] Test alerting
- [ ] Verify backup/restore
- [ ] Performance baseline
- [ ] Security audit
- [ ] Documentation review

### Maintenance
- [ ] Regular updates schedule
- [ ] Backup verification
- [ ] Certificate renewal
- [ ] Capacity planning
- [ ] Incident response drills
- [ ] Security patches

## Support

### Resources
- [GitHub Repository](https://github.com/breddin/mcp-ballerina)
- [API Documentation](./API_REFERENCE.md)
- [Architecture Guide](./ARCHITECTURE.md)
- [Developer Guide](./DEVELOPER_GUIDE.md)

### Getting Help
- GitHub Issues: Report bugs and feature requests
- Discussions: Ask questions and share ideas
- Security: Report vulnerabilities privately

### Monitoring Endpoints
- `/health` - Health check
- `/ready` - Readiness check
- `/metrics` - Prometheus metrics
- `/api/v1/status` - Detailed status

---

## Quick Reference

### Essential Commands
```bash
# Docker
docker-compose up -d
docker-compose logs -f
docker-compose down

# Kubernetes
kubectl apply -k deployment/kubernetes/
kubectl get all -n mcp-ballerina
kubectl logs -f deployment/mcp-ballerina -n mcp-ballerina

# Helm
helm install mcp-ballerina ./deployment/helm/mcp-ballerina
helm upgrade mcp-ballerina ./deployment/helm/mcp-ballerina
helm rollback mcp-ballerina

# Monitoring
kubectl port-forward svc/prometheus 9090:9090
kubectl port-forward svc/grafana 3000:3000
```

### Environment Variables
```bash
PORT=8080
LOG_LEVEL=INFO
DB_HOST=localhost
DB_PORT=5432
REDIS_URL=redis://localhost:6379
CACHE_ENABLED=true
METRICS_ENABLED=true
```

This deployment guide provides comprehensive instructions for deploying the MCP Ballerina Server in various environments with production-grade monitoring, security, and scalability.