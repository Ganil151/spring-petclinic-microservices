#!/bin/bash

# Validation script for Kubernetes deployment
# This script performs pre-deployment checks without modifying the cluster

set -e

DEPLOYMENT_FILE="${1:-../deployments/deployment.yaml}"
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m' # No Color

echo "=========================================="
echo "Kubernetes Deployment Validation"
echo "=========================================="
echo ""

# Function to print success
success() {
    echo -e "${COLOR_GREEN}✓${COLOR_NC} $1"
}

# Function to print error
error() {
    echo -e "${COLOR_RED}✗${COLOR_NC} $1"
}

# Function to print warning
warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_NC} $1"
}

# Check 1: File exists
echo "[1/8] Checking deployment file..."
if [ -f "$DEPLOYMENT_FILE" ]; then
    success "Deployment file found: $DEPLOYMENT_FILE"
else
    error "Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi
echo ""

# Check 2: YAML syntax validation (client-side)
echo "[2/8] Validating YAML syntax (client-side)..."
if kubectl apply -f "$DEPLOYMENT_FILE" --dry-run=client > /dev/null 2>&1; then
    success "YAML syntax is valid"
else
    error "YAML syntax validation failed"
    kubectl apply -f "$DEPLOYMENT_FILE" --dry-run=client
    exit 1
fi
echo ""

# Check 3: Server-side validation
echo "[3/8] Validating against API server (server-side)..."
if kubectl apply -f "$DEPLOYMENT_FILE" --dry-run=server > /dev/null 2>&1; then
    success "Server-side validation passed"
else
    error "Server-side validation failed"
    kubectl apply -f "$DEPLOYMENT_FILE" --dry-run=server
    exit 1
fi
echo ""

# Check 4: Node labels validation
echo "[4/8] Checking node labels..."
NODES_WITH_FRONTEND=$(kubectl get nodes -l node-role.kubernetes.io/frontend --no-headers 2>/dev/null | wc -l)
NODES_WITH_WORKER=$(kubectl get nodes -l node-role.kubernetes.io/worker --no-headers 2>/dev/null | wc -l)

if [ "$NODES_WITH_FRONTEND" -gt 0 ]; then
    success "Found $NODES_WITH_FRONTEND node(s) with 'frontend' label"
else
    warning "No nodes found with 'frontend' label - api-gateway and admin-server won't be scheduled"
fi

if [ "$NODES_WITH_WORKER" -gt 0 ]; then
    success "Found $NODES_WITH_WORKER node(s) with 'worker' label"
else
    warning "No nodes found with 'worker' label - backend services won't be scheduled"
fi
echo ""

# Check 5: Required secrets
echo "[5/8] Checking required secrets..."
if kubectl get secret genai-secrets > /dev/null 2>&1; then
    success "Secret 'genai-secrets' exists"
else
    warning "Secret 'genai-secrets' not found - genai-service may fail (this is optional)"
fi
echo ""

# Check 6: Cluster resources
echo "[6/8] Checking cluster resources..."
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -w "Ready" | wc -l)

if [ "$READY_NODES" -gt 0 ]; then
    success "$READY_NODES of $TOTAL_NODES nodes are Ready"
else
    error "No Ready nodes found in the cluster"
    exit 1
fi
echo ""

# Check 7: Namespace check
echo "[7/8] Checking namespaces..."
CURRENT_NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
if [ -z "$CURRENT_NAMESPACE" ]; then
    CURRENT_NAMESPACE="default"
fi
success "Current namespace: $CURRENT_NAMESPACE"
echo ""

# Check 8: Resource capacity estimate
echo "[8/8] Estimating resource requirements..."
echo "Resource requests from deployment:"
echo "  - Deployments: $(grep -c "kind: Deployment" "$DEPLOYMENT_FILE")"
echo "  - Services: $(grep -c "kind: Service" "$DEPLOYMENT_FILE")"

# Calculate total resource requests
TOTAL_CPU_REQUESTS=$(grep -A 5 "requests:" "$DEPLOYMENT_FILE" | grep "cpu:" | sed 's/[^0-9]//g' | awk '{s+=$1}END{print s}')
TOTAL_MEM_REQUESTS=$(grep -A 5 "requests:" "$DEPLOYMENT_FILE" | grep "memory:" | grep -o "[0-9]*" | awk '{s+=$1}END{print s}')

echo "  - Total CPU requests: ~${TOTAL_CPU_REQUESTS}m (millicores)"
echo "  - Total Memory requests: ~${TOTAL_MEM_REQUESTS}Mi"
success "Resource estimation complete"
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
success "All critical validations passed!"
echo ""
echo "You can now safely run:"
echo "  kubectl apply -f $DEPLOYMENT_FILE"
echo ""
echo "To monitor the deployment:"
echo "  kubectl get pods -w"
echo "  kubectl get deployments"
echo "  kubectl get services"
echo ""
