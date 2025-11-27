#!/bin/bash

# EKS Pending Pods Diagnosis & Fix Script
# Diagnoses why pods are pending and offers EKS-specific fixes

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

# 1. Check for Pending Pods
print_header "1. Checking for Pending Pods"
PENDING_COUNT=$(kubectl get pods -A --no-headers | grep Pending | wc -l)

if [ "$PENDING_COUNT" -eq 0 ]; then
    print_success "No pending pods found! Cluster looks healthy."
    exit 0
else
    print_warning "Found $PENDING_COUNT pending pods:"
    kubectl get pods -A | grep Pending
fi

# 2. Analyze a Pending Pod
print_header "2. Analyzing Pending Pod Reason"
POD_NAME=$(kubectl get pods -A --no-headers | grep Pending | head -1 | awk '{print $2}')
NAMESPACE=$(kubectl get pods -A --no-headers | grep Pending | head -1 | awk '{print $1}')

if [ -n "$POD_NAME" ]; then
    print_info "Analyzing pod: $POD_NAME (Namespace: $NAMESPACE)"
    REASON=$(kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -A 5 "Events:" | grep "FailedScheduling")
    
    echo "$REASON"
    
    if echo "$REASON" | grep -q "Insufficient cpu"; then
        ISSUE="CPU"
    elif echo "$REASON" | grep -q "Insufficient memory"; then
        ISSUE="MEMORY"
    elif echo "$REASON" | grep -q "no nodes available"; then
        ISSUE="NODES"
    else
        ISSUE="UNKNOWN"
    fi
fi

# 3. Check Node Capacity
print_header "3. Checking Node Capacity"
kubectl top nodes 2>/dev/null || print_warning "Metrics server not available (cannot show current usage)"
echo ""
kubectl describe nodes | grep -E "Allocated resources|Name:|cpu |memory " | grep -v "System"

# 4. Provide EKS Fixes
print_header "4. Recommended EKS Fixes"

case $ISSUE in
    "CPU")
        print_error "Issue: Insufficient CPU"
        print_info "Fix Options:"
        echo "  1. Scale up node group (add more nodes)"
        echo "     eksctl scale nodegroup --cluster spring-petclinic-eks --name petclinic-worker-primary --nodes <N+1>"
        echo "  2. Use larger instance types (e.g., t3.xlarge)"
        echo "     (Requires creating new node group in Terraform)"
        echo "  3. Reduce CPU requests in deployment.yaml"
        ;;
    "MEMORY")
        print_error "Issue: Insufficient Memory"
        print_info "Fix Options:"
        echo "  1. Scale up node group (add more nodes)"
        echo "     eksctl scale nodegroup --cluster spring-petclinic-eks --name petclinic-worker-primary --nodes <N+1>"
        echo "  2. Use memory-optimized instances (e.g., r5.large)"
        echo "  3. Reduce Memory requests in deployment.yaml"
        ;;
    "NODES")
        print_error "Issue: No Nodes Available"
        print_info "Fix Options:"
        echo "  1. Check if nodes are Ready:"
        echo "     kubectl get nodes"
        echo "  2. Check AWS Auto Scaling Group for errors"
        echo "  3. Check if you hit AWS vCPU limits"
        ;;
    *)
        print_warning "Issue: Unknown or Complex"
        print_info "  • Check pod events: kubectl describe pod $POD_NAME -n $NAMESPACE"
        print_info "  • Check node taints: kubectl describe node <node-name> | grep Taints"
        ;;
esac

# 5. Interactive Fix Menu
print_header "5. Interactive Fix Menu"
echo "1) Scale up node group (via eksctl)"
echo "2) Check AWS vCPU limits"
echo "3) View full pod description"
echo "4) Exit"
echo ""

read -p "Select an option: " CHOICE

case $CHOICE in
    1)
        read -p "Enter node group name (default: petclinic-worker-primary): " NG_NAME
        NG_NAME=${NG_NAME:-petclinic-worker-primary}
        read -p "Enter desired node count: " COUNT
        print_info "Scaling $NG_NAME to $COUNT nodes..."
        eksctl scale nodegroup --cluster spring-petclinic-eks --name "$NG_NAME" --nodes "$COUNT"
        ;;
    2)
        aws service-quotas list-service-quotas --service-code ec2 --query 'Quotas[?QuotaName==`Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances`]'
        ;;
    3)
        kubectl describe pod "$POD_NAME" -n "$NAMESPACE"
        ;;
    *)
        echo "Exiting."
        ;;
esac
