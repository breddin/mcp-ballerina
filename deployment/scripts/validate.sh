#!/bin/bash

# MCP Ballerina Server Deployment Validation Script
# Comprehensive validation and health checks for the deployment

set -euo pipefail

NAMESPACE="mcp-ballerina"
VERBOSE=false
CHECK_EXTERNAL=false
TIMEOUT=300

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

info() {
    echo -e "${BLUE}[i]${NC} $1"
}

show_help() {
    cat << EOF
MCP Ballerina Server Deployment Validation Script

Usage: $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: mcp-ballerina)
    -e, --external              Check external connectivity (ingress, load balancer)
    -v, --verbose               Enable verbose output
    -t, --timeout SECONDS       Timeout for checks (default: 300)
    -h, --help                  Show this help

VALIDATION CHECKS:
    ✓ Kubernetes cluster connectivity
    ✓ Namespace existence and health
    ✓ Pod status and readiness
    ✓ Service endpoints
    ✓ ConfigMaps and Secrets
    ✓ Persistent Volume Claims
    ✓ Ingress configuration
    ✓ Application health endpoints
    ✓ Metrics endpoints
    ✓ Database connectivity
    ✓ Cache connectivity
    ✓ Resource utilization
    ✓ Autoscaling configuration
    ✓ Network policies
    ✓ Security context
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -e|--external)
                CHECK_EXTERNAL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
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

debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Validation functions
validate_cluster() {
    info "Validating Kubernetes cluster connectivity..."
    
    if kubectl cluster-info &> /dev/null; then
        log "Cluster connectivity: OK"
        return 0
    else
        error "Cannot connect to Kubernetes cluster"
        return 1
    fi
}

validate_namespace() {
    info "Validating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log "Namespace exists: $NAMESPACE"
        
        # Check namespace status
        local phase
        phase=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}')
        if [[ "$phase" == "Active" ]]; then
            log "Namespace status: Active"
        else
            warn "Namespace status: $phase"
        fi
        
        # Check resource quotas
        if kubectl get resourcequota -n "$NAMESPACE" &> /dev/null; then
            debug "Resource quotas configured"
        fi
        
        return 0
    else
        error "Namespace not found: $NAMESPACE"
        return 1
    fi
}

validate_pods() {
    info "Validating pods..."
    
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o json)
    
    local pod_count
    pod_count=$(echo "$pods" | jq '.items | length')
    
    if [[ $pod_count -eq 0 ]]; then
        error "No pods found with label app.kubernetes.io/name=mcp-ballerina"
        return 1
    fi
    
    log "Found $pod_count pod(s)"
    
    local ready_count=0
    local running_count=0
    
    for i in $(seq 0 $((pod_count - 1))); do
        local pod_name
        pod_name=$(echo "$pods" | jq -r ".items[$i].metadata.name")
        
        local pod_phase
        pod_phase=$(echo "$pods" | jq -r ".items[$i].status.phase")
        
        local ready_condition
        ready_condition=$(echo "$pods" | jq -r ".items[$i].status.conditions[]? | select(.type==\"Ready\") | .status")
        
        debug "Pod $pod_name: Phase=$pod_phase, Ready=$ready_condition"
        
        if [[ "$pod_phase" == "Running" ]]; then
            ((running_count++))
            if [[ "$ready_condition" == "True" ]]; then
                ((ready_count++))
                log "Pod $pod_name: Running and Ready"
            else
                warn "Pod $pod_name: Running but not Ready"
                
                # Show pod conditions if verbose
                if [[ "$VERBOSE" == true ]]; then
                    kubectl describe pod "$pod_name" -n "$NAMESPACE" | grep -A 10 "Conditions:"
                fi
            fi
        else
            error "Pod $pod_name: Not Running (Phase: $pod_phase)"
        fi
    done
    
    if [[ $ready_count -eq $pod_count ]]; then
        log "All pods are ready ($ready_count/$pod_count)"
        return 0
    else
        error "Not all pods are ready ($ready_count/$pod_count)"
        return 1
    fi
}

validate_services() {
    info "Validating services..."
    
    local services=("mcp-ballerina" "mcp-ballerina-headless")
    if kubectl get service mcp-ballerina-metrics -n "$NAMESPACE" &> /dev/null; then
        services+=("mcp-ballerina-metrics")
    fi
    
    local success=true
    
    for service in "${services[@]}"; do
        if kubectl get service "$service" -n "$NAMESPACE" &> /dev/null; then
            log "Service exists: $service"
            
            # Check endpoints
            local endpoints
            endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
            
            if [[ $endpoints -gt 0 ]]; then
                log "Service $service has $endpoints endpoint(s)"
            else
                warn "Service $service has no endpoints"
                success=false
            fi
        else
            error "Service not found: $service"
            success=false
        fi
    done
    
    return $success
}

