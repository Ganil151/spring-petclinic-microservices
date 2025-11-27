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

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check connectivity
print_header "Checking Cluster Connectivity"
if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    print_info "Run ./scripts/fix-eks-cluster.sh first"
    exit 1
fi
print_success "Connected to cluster"

# Check Deployment
print_header "Checking Config Server Deployment"
if kubectl get deployment config-server &>/dev/null; then
    print_success "Deployment 'config-server' exists"
    
    # Check Replicas
    REPLICAS=$(kubectl get deployment config-server -o jsonpath='{.spec.replicas}')
    READY=$(kubectl get deployment config-server -o jsonpath='{.status.readyReplicas}')
    
    # Handle empty ready replicas (if none are ready)
    if [ -z "$READY" ]; then READY=0; fi
    
    print_info "Replicas: $READY/$REPLICAS ready"
    
    if [ "$REPLICAS" -eq 0 ]; then
        print_warning "Deployment is scaled to 0"
        print_info "Scaling up..."
        kubectl scale deployment config-server --replicas=1
        print_success "Scaled to 1 replica"
    elif [ "$READY" -lt "$REPLICAS" ]; then
        print_warning "Pods are not ready"
        
        # Get the first pod name correctly
        POD_NAME=$(kubectl get pods -l app=config-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ -n "$POD_NAME" ]; then
            print_info "Checking logs for pod: $POD_NAME"
            
            # Capture logs to check for specific errors
            LOGS=$(kubectl logs "$POD_NAME" --tail=50 2>&1 || true)
            
            # Check for "unborn branch" error
            if echo "$LOGS" | grep -q "unborn branch"; then
                print_error "Detected 'unborn branch' error"
                print_info "This means the configured git branch (main) does not exist."
                print_info "Attempting to switch to 'master' branch..."
                
                # Patch the deployment to use 'master'
                kubectl set env deployment/config-server SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL=master
                print_success "Updated deployment to use 'master' branch"
                
                print_info "Waiting for rollout..."
                kubectl rollout status deployment/config-server --timeout=180s || true
            else
                print_info "Recent logs:"
                echo "$LOGS" | tail -10
                
                # Check for CrashLoopBackOff
                STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
                if [ "$STATUS" == "CrashLoopBackOff" ]; then
                    print_warning "Pod is in CrashLoopBackOff"
                    print_info "Restarting deployment..."
                    kubectl rollout restart deployment config-server
                fi
            fi
        else
            print_warning "No pods found for deployment"
        fi
    else
        print_success "Deployment looks healthy"
    fi
else
    print_warning "Deployment 'config-server' NOT found"
    print_info "Applying deployment manifest..."
    
    if [ -f "kubernetes/deployments/deployment.yaml" ]; then
        kubectl apply -f kubernetes/deployments/deployment.yaml
        print_success "Applied deployment.yaml"
    elif [ -f "kubernetes/deployments/config-server.yaml" ]; then
        kubectl apply -f kubernetes/deployments/config-server.yaml
        print_success "Applied config-server.yaml"
    else
        print_error "No deployment file found!"
        exit 1
    fi
fi

# Wait for rollout
print_header "Waiting for Config Server"
print_info "Waiting for pod to be ready (timeout 300s)..."
if kubectl wait --for=condition=ready pod -l app=config-server --timeout=300s; then
    print_success "Config Server is READY"
else
    print_error "Timed out waiting for Config Server"
    
    print_header "Diagnostics"
    POD_NAME=$(kubectl get pods -l app=config-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        print_info "Pod Status:"
        kubectl get pod "$POD_NAME"
        
        print_info "Pod Events:"
        kubectl describe pod "$POD_NAME" | grep -A 10 Events
        
        print_info "Recent Logs:"
        kubectl logs "$POD_NAME" --tail=20
    fi
fi
