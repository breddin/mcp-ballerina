#!/bin/bash

# MCP Ballerina Server Deployment Script
# This script provides a comprehensive deployment solution with multiple options

set -euo pipefail

# Default configuration
NAMESPACE="mcp-ballerina"
DEPLOYMENT_METHOD="helm"
ENVIRONMENT="production"
DRY_RUN=false
VERBOSE=false
HELM_CHART_DIR="./helm/mcp-ballerina"
KUSTOMIZE_DIR="./kubernetes"
VALUES_FILE=""
WAIT_TIMEOUT="600s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Help function
show_help() {
    cat << EOF
MCP Ballerina Server Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -m, --method METHOD          Deployment method: helm, kustomize, kubectl (default: helm)
    -n, --namespace NAMESPACE    Kubernetes namespace (default: mcp-ballerina)
    -e, --environment ENV        Environment: dev, staging, production (default: production)
    -f, --values-file FILE       Helm values file or Kustomize overlay
    -d, --dry-run               Perform a dry run without making changes
    -v, --verbose               Enable verbose output
    -w, --wait TIMEOUT          Wait timeout for deployment (default: 600s)
    -h, --help                  Show this help message

EXAMPLES:
    # Deploy using Helm with default values
    $0 --method helm

    # Deploy using Kustomize to staging environment
    $0 --method kustomize --environment staging --namespace mcp-ballerina-staging

    # Dry run deployment with custom values
    $0 --method helm --values-file custom-values.yaml --dry-run

    # Deploy with kubectl manifests
    $0 --method kubectl --verbose

ENVIRONMENTS:
    dev         - Development environment with reduced resources
    staging     - Staging environment with production-like setup
    production  - Production environment with full resources

METHODS:
    helm        - Deploy using Helm chart (recommended)
    kustomize   - Deploy using Kustomize
    kubectl     - Deploy using raw Kubernetes manifests
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--method)
                DEPLOYMENT_METHOD="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -f|--values-file)
                VALUES_FILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -w|--wait)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."

    # Check if running from correct directory
    if [[ ! -d "$HELM_CHART_DIR" && ! -d "$KUSTOMIZE_DIR" ]]; then
        error "Please run this script from the deployment directory"
        exit 1
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check method-specific tools
    case $DEPLOYMENT_METHOD in
        helm)
            if ! command -v helm &> /dev/null; then
                error "Helm is not installed or not in PATH"
                exit 1
            fi
            ;;
        kustomize)
            if ! command -v kustomize &> /dev/null && ! kubectl version --client -o json | jq -e '.clientVersion.major >= "1" and .clientVersion.minor >= "14"' &> /dev/null; then
                error "Kustomize is not available (install kustomize or use kubectl >= 1.14)"
                exit 1
            fi
            ;;
    esac

    # Check if namespace exists (if not using --create-namespace with helm)
    if [[ "$DEPLOYMENT_METHOD" != "helm" ]]; then
        if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
            warn "Namespace $NAMESPACE does not exist, will be created"
        fi
    fi

    log "Prerequisites validated successfully"
}

# Create namespace if it doesn't exist
ensure_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Creating namespace: $NAMESPACE"
        if [[ "$DRY_RUN" == false ]]; then
            kubectl create namespace "$NAMESPACE"
            kubectl label namespace "$NAMESPACE" environment="$ENVIRONMENT"
        fi
    else
        debug "Namespace $NAMESPACE already exists"
    fi
}

