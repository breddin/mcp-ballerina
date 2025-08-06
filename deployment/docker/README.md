# MCP Ballerina Server - Docker Deployment

This directory contains comprehensive Docker configurations for deploying the MCP Ballerina server in various environments.

## 📁 Structure

```
deployment/docker/
├── docker-compose.yml          # Production deployment
├── docker-compose.dev.yml      # Development deployment
├── Dockerfile                  # Production image
├── Dockerfile.dev             # Development image
├── scripts/
│   └── deploy.sh              # Deployment script
├── monitoring/
│   ├── prometheus.yml         # Prometheus configuration
│   ├── prometheus-dev.yml     # Development Prometheus
│   ├── alert.rules.yml        # Alerting rules
│   ├── filebeat.yml          # Log shipping
│   ├── redis.conf            # Redis configuration
│   └── grafana/
│       ├── datasources/      # Grafana datasources
│       └── dashboards/       # Grafana dashboards
├── nginx/
│   └── nginx.conf            # Reverse proxy configuration
├── config/
│   └── app-config.toml       # Application configuration
└── dev/
    └── init-db.sql           # Development database setup
```

## 🚀 Quick Start

### Production Deployment

```bash
# Deploy to production
./scripts/deploy.sh production

# Deploy with fresh build
./scripts/deploy.sh production true

# Check status
./scripts/deploy.sh --status
```

### Development Deployment

```bash
# Deploy development environment
./scripts/deploy.sh development

# Check development status
docker-compose -f docker-compose.dev.yml ps
```

## 🐳 Services Overview

### Production Stack

| Service | Port | Description |
|---------|------|-------------|
| MCP Server | 8080, 8443 | Main Ballerina application |
| Nginx | 80, 443 | Reverse proxy with SSL |
| Prometheus | 9091 | Metrics collection |
| Grafana | 3000 | Metrics visualization |
| Elasticsearch | 9200 | Log storage |
| Kibana | 5601 | Log visualization |
| Redis | 6379 | Caching and sessions |

### Development Stack

| Service | Port | Description |
|---------|------|-------------|
| MCP Server | 8080 | Development server with debug |
| PostgreSQL | 5432 | Development database |
| Redis | 6379 | Development cache |
| Prometheus | 9091 | Development metrics |
| Grafana | 3000 | Development dashboards |
| Swagger UI | 8081 | API documentation |

## 🔧 Configuration

### Environment Variables

**Production:**
```bash
MCP_SERVER_PORT=8080
MCP_METRICS_PORT=9090
LOG_LEVEL=INFO
JVM_HEAP_SIZE=1g
PROMETHEUS_ENABLED=true
```

**Development:**
```bash
MCP_SERVER_PORT=8080
LOG_LEVEL=DEBUG
BALLERINA_DEBUG=true
HOT_RELOAD=true
```

### SSL Certificates

For production deployment, place SSL certificates in:
```
nginx/ssl/server.crt
nginx/ssl/server.key
```

Or use the deployment script to generate self-signed certificates for testing.

## 📊 Monitoring

### Prometheus Metrics

Available at `http://localhost:9091`

Key metrics collected:
- HTTP request rates and response times
- JVM memory and CPU usage
- Application-specific metrics
- Container resource usage

### Grafana Dashboards

Access at `http://localhost:3000` (admin/admin123)

Pre-configured dashboards for:
- Application performance
- Infrastructure monitoring
- Error tracking
- Business metrics

### Alerting

Configured alerts for:
- Service downtime
- High error rates
- Resource exhaustion
- Performance degradation

## 📝 Logging

### Production Logging

- **Filebeat** → **Elasticsearch** → **Kibana**
- Structured JSON logging
- Log aggregation from all containers
- Centralized log analysis in Kibana

### Development Logging

- Console output with debug level
- File-based logging for persistence
- Direct container log access

## 🔒 Security Features

### Container Security

- Non-root user execution
- Read-only root filesystem
- Dropped capabilities
- Security options enabled
- No new privileges

### Network Security

- Isolated Docker networks
- Service-to-service communication only
- Exposed ports minimized
- Rate limiting configured

### Application Security

- HTTPS enforcement
- Security headers
- CORS configuration
- Request validation
- Input sanitization

## 🛠️ Development Workflow

### Hot Reload Development

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f mcp-ballerina-dev

# Run tests
docker exec -it mcp-test-runner bal test

# Debug application
# Connect debugger to localhost:5005
```

### Database Management

```bash
# Connect to development database
docker exec -it mcp-postgres-dev psql -U dev_user -d mcp_ballerina_dev

# Run migrations
docker exec -it mcp-ballerina-dev bal run migrations.bal
```

## 📈 Performance Optimization

### Production Optimizations

- Multi-stage Docker builds
- Layer caching
- Resource limits and reservations
- Connection pooling
- Cache configuration
- Gzip compression

### Development Optimizations

- Volume caching
- Minimal service stack
- Fast rebuild times
- Debug port exposure

## 🚨 Troubleshooting

### Common Issues

1. **Port conflicts**
   ```bash
   # Check port usage
   netstat -tulpn | grep :8080
   # Modify docker-compose ports if needed
   ```

2. **SSL certificate issues**
   ```bash
   # Regenerate certificates
   ./scripts/deploy.sh --cleanup
   ./scripts/deploy.sh production
   ```

3. **Database connection issues**
   ```bash
   # Check database logs
   docker-compose logs postgres-dev
   # Reset database
   docker-compose down -v && docker-compose up -d
   ```

### Health Checks

```bash
# Application health
curl http://localhost:8080/health

# Prometheus metrics
curl http://localhost:9091/metrics

# Service status
./scripts/deploy.sh --status
```

## 📋 Deployment Checklist

### Pre-deployment

- [ ] Update application version
- [ ] Run tests locally
- [ ] Check resource requirements
- [ ] Verify SSL certificates
- [ ] Review configuration changes

### Deployment

- [ ] Deploy to staging first
- [ ] Run health checks
- [ ] Verify monitoring
- [ ] Check log aggregation
- [ ] Test API endpoints

### Post-deployment

- [ ] Monitor metrics
- [ ] Check error rates
- [ ] Verify performance
- [ ] Update documentation
- [ ] Notify stakeholders

## 🔄 Backup and Recovery

### Database Backups

```bash
# Backup production data
docker exec mcp-postgres pg_dump -U user -d mcp_ballerina > backup.sql

# Restore from backup
docker exec -i mcp-postgres psql -U user -d mcp_ballerina < backup.sql
```

### Configuration Backups

```bash
# Backup configurations
tar -czf config-backup-$(date +%Y%m%d).tar.gz config/ monitoring/ nginx/
```

## 📞 Support

For issues and questions:
- Check logs: `docker-compose logs [service-name]`
- Health check: `./scripts/deploy.sh --health`
- Monitoring: Check Grafana dashboards
- Documentation: See project README

## 🔄 Updates

To update the deployment:

1. Pull latest code
2. Build new images
3. Deploy with zero-downtime strategy
4. Verify functionality
5. Monitor post-deployment

```bash
# Update deployment
git pull origin main
./scripts/deploy.sh production true false
```