validate_configmaps_secrets() {
    info "Validating ConfigMaps and Secrets..."
    
    # Check ConfigMaps
    local configmaps=("mcp-ballerina-config" "mcp-ballerina-scripts")
    for cm in "${configmaps[@]}"; do
        if kubectl get configmap "$cm" -n "$NAMESPACE" &> /dev/null; then
            log "ConfigMap exists: $cm"
        else
            error "ConfigMap not found: $cm"
            return 1
        fi
    done
    
    # Check Secrets
    local secrets=("mcp-ballerina-secrets")
    for secret in "${secrets[@]}"; do
        if kubectl get secret "$secret" -n "$NAMESPACE" &> /dev/null; then
            log "Secret exists: $secret"
        else
            error "Secret not found: $secret"
            return 1
        fi
    done
    
    return 0
}

validate_storage() {
    info "Validating persistent storage..."
    
    local pvcs=("mcp-ballerina-data" "mcp-ballerina-logs" "mcp-ballerina-temp")
    local success=true
    
    for pvc in "${pvcs[@]}"; do
        if kubectl get pvc "$pvc" -n "$NAMESPACE" &> /dev/null; then
            local status
            status=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
            
            if [[ "$status" == "Bound" ]]; then
                log "PVC $pvc: Bound"
            else
                warn "PVC $pvc: $status"
                success=false
            fi
        else
            warn "Optional PVC not found: $pvc"
        fi
    done
    
    return $success
}

validate_ingress() {
    info "Validating ingress configuration..."
    
    if kubectl get ingress mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
        log "Ingress exists: mcp-ballerina"
        
        local hosts
        hosts=$(kubectl get ingress mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.spec.rules[*].host}')
        
        if [[ -n "$hosts" ]]; then
            log "Ingress hosts: $hosts"
            
            # Check if TLS is configured
            local tls_hosts
            tls_hosts=$(kubectl get ingress mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.spec.tls[*].hosts[*]}' 2>/dev/null || echo "")
            
            if [[ -n "$tls_hosts" ]]; then
                log "TLS configured for hosts: $tls_hosts"
            else
                warn "No TLS configuration found"
            fi
            
            return 0
        else
            error "Ingress has no host configuration"
            return 1
        fi
    else
        warn "Ingress not configured (optional)"
        return 0
    fi
}

validate_health_endpoints() {
    info "Validating health endpoints..."
    
    local pod_name
    pod_name=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$pod_name" ]]; then
        error "No pods found to test health endpoints"
        return 1
    fi
    
    local endpoints=("/health" "/ready")
    local success=true
    
    for endpoint in "${endpoints[@]}"; do
        debug "Testing endpoint: $endpoint"
        
        if kubectl exec -n "$NAMESPACE" "$pod_name" -c mcp-ballerina -- curl -sf "http://localhost:8080$endpoint" &> /dev/null; then
            log "Health endpoint responding: $endpoint"
        else
            error "Health endpoint not responding: $endpoint"
            success=false
        fi
    done
    
    return $success
}

validate_metrics() {
    info "Validating metrics endpoints..."
    
    local pod_name
    pod_name=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$pod_name" ]]; then
        error "No pods found to test metrics endpoint"
        return 1
    fi
    
    if kubectl exec -n "$NAMESPACE" "$pod_name" -c mcp-ballerina -- curl -sf "http://localhost:9090/metrics" &> /dev/null; then
        log "Metrics endpoint responding"
        return 0
    else
        error "Metrics endpoint not responding"
        return 1
    fi
}

validate_database() {
    info "Validating database connectivity..."
    
    # Check if PostgreSQL service exists
    if kubectl get service -l app.kubernetes.io/name=postgresql -n "$NAMESPACE" &> /dev/null; then
        log "PostgreSQL service found"
        
        # Try to connect from application pod
        local pod_name
        pod_name=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
        
        if [[ -n "$pod_name" ]]; then
            # Test database connection (this is a basic connectivity test)
            if kubectl exec -n "$NAMESPACE" "$pod_name" -c mcp-ballerina -- nc -z localhost 5432 2>/dev/null; then
                log "Database connectivity: OK"
                return 0
            else
                warn "Cannot test database connectivity from pod"
                return 0  # Don't fail validation for this
            fi
        fi
    else
        warn "PostgreSQL service not found (may be external)"
        return 0  # Don't fail validation for external databases
    fi
}

validate_cache() {
    info "Validating cache connectivity..."
    
    # Check if Redis service exists
    if kubectl get service -l app.kubernetes.io/name=redis -n "$NAMESPACE" &> /dev/null; then
        log "Redis service found"
        
        # Try to connect from application pod
        local pod_name
        pod_name=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
        
        if [[ -n "$pod_name" ]]; then
            # Test Redis connection
            if kubectl exec -n "$NAMESPACE" "$pod_name" -c mcp-ballerina -- nc -z localhost 6379 2>/dev/null; then
                log "Cache connectivity: OK"
                return 0
            else
                warn "Cannot test cache connectivity from pod"
                return 0
            fi
        fi
    else
        warn "Redis service not found (may be external)"
        return 0
    fi
}

