#!/bin/bash

##############################################################################
# EKS Master Diagnostic & Fix Tool
# Purpose: Unified tool to diagnose and fix EKS cluster, connectivity, and app issues
# Author: Automated DevOps Script
# Date: 2025-11-26
##############################################################################

set -e
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="eks-master-fix-$(date +%Y%m%d-%H%M%S).log"

print_header() {
    echo -e "${BLUE}==========================================" | tee -a "$LOG_FILE"
    echo -e "$1" | tee -a "$LOG_FILE"
    echo -e "==========================================${NC}" | tee -a "$LOG_FILE"
}

print_info() { echo -e "${CYAN}ℹ $1${NC}" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"; }

# Determine script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##############################################################################
# Module 1: Connectivity Check
##############################################################################
check_connectivity() {
    print_header "1. Checking Cluster Connectivity"
    
    if kubectl cluster-info &>/dev/null; then
        print_success "Connected to cluster"
        return 0
    else
        print_error "Cannot connect to cluster"
        print_info "Running connectivity fix..."
        
        if [ -f "$SCRIPT_DIR/fix-eks-cluster.sh" ]; then
            "$SCRIPT_DIR/fix-eks-cluster.sh"
        else
            print_error "fix-eks-cluster.sh not found in $SCRIPT_DIR"
        fi
        
        # Re-check
        if kubectl cluster-info &>/dev/null; then
            print_success "Connectivity restored"
            return 0
        else
            print_error "Still cannot connect. Please fix connectivity first."
            return 1
        fi
    fi
}

##############################################################################
# Module 2: Pending Pods Diagnosis
##############################################################################
diagnose_pending_pods() {
    print_header "2. Diagnosing Pending Pods"
    
    PENDING_COUNT=$(kubectl get pods -A --no-headers 2>/dev/null | grep Pending | wc -l)
    
    if [ "$PENDING_COUNT" -eq 0 ]; then
        print_success "No pending pods found"
        return 0
    fi
    
    print_warning "Found $PENDING_COUNT pending pods"
    
    # Get list of pending pods
    kubectl get pods -A | grep Pending | tee -a "$LOG_FILE"
    
    print_info "Analyzing causes..."
    
    # Check Nodes
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    print_info "Node count: $NODE_COUNT"
    
    # Check Resources
    if kubectl top nodes &>/dev/null; then
        print_info "Node Usage:"
        kubectl top nodes | tee -a "$LOG_FILE"
    fi
    
    # Analyze first pending pod
    POD_NAME=$(kubectl get pods -A --no-headers | grep Pending | head -1 | awk '{print $2}')
    NAMESPACE=$(kubectl get pods -A --no-headers | grep Pending | head -1 | awk '{print $1}')
    
    if [ -n "$POD_NAME" ]; then
        print_info "Analyzing pod: $POD_NAME"
        EVENTS=$(kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -A 10 Events)
        echo "$EVENTS" | tee -a "$LOG_FILE"
        
        if echo "$EVENTS" | grep -q "Insufficient cpu"; then
            print_error "Cause: Insufficient CPU"
            print_info "Recommendation: Scale up nodes or use larger instance types"
        elif echo "$EVENTS" | grep -q "Insufficient memory"; then
            print_error "Cause: Insufficient Memory"
            print_info "Recommendation: Scale up nodes or use larger instance types"
        elif echo "$EVENTS" | grep -q "no nodes available"; then
            print_error "Cause: No nodes available"
            print_info "Recommendation: Check node groups in Terraform"
        fi
    fi
}

##############################################################################
# Module 3: Config Server Check
##############################################################################
check_config_server() {
    print_header "3. Checking Config Server"
    
    if kubectl get deployment config-server &>/dev/null; then
        READY=$(kubectl get deployment config-server -o jsonpath='{.status.readyReplicas}')
        if [ "$READY" == "1" ] || [ "$READY" == "2" ]; then
            print_success "Config Server is running"
        else
            print_error "Config Server is NOT ready"
            print_info "Running fix script..."
            
            if [ -f "$SCRIPT_DIR/fix-config-server.sh" ]; then
                "$SCRIPT_DIR/fix-config-server.sh"
            else
                print_error "fix-config-server.sh not found in $SCRIPT_DIR"
            fi
        fi
    else
        print_warning "Config Server deployment not found"
        print_info "Running fix script to deploy..."
        if [ -f "$SCRIPT_DIR/fix-config-server.sh" ]; then
            "$SCRIPT_DIR/fix-config-server.sh"
        fi
    fi
}

##############################################################################
# Module 4: General Health Check
##############################################################################
run_health_check() {
    print_header "4. Running General Health Check"
    
    # Try to find health check script in various locations
    if [ -f "$SCRIPT_DIR/eks-health-check.sh" ]; then
        "$SCRIPT_DIR/eks-health-check.sh"
    elif [ -f "$SCRIPT_DIR/../../EKS/eks-health-check.sh" ]; then
        "$SCRIPT_DIR/../../EKS/eks-health-check.sh"
    else
        print_error "eks-health-check.sh not found!"
    fi
}

##############################################################################
# Main Menu
##############################################################################
main() {
    print_header "EKS Master Diagnostic Tool"
    echo "Log file: $LOG_FILE"
    
    # 1. Check Connectivity first
    if ! check_connectivity; then
        exit 1
    fi
    
    # 2. Check Config Server (Critical dependency)
    check_config_server
    
    # 3. Diagnose Pending Pods
    diagnose_pending_pods
    
    # 4. Run full health check
    echo ""
    read -p "Run full cluster health check? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_health_check
    fi
    
    print_header "Diagnosis Complete"
    print_info "If issues persist, check the log file: $LOG_FILE"
}

# Make scripts executable
chmod +x ./kubernetes/scripts/fix-eks-cluster.sh 2>/dev/null || true
chmod +x ./kubernetes/scripts/fix-config-server.sh 2>/dev/null || true
chmod +x ./EKS/eks-health-check.sh 2>/dev/null || true

# Run main
main