# Deploy using Helm
deploy_helm() {
    log "Deploying MCP Ballerina using Helm..."

    local helm_args=(
        "upgrade"
        "--install"
        "mcp-ballerina"
        "$HELM_CHART_DIR"
        "--namespace" "$NAMESPACE"
        "--create-namespace"
        "--wait"
        "--timeout" "$WAIT_TIMEOUT"
    )

    # Add environment-specific values
    if [[ -f "$HELM_CHART_DIR/values-$ENVIRONMENT.yaml" ]]; then
        helm_args+=(--values "$HELM_CHART_DIR/values-$ENVIRONMENT.yaml")
        debug "Using environment values file: values-$ENVIRONMENT.yaml"
    fi

    # Add custom values file if specified
    if [[ -n "$VALUES_FILE" ]]; then
        if [[ -f "$VALUES_FILE" ]]; then
            helm_args+=(--values "$VALUES_FILE")
            debug "Using custom values file: $VALUES_FILE"
        else
            error "Values file not found: $VALUES_FILE"
            exit 1
        fi
    fi

    # Add dry-run flag if specified
    if [[ "$DRY_RUN" == true ]]; then
        helm_args+=(--dry-run)
        log "Performing Helm dry run..."
    fi

    # Execute Helm command
    if [[ "$VERBOSE" == true ]]; then
        helm_args+=(--debug)
    fi

    debug "Helm command: helm ${helm_args[*]}"
    helm "${helm_args[@]}"

    if [[ "$DRY_RUN" == false ]]; then
        log "Helm deployment completed successfully"
        show_deployment_status
    fi
}

# Deploy using Kustomize
deploy_kustomize() {
    log "Deploying MCP Ballerina using Kustomize..."

    ensure_namespace

    local kustomize_dir="$KUSTOMIZE_DIR"
    
    # Check for environment-specific overlay
    if [[ -d "$KUSTOMIZE_DIR/overlays/$ENVIRONMENT" ]]; then
        kustomize_dir="$KUSTOMIZE_DIR/overlays/$ENVIRONMENT"
        debug "Using environment overlay: $kustomize_dir"
    elif [[ -n "$VALUES_FILE" && -d "$VALUES_FILE" ]]; then
        kustomize_dir="$VALUES_FILE"
        debug "Using custom overlay: $kustomize_dir"
    fi

    local kubectl_args=("apply" "-k" "$kustomize_dir")

    if [[ "$DRY_RUN" == true ]]; then
        kubectl_args+=(--dry-run=client -o yaml)
        log "Performing Kustomize dry run..."
    fi

    debug "Kustomize command: kubectl ${kubectl_args[*]}"
    kubectl "${kubectl_args[@]}"

    if [[ "$DRY_RUN" == false ]]; then
        log "Kustomize deployment completed successfully"
        wait_for_deployment
        show_deployment_status
    fi
}

# Deploy using raw Kubernetes manifests
deploy_kubectl() {
    log "Deploying MCP Ballerina using raw Kubernetes manifests..."

    ensure_namespace

    local manifest_files=(
        "$KUSTOMIZE_DIR/configmap.yaml"
        "$KUSTOMIZE_DIR/secret.yaml"
        "$KUSTOMIZE_DIR/pvc.yaml"
        "$KUSTOMIZE_DIR/rbac.yaml"
        "$KUSTOMIZE_DIR/deployment.yaml"
        "$KUSTOMIZE_DIR/service.yaml"
        "$KUSTOMIZE_DIR/ingress.yaml"
        "$KUSTOMIZE_DIR/hpa.yaml"
        "$KUSTOMIZE_DIR/servicemonitor.yaml"
    )

    local kubectl_args=("apply" "-f")

    if [[ "$DRY_RUN" == true ]]; then
        kubectl_args+=(--dry-run=client -o yaml)
        log "Performing kubectl dry run..."
    fi

    for manifest in "${manifest_files[@]}"; do
        if [[ -f "$manifest" ]]; then
            debug "Applying manifest: $manifest"
            kubectl "${kubectl_args[@]}" "$manifest" --namespace "$NAMESPACE"
        else
            warn "Manifest file not found: $manifest"
        fi
    done

    if [[ "$DRY_RUN" == false ]]; then
        log "Kubectl deployment completed successfully"
        wait_for_deployment
        show_deployment_status
    fi
}

# Wait for deployment to be ready
wait_for_deployment() {
    log "Waiting for deployment to be ready..."
    
    if ! kubectl rollout status deployment/mcp-ballerina \
         --namespace "$NAMESPACE" \
         --timeout "$WAIT_TIMEOUT"; then
        error "Deployment failed to become ready within $WAIT_TIMEOUT"
        show_deployment_logs
        exit 1
    fi
    
    log "Deployment is ready"
}