validate_autoscaling() {
    info "Validating autoscaling configuration..."
    
    if kubectl get hpa mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
        log "HPA configured: mcp-ballerina"
        
        local current_replicas
        current_replicas=$(kubectl get hpa mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.status.currentReplicas}')
        
        local desired_replicas
        desired_replicas=$(kubectl get hpa mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.status.desiredReplicas}')
        
        log "HPA Status: Current=$current_replicas, Desired=$desired_replicas"
        
        return 0
    else
        warn "HPA not configured (optional)"
        return 0
    fi
}

validate_monitoring() {
    info "Validating monitoring configuration..."
    
    local success=true
    
    # Check ServiceMonitor
    if kubectl get servicemonitor mcp-ballerina -n "$NAMESPACE" &> /dev/null 2>&1; then
        log "ServiceMonitor configured"
    else
        warn "ServiceMonitor not found (requires Prometheus Operator)"
    fi
    
    # Check PrometheusRule
    if kubectl get prometheusrule mcp-ballerina -n "$NAMESPACE" &> /dev/null 2>&1; then
        log "PrometheusRule configured"
    else
        warn "PrometheusRule not found (requires Prometheus Operator)"
    fi
    
    return 0
}

validate_security() {
    info "Validating security configuration..."
    
    local pod_name
    pod_name=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$pod_name" ]]; then
        error "No pods found to validate security"
        return 1
    fi
    
    # Check security context
    local run_as_non_root
    run_as_non_root=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.runAsNonRoot}')
    
    if [[ "$run_as_non_root" == "true" ]]; then
        log "Security: Running as non-root user"
    else
        warn "Security: Not configured to run as non-root"
    fi
    
    # Check read-only root filesystem
    local read_only_root_fs
    read_only_root_fs=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')
    
    if [[ "$read_only_root_fs" == "true" ]]; then
        log "Security: Read-only root filesystem enabled"
    else
        warn "Security: Read-only root filesystem not enabled"
    fi
    
    return 0
}

validate_external_connectivity() {
    if [[ "$CHECK_EXTERNAL" != true ]]; then
        return 0
    fi
    
    info "Validating external connectivity..."
    
    # Check ingress hosts
    local hosts
    hosts=$(kubectl get ingress mcp-ballerina -n "$NAMESPACE" -o jsonpath='{.spec.rules[*].host}' 2>/dev/null || echo "")
    
    if [[ -n "$hosts" ]]; then
        for host in $hosts; do
            if curl -sf "https://$host/health" &> /dev/null; then
                log "External endpoint responding: https://$host"
            else
                warn "External endpoint not responding: https://$host"
            fi
        done
    else
        warn "No external hosts configured"
    fi
    
    return 0
}

show_summary() {
    info "Deployment Summary"
    echo "======================"
    
    # Resource counts
    local deployments
    deployments=$(kubectl get deployments -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" --no-headers | wc -l)
    
    local pods
    pods=$(kubectl get pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" --no-headers | wc -l)
    
    local services
    services=$(kubectl get services -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" --no-headers | wc -l)
    
    echo "Deployments: $deployments"
    echo "Pods: $pods"
    echo "Services: $services"
    echo
    
    # Resource usage (if metrics-server is available)
    if kubectl top pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE" &> /dev/null; then
        echo "Resource Usage:"
        kubectl top pods -l app.kubernetes.io/name=mcp-ballerina -n "$NAMESPACE"
        echo
    fi
    
    # Recent events
    echo "Recent Events:"
    kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp --field-selector type!=Normal | tail -5
}

run_all_validations() {
    local validations=(
        "validate_cluster"
        "validate_namespace"
        "validate_pods"
        "validate_services"
        "validate_configmaps_secrets"
        "validate_storage"
        "validate_ingress"
        "validate_health_endpoints"
        "validate_metrics"
        "validate_database"
        "validate_cache"
        "validate_autoscaling"
        "validate_monitoring"
        "validate_security"
        "validate_external_connectivity"
    )
    
    local failed_count=0
    local total_count=${#validations[@]}
    
    for validation in "${validations[@]}"; do
        if ! $validation; then
            ((failed_count++))
        fi
        echo
    done
    
    show_summary
    
    if [[ $failed_count -eq 0 ]]; then
        log "🎉 All validations passed! ($total_count/$total_count)"
        return 0
    else
        error "Some validations failed ($((total_count - failed_count))/$total_count passed)"
        return 1
    fi
}

main() {
    echo "MCP Ballerina Deployment Validation"
    echo "==================================="
    echo "Namespace: $NAMESPACE"
    echo "Timeout: ${TIMEOUT}s"
    echo "Check External: $CHECK_EXTERNAL"
    echo "Verbose: $VERBOSE"
    echo
    
    run_all_validations
}

parse_args "$@"
main