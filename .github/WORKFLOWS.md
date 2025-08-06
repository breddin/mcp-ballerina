# GitHub Actions Workflows

This document describes the GitHub Actions CI/CD workflows for the MCP Ballerina server project.

## 🚀 Workflow Overview

### Core Workflows

| Workflow | Trigger | Purpose | Status Badge |
|----------|---------|---------|--------------|
| **CI** | Push/PR | Build, test, security | ![CI](https://github.com/org/mcp-ballerina/workflows/Continuous%20Integration/badge.svg) |
| **Release** | Tags | Automated releases | ![Release](https://github.com/org/mcp-ballerina/workflows/Release/badge.svg) |
| **Quality** | Push/PR/Schedule | Code quality checks | ![Quality](https://github.com/org/mcp-ballerina/workflows/Code%20Quality/badge.svg) |
| **Docker** | Push/Tags | Container builds | ![Docker](https://github.com/org/mcp-ballerina/workflows/Docker%20Build%20and%20Push/badge.svg) |

### Automation Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Dependencies** | Schedule/Manual | Dependency updates |
| **CodeQL** | Push/PR/Schedule | Security analysis |
| **Stale** | Schedule | Issue/PR cleanup |

## 📋 Workflow Details

### 1. Continuous Integration (ci.yml)

**Triggers:**
- Push to `main`, `develop`
- Pull requests to `main`
- Changes to Ballerina files or workflows

**Jobs:**
- **Lint**: Code formatting checks
- **Build/Test**: Multi-matrix builds (Ballerina 2201.8.0, latest × 3 OS)
- **Security Scan**: Trivy vulnerability scanning
- **Dependency Check**: OWASP dependency analysis
- **Build Artifacts**: Create packages and Docker images
- **Integration Tests**: End-to-end testing
- **Notify**: Status notifications

**Features:**
- ✅ Multi-OS support (Ubuntu, macOS, Windows)
- ✅ Multiple Ballerina versions
- ✅ Code coverage reporting
- ✅ Security scanning with SARIF upload
- ✅ Caching for faster builds
- ✅ Artifact publishing

### 2. Release (release.yml)

**Triggers:**
- Git tags matching `v*.*.*`
- Manual workflow dispatch

**Jobs:**
- **Validate Release**: Version validation
- **Build Release**: Multi-platform artifacts
- **Build Docker**: Multi-arch container images
- **Generate Changelog**: Automated changelog
- **Create Release**: GitHub release creation
- **Publish Package**: Ballerina Central publishing
- **Notify**: Release notifications

**Features:**
- ✅ Semantic versioning validation
- ✅ Multi-platform builds (Linux, macOS, Windows)
- ✅ Docker multi-architecture support
- ✅ Automated changelog generation
- ✅ Container image signing
- ✅ Ballerina Central publishing

### 3. Code Quality (quality.yml)

**Triggers:**
- Push to `main`, `develop`
- Pull requests to `main`
- Daily schedule (2 AM UTC)

**Jobs:**
- **Code Quality**: Complexity analysis, code smells
- **License Scan**: License compliance
- **Documentation**: API docs validation
- **Performance**: Build time benchmarks
- **Security Analysis**: Advanced security checks
- **Quality Summary**: Comprehensive reporting

**Features:**
- ✅ Code complexity analysis
- ✅ License compliance checking
- ✅ Documentation coverage
- ✅ Performance benchmarking
- ✅ Security pattern detection
- ✅ PR quality comments

### 4. Docker Build (docker.yml)

**Triggers:**
- Push to `main`, `develop`
- Git tags
- Pull requests
- Manual dispatch

**Jobs:**
- **Build Docker**: Multi-platform builds
- **Security Scan**: Container security
- **Image Signing**: Cosign signing
- **Deployment Test**: Container testing
- **Multi-arch Manifest**: Registry manifest
- **Notify**: Build notifications

**Features:**
- ✅ Multi-architecture support (amd64, arm64)
- ✅ Optimized Dockerfile
- ✅ Security scanning (Trivy, Grype)
- ✅ Image signing with Cosign
- ✅ Deployment testing
- ✅ Registry caching

### 5. Dependencies (dependencies.yml)

**Triggers:**
- Weekly schedule (Mondays 9 AM UTC)
- Manual dispatch

**Jobs:**
- **Update Ballerina Dependencies**: Auto-update packages
- **Update GitHub Actions**: Keep workflows current
- **Security Audit**: Dependency vulnerability scanning
- **Dependency Review**: PR dependency analysis

**Features:**
- ✅ Automated dependency updates
- ✅ GitHub Actions version updates
- ✅ Security vulnerability detection
- ✅ Automated PR creation
- ✅ License compliance

### 6. CodeQL Analysis (codeql.yml)

**Triggers:**
- Push to `main`, `develop`
- Pull requests to `main`
- Daily schedule (6 AM UTC)

**Jobs:**
- **Analyze Code**: Static analysis
- **Upload Results**: SARIF reporting
- **Security Summary**: Analysis reporting

**Features:**
- ✅ Advanced static analysis
- ✅ Security vulnerability detection
- ✅ SARIF integration
- ✅ GitHub Security tab integration
- ✅ Automated issue creation

### 7. Stale Management (stale.yml)

**Triggers:**
- Daily schedule (midnight UTC)
- Manual dispatch

**Jobs:**
- **Mark Stale**: Identify inactive items
- **Cleanup Closed**: Remove stale labels
- **Statistics**: Generate reports

**Features:**
- ✅ Automated stale detection
- ✅ Configurable timeouts
- ✅ Label management
- ✅ Statistical reporting
- ✅ Exemption handling

## 🔧 Configuration

### Required Secrets

| Secret | Purpose | Required For |
|--------|---------|--------------|
| `GITHUB_TOKEN` | Repository access | All workflows (auto-provided) |
| `DOCKERHUB_USERNAME` | Docker Hub login | Docker publishing |
| `DOCKERHUB_TOKEN` | Docker Hub token | Docker publishing |
| `BALLERINA_CENTRAL_TOKEN` | Package publishing | Release workflow |

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `REGISTRY` | `ghcr.io` | Container registry |
| `IMAGE_NAME` | `${{ github.repository }}` | Container image name |

### Cache Configuration

All workflows use aggressive caching:
- Ballerina dependencies (`~/.ballerina/`)
- GitHub Actions cache
- Docker layer caching
- Maven/Gradle caches (if applicable)

## 🛠️ Customization

### Adding New Workflows

1. Create workflow file in `.github/workflows/`
2. Follow naming convention: `kebab-case.yml`
3. Include proper permissions
4. Add status badges to README
5. Document in this file

### Modifying Existing Workflows

1. Test changes in feature branch
2. Use workflow dispatch for testing
3. Monitor workflow runs
4. Update documentation

### Branch Protection Rules

Recommended branch protection for `main`:
- Require PR reviews (2 reviewers)
- Require status checks:
  - `lint`
  - `build-test`
  - `security-scan`
  - `quality-summary`
- Require up-to-date branches
- Include administrators

## 📊 Monitoring

### Workflow Status

Monitor workflows via:
- GitHub Actions tab
- Status badges in README
- Email notifications (configure in settings)
- Slack/Teams integration (if configured)

### Performance Metrics

Track workflow performance:
- Build times by OS/version
- Test execution times
- Cache hit rates
- Artifact sizes
- Security scan results

### Cost Optimization

- Use caching aggressively
- Limit matrix builds when appropriate
- Cancel redundant runs
- Use self-hosted runners for private repos
- Monitor Actions minutes usage

## 🚨 Troubleshooting

### Common Issues

**Build Failures:**
- Check Ballerina version compatibility
- Verify dependency availability
- Review cache corruption

**Security Scan Failures:**
- Review vulnerability reports
- Update vulnerable dependencies
- Add security exceptions if needed

**Docker Build Issues:**
- Check multi-architecture support
- Verify base image availability
- Review Dockerfile optimization

**Release Failures:**
- Validate semantic versioning
- Check required secrets
- Verify branch protection rules

### Debug Workflows

Enable debug logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## 📚 Best Practices

### Security
- Use pinned action versions
- Minimize secret usage
- Enable dependency review
- Regular security audits
- SARIF integration

### Performance
- Aggressive caching
- Parallel job execution
- Conditional job runs
- Artifact optimization
- Runner selection

### Maintainability
- Clear job names
- Comprehensive documentation
- Consistent patterns
- Error handling
- Status reporting

### Reliability
- Retry mechanisms
- Timeout configurations
- Fallback strategies
- Health checks
- Monitoring integration

## 🔄 Migration Guide

### From Other CI Systems

**Jenkins:**
- Convert Jenkinsfile to workflow YAML
- Map plugins to Actions
- Update secret management
- Migrate artifact handling

**GitLab CI:**
- Convert `.gitlab-ci.yml` to workflow YAML
- Map stages to jobs
- Update variable syntax
- Migrate cache configuration

**CircleCI:**
- Convert `.circleci/config.yml` to workflow YAML
- Map orbs to Actions
- Update executor configuration
- Migrate environment handling

## 📖 References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Ballerina CI/CD Guide](https://ballerina.io/learn/run-in-the-cloud/deploy-on-github-actions/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

*Last updated: $(date)*