# Show deployment status
show_deployment_status() {
    log "Deployment Status:"
    echo "===================="
    
    # Show deployment info
    kubectl get deployment mcp-ballerina -n "$NAMESPACE" -o wide
    echo
    
    # Show pod status
    kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o wide
    echo
    
    # Show services
    kubectl get services -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o wide
    echo
    
    # Show ingress if available
    if kubectl get ingress mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
        kubectl get ingress mcp-ballerina -n "$NAMESPACE" -o wide
        echo
    fi
    
    # Show HPA status
    if kubectl get hpa mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
        kubectl get hpa mcp-ballerina -n "$NAMESPACE"
        echo
    fi
    
    # Show resource usage
    if kubectl top pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" &> /dev/null 2>&1; then
        echo "Resource Usage:"
        kubectl top pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE"
        echo
    fi
}

# Show deployment logs for troubleshooting
show_deployment_logs() {
    error "Showing recent logs for troubleshooting:"
    kubectl logs -l app.kubernetes.io/name=mcp-ballerina \
        --namespace "$NAMESPACE" \
        --tail=50 \
        --prefix=true \
        --timestamps || true
}

# Validate deployment
validate_deployment() {
    log "Validating deployment..."
    
    local validation_passed=true
    
    # Check if pods are running
    local running_pods
    running_pods=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" --field-selector=status.phase=Running -o name | wc -l)
    
    if [[ $running_pods -eq 0 ]]; then
        error "No running pods found"
        validation_passed=false
    else
        log "Found $running_pods running pod(s)"
    fi
    
    # Check service endpoints
    if kubectl get endpoints mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; then
        log "Service endpoints are available"
    else
        error "No service endpoints available"
        validation_passed=false
    fi
    
    # Test health endpoint (if service is accessible)
    if kubectl get service mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
        if kubectl exec -n "$NAMESPACE" deployment/mcp-ballerina -c mcp-ballerina -- curl -sf http://localhost:8080/health &> /dev/null; then
            log "Health endpoint is responding"
        else
            warn "Health endpoint is not responding (might still be starting up)"
        fi
    fi
    
    if [[ "$validation_passed" == true ]]; then
        log "Deployment validation passed"
        return 0
    else
        error "Deployment validation failed"
        return 1
    fi
}

# Main execution
main() {
    log "Starting MCP Ballerina deployment..."
    log "Method: $DEPLOYMENT_METHOD, Environment: $ENVIRONMENT, Namespace: $NAMESPACE"
    
    if [[ "$DRY_RUN" == true ]]; then
        warn "Dry run mode enabled - no changes will be made"
    fi
    
    validate_prerequisites
    
    case $DEPLOYMENT_METHOD in
        helm)
            deploy_helm
            ;;
        kustomize)
            deploy_kustomize
            ;;
        kubectl)
            deploy_kubectl
            ;;
        *)
            error "Unsupported deployment method: $DEPLOYMENT_METHOD"
            error "Supported methods: helm, kustomize, kubectl"
            exit 1
            ;;
    esac
    
    if [[ "$DRY_RUN" == false ]]; then
        if validate_deployment; then
            log "🎉 MCP Ballerina deployment completed successfully!"
            echo
            echo "Next steps:"
            echo "1. Check the application logs: kubectl logs -f deployment/mcp-ballerina -n $NAMESPACE"
            echo "2. Access the application: kubectl port-forward service/mcp-ballerina 8080:80 -n $NAMESPACE"
            echo "3. View metrics: kubectl port-forward service/mcp-ballerina-metrics 9090:9090 -n $NAMESPACE"
            if kubectl get ingress mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
                local ingress_host
                ingress_host=$(kubectl get ingress mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
                echo "4. Access via ingress: https://$ingress_host"
            fi
        else
            error "Deployment completed but validation failed. Please check the logs and try again."
            exit 1
        fi
    else
        log "Dry run completed successfully"
    fi
}

# Parse arguments and run
parse_args "$@"
main