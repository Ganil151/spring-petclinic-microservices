#!/bin/bash

# Fix Config Server Script
# Diagnoses and fixes issues with the Spring Petclinic Config Server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GIT_URI="https://github.com/spring-petclinic/spring-petclinic-microservices-config"
GIT_LABEL="main"

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Check connectivity
print_header "Checking Cluster Connectivity"
if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_success "Connected to cluster"

# Check Deployment
print_header "Checking Config Server Deployment"
if kubectl get deployment config-server &>/dev/null; then
    print_success "Deployment 'config-server' exists"
    
    # Enforce Configuration
    print_info "Enforcing Git Configuration..."
    print_info "URI: $GIT_URI"
    print_info "Label: $GIT_LABEL"
    
    kubectl set env deployment/config-server \
        SPRING_CLOUD_CONFIG_SERVER_GIT_URI="$GIT_URI" \
        SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL="$GIT_LABEL"
    
    print_success "Configuration updated"
    
    # Check Replicas
    REPLICAS=$(kubectl get deployment config-server -o jsonpath='{.spec.replicas}')
    if [ "$REPLICAS" -eq 0 ]; then
        print_info "Scaling up..."
        kubectl scale deployment config-server --replicas=1
    fi
    
    # Restart to ensure fresh start
    print_info "Restarting deployment..."
    kubectl rollout restart deployment config-server
    
else
    print_warning "Deployment 'config-server' NOT found"
    print_info "Applying deployment manifest..."
    
    # Try to find the deployment file
    if [ -f "kubernetes/base/kustomization.yaml" ]; then
        kubectl apply -k kubernetes/base/
    elif [ -f "../../kubernetes/base/kustomization.yaml" ]; then
        kubectl apply -k ../../kubernetes/base/
    else
        print_error "No deployment file found!"
        exit 1
    fi
    
    # Patch it immediately after creating
    kubectl set env deployment/config-server \
        SPRING_CLOUD_CONFIG_SERVER_GIT_URI="$GIT_URI" \
        SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL="$GIT_LABEL"
fi

# Wait for rollout
print_header "Waiting for Config Server"
print_info "Waiting for pod to be ready (timeout 300s)..."

if kubectl rollout status deployment/config-server --timeout=300s; then
    print_success "Config Server is READY"
    
    # Verify health
    POD_NAME=$(kubectl get pods -l app=config-server -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$POD_NAME" ]; then
        print_info "Verifying health endpoint..."
        if kubectl exec "$POD_NAME" -- curl -s http://localhost:8888/actuator/health | grep -q "UP"; then
            print_success "Health check PASSED"
        else
            print_warning "Health check failed or pending"
        fi
    fi
else
    print_error "Timed out waiting for Config Server"
    
    print_header "Diagnostics"
    POD_NAME=$(kubectl get pods -l app=config-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        print_info "Pod Status:"
        kubectl get pod "$POD_NAME"
        
        print_info "Recent Logs:"
        kubectl logs "$POD_NAME" --tail=20
        
        print_info "Events:"
        kubectl describe pod "$POD_NAME" | grep -A 10 Events
    fi
fi
