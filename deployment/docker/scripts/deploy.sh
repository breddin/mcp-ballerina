#!/bin/bash
set -euo pipefail

# MCP Ballerina Server Deployment Script
# Usage: ./deploy.sh [environment] [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DEPLOYMENT_DIR="$SCRIPT_DIR/.."

# Default values
ENVIRONMENT="${1:-production}"
BUILD_FRESH="${2:-false}"
SKIP_TESTS="${3:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build application
build_application() {
    if [[ "$BUILD_FRESH" == "true" ]]; then
        log_info "Building application with fresh dependencies..."
        cd "$PROJECT_ROOT"
        
        if [[ "$SKIP_TESTS" != "true" ]]; then
            log_info "Running tests..."
            bal test || {
                log_error "Tests failed"
                exit 1
            }
        fi
        
        log_info "Building Ballerina application..."
        bal build || {
            log_error "Build failed"
            exit 1
        }
        
        log_success "Application built successfully"
    else
        log_info "Skipping fresh build (use 'true' as second argument to build)"
    fi
}

# Deploy based on environment
deploy() {
    cd "$DEPLOYMENT_DIR"
    
    case "$ENVIRONMENT" in
        "production"|"prod")
            log_info "Deploying to production environment..."
            
            # Create SSL certificates if they don't exist
            create_ssl_certificates
            
            # Pull latest images
            docker-compose pull
            
            # Deploy with production compose
            docker-compose -f docker-compose.yml up -d --remove-orphans
            ;;
            
        "development"|"dev")
            log_info "Deploying to development environment..."
            
            # Deploy with development compose
            docker-compose -f docker-compose.dev.yml up -d --remove-orphans
            ;;
            
        "staging")
            log_info "Deploying to staging environment..."
            
            # Use production compose but with staging tag
            docker-compose -f docker-compose.yml up -d --remove-orphans
            ;;
            
        *)
            log_error "Unknown environment: $ENVIRONMENT"
            log_info "Supported environments: production, development, staging"
            exit 1
            ;;
    esac
    
    log_success "Deployment started for $ENVIRONMENT environment"
}

# Create SSL certificates for development/testing
create_ssl_certificates() {
    SSL_DIR="$DEPLOYMENT_DIR/nginx/ssl"
    
    if [[ ! -f "$SSL_DIR/server.crt" ]] || [[ ! -f "$SSL_DIR/server.key" ]]; then
        log_info "Creating self-signed SSL certificates..."
        
        mkdir -p "$SSL_DIR"
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/server.key" \
            -out "$SSL_DIR/server.crt" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
            &> /dev/null || {
            log_warning "Failed to create SSL certificates. Using existing or default ones."
        }
        
        if [[ -f "$SSL_DIR/server.crt" ]]; then
            log_success "SSL certificates created"
        fi
    else
        log_info "SSL certificates already exist"
    fi
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s http://localhost:8080/health &> /dev/null; then
            log_success "Health check passed"
            return 0
        fi
        
        log_info "Health check attempt $attempt/$max_attempts failed, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Show status
show_status() {
    cd "$DEPLOYMENT_DIR"
    
    log_info "Container status:"
    if [[ "$ENVIRONMENT" == "development" ]] || [[ "$ENVIRONMENT" == "dev" ]]; then
        docker-compose -f docker-compose.dev.yml ps
    else
        docker-compose -f docker-compose.yml ps
    fi
    
    log_info "Service URLs:"
    echo "  MCP Server: http://localhost:8080"
    echo "  HTTPS: https://localhost:443"
    echo "  Prometheus: http://localhost:9091"
    echo "  Grafana: http://localhost:3000 (admin/admin123)"
    
    if [[ "$ENVIRONMENT" == "development" ]] || [[ "$ENVIRONMENT" == "dev" ]]; then
        echo "  Swagger UI: http://localhost:8081"
        echo "  PostgreSQL: localhost:5432"
    else
        echo "  Kibana: http://localhost:5601"
        echo "  Elasticsearch: http://localhost:9200"
    fi
}

# Cleanup
cleanup() {
    cd "$DEPLOYMENT_DIR"
    
    log_info "Stopping and removing containers..."
    
    if [[ "$ENVIRONMENT" == "development" ]] || [[ "$ENVIRONMENT" == "dev" ]]; then
        docker-compose -f docker-compose.dev.yml down -v --remove-orphans
    else
        docker-compose -f docker-compose.yml down -v --remove-orphans
    fi
    
    log_success "Cleanup completed"
}

# Show help
show_help() {
    echo "MCP Ballerina Server Deployment Script"
    echo ""
    echo "Usage: $0 [environment] [build_fresh] [skip_tests]"
    echo ""
    echo "Arguments:"
    echo "  environment   Target environment (production|development|staging) [default: production]"
    echo "  build_fresh   Build application from source (true|false) [default: false]"
    echo "  skip_tests    Skip running tests during build (true|false) [default: false]"
    echo ""
    echo "Commands:"
    echo "  $0 production true false    # Deploy to production with fresh build and tests"
    echo "  $0 development              # Deploy to development environment"
    echo "  $0 staging                  # Deploy to staging environment"
    echo ""
    echo "Additional options:"
    echo "  --status     Show current deployment status"
    echo "  --cleanup    Stop and remove all containers"
    echo "  --health     Perform health check"
    echo "  --help       Show this help message"
}

# Main execution
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--status")
            show_status
            exit 0
            ;;
        "--cleanup")
            cleanup
            exit 0
            ;;
        "--health")
            health_check
            exit $?
            ;;
        "")
            # Default deployment
            ;;
        *)
            # Environment specified
            ;;
    esac
    
    log_info "Starting MCP Ballerina Server deployment..."
    log_info "Environment: $ENVIRONMENT"
    log_info "Build fresh: $BUILD_FRESH"
    log_info "Skip tests: $SKIP_TESTS"
    
    check_prerequisites
    build_application
    deploy
    
    # Wait a moment for services to start
    sleep 10
    
    health_check || log_warning "Health check failed, but deployment may still be starting"
    show_status
    
    log_success "Deployment completed successfully!"
}

# Run main function
main "$@"