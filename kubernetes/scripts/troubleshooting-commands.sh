#!/bin/bash
# Kubernetes Cluster Troubleshooting & Fix Script
# Run this on your K8s master node to diagnose and fix cluster issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
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

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ==========================================
# SECTION 1: HEALTH CHECK
# ==========================================

health_check() {
    print_header "SECTION 1: Kubernetes Cluster Health Check"
    echo ""

    print_info "1. Checking Node Status..."
    kubectl get nodes -o wide
    echo ""

    print_info "2. Checking Control Plane Pods..."
    kubectl get pods -n kube-system -l tier=control-plane
    echo ""

    print_info "3. Checking All System Pods..."
    kubectl get pods -n kube-system -o wide
    echo ""

    print_info "4. Checking Component Status..."
    kubectl get componentstatuses 2>/dev/null || echo "Note: componentstatuses deprecated in newer K8s versions"
    echo ""

    print_info "5. Checking API Server Health..."
    kubectl get --raw='/readyz?verbose' | head -20
    echo ""

    print_info "6. Checking Network Plugin (Calico)..."
    if kubectl get pods -n calico-system &>/dev/null; then
        kubectl get pods -n calico-system
        print_success "Calico is installed"
    else
        print_warning "Calico namespace not found - CNI may not be installed!"
    fi
    echo ""

    print_info "7. Checking CoreDNS..."
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
    echo ""

    print_info "8. Checking for Pending Pods..."
    PENDING=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    if [ "$PENDING" -gt 0 ]; then
        print_warning "Found $PENDING pending pods:"
        kubectl get pods --all-namespaces --field-selector=status.phase=Pending
    else
        print_success "No pending pods"
    fi
    echo ""

    print_info "9. Checking for Failed/Error Pods..."
    FAILED=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
    if [ "$FAILED" -gt 0 ]; then
        print_warning "Found $FAILED failed pods:"
        kubectl get pods --all-namespaces --field-selector=status.phase=Failed
    else
        print_success "No failed pods"
    fi
    echo ""

    print_info "10. Checking Recent Events..."
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
    echo ""

    print_header "Health Check Complete!"
}

# ==========================================
# SECTION 2: CNI INSTALLATION
# ==========================================

# ==========================================
# SECTION 2A: VERIFY CNI CONFIGURATION
# ==========================================

verify_cni_config() {
    print_header "Verifying CNI Configuration"
    echo ""
    
    print_info "Checking CNI configuration files..."
    if [ -d "/etc/cni/net.d" ]; then
        ls -la /etc/cni/net.d/
        echo ""
        
        # Check for conflicting CNI configs
        if ls /etc/cni/net.d/*.conflist &>/dev/null; then
            CNI_COUNT=$(ls /etc/cni/net.d/*.conflist 2>/dev/null | wc -l)
            if [ "$CNI_COUNT" -gt 1 ]; then
                print_warning "Multiple CNI configurations found! This can cause conflicts."
                ls /etc/cni/net.d/*.conflist
            else
                print_success "Single CNI configuration found"
            fi
        else
            print_warning "No CNI configuration files found in /etc/cni/net.d/"
        fi
    else
        print_error "/etc/cni/net.d directory does not exist!"
    fi
    echo ""
    
    print_info "Checking Calico/Tigera CRDs..."
    kubectl get crd | grep -E "calico|tigera" || print_info "No Calico/Tigera CRDs found"
    echo ""
    
    print_info "Checking Calico-related namespaces..."
    kubectl get ns | grep -E "calico|tigera" || print_info "No Calico/Tigera namespaces found"
    echo ""
}

# ==========================================
# SECTION 2B: COMPLETE CNI CLEANUP
# ==========================================

complete_cni_cleanup() {
    print_header "SECTION 2B: Complete CNI Cleanup (Calico/Flannel)"
    echo ""
    
    print_warning "This will completely remove Calico and Flannel from your cluster!"
    read -p "Are you sure you want to proceed? (yes/no) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cleanup cancelled"
        return
    fi
    
    print_info "Step 1: Deleting Calico/Tigera namespaces..."
    kubectl delete ns tigera-operator --ignore-not-found --timeout=30s &
    kubectl delete ns calico-system --ignore-not-found --timeout=30s &
    kubectl delete ns calico-apiserver --ignore-not-found --timeout=30s &
    kubectl delete ns kube-flannel --ignore-not-found --timeout=30s &
    wait
    echo ""
    
    print_info "Step 2: Force-deleting stuck namespaces if any..."
    for ns in tigera-operator calico-system calico-apiserver kube-flannel; do
        if kubectl get ns $ns &>/dev/null; then
            print_warning "Namespace $ns is stuck, force-deleting..."
            kubectl get ns $ns -o json | jq 'del(.spec.finalizers)' > /tmp/ns-$ns.json 2>/dev/null
            kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f /tmp/ns-$ns.json 2>/dev/null || true
            rm -f /tmp/ns-$ns.json
        fi
    done
    echo ""
    
    print_info "Step 3: Deleting Calico/Tigera CRDs..."
    kubectl get crd | grep -E "calico|tigera" | awk '{print $1}' | while read crd; do
        print_info "Deleting CRD: $crd"
        kubectl delete crd $crd --ignore-not-found --timeout=30s &
    done
    wait
    echo ""
    
    print_info "Step 4: Force-deleting stuck CRDs if any..."
    kubectl get crd | grep -E "calico|tigera" | awk '{print $1}' | while read crd; do
        print_warning "CRD $crd is stuck, force-deleting..."
        kubectl patch crd $crd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        kubectl delete crd $crd --ignore-not-found 2>/dev/null || true
    done
    echo ""
    
    print_info "Step 5: Cleaning CNI configuration files on ALL nodes..."
    print_warning "Note: This only cleans the current node. Run on worker nodes too!"
    sudo rm -f /etc/cni/net.d/10-calico.conflist
    sudo rm -f /etc/cni/net.d/10-flannel.conflist
    sudo rm -f /etc/cni/net.d/calico-kubeconfig
    sudo rm -f /etc/cni/net.d/calico-tls
    ls -la /etc/cni/net.d/ 2>/dev/null || print_info "CNI directory is now empty"
    echo ""
    
    print_info "Step 6: Deleting Calico/Flannel DaemonSets..."
    kubectl delete ds -n kube-system calico-node --ignore-not-found
    kubectl delete ds -n kube-system kube-flannel-ds --ignore-not-found
    echo ""
    
    print_info "Step 7: Waiting for cleanup to complete..."
    sleep 5
    echo ""
    
    print_success "CNI cleanup complete!"
    print_info "Verifying cleanup..."
    verify_cni_config
}

# ==========================================
# SECTION 2C: INSTALL CALICO (CLEAN)
# ==========================================

install_calico() {
    print_header "SECTION 2C: Installing Calico CNI"
    echo ""

    print_info "Pre-installation checks..."
    
    # Check for existing Calico
    if kubectl get namespace calico-system &>/dev/null; then
        print_error "Calico namespace already exists!"
        print_info "Run 'complete_cni_cleanup' first or use option to cleanup"
        return 1
    fi
    
    # Check for existing CRDs
    EXISTING_CRDS=$(kubectl get crd | grep -E "calico|tigera" | wc -l)
    if [ "$EXISTING_CRDS" -gt 0 ]; then
        print_warning "Found $EXISTING_CRDS existing Calico/Tigera CRDs"
        print_info "This might cause issues. Consider running complete_cni_cleanup first."
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Check for CNI config files
    if ls /etc/cni/net.d/*.conflist &>/dev/null; then
        print_warning "Existing CNI configuration files found:"
        ls /etc/cni/net.d/*.conflist
        print_info "These will be replaced by Calico"
    fi
    echo ""

    print_info "Installing Calico Operator (v3.27.2)..."
    if kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml; then
        print_success "Calico Operator installed"
    else
        print_error "Failed to install Calico Operator"
        return 1
    fi
    echo ""
    
    print_info "Waiting for operator to be ready (30 seconds)..."
    sleep 30
    echo ""
    
    print_info "Installing Calico Custom Resources..."
    if kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml; then
        print_success "Calico Custom Resources installed"
    else
        print_error "Failed to install Calico Custom Resources"
        return 1
    fi
    
    print_success "Calico installation initiated!"
    echo ""
    
    print_info "Waiting for Calico pods to start (this takes 2-3 minutes)..."
    echo "Watching Calico pods (press Ctrl+C when all are Running):"
    kubectl get pods -n calico-system -w
}

# ==========================================
# SECTION 3: CLEANUP FAILED PODS
# ==========================================

cleanup_failed_pods() {
    print_header "SECTION 3: Cleaning Up Failed Pods"
    echo ""

    print_info "Deleting pods in Failed state..."
    FAILED_COUNT=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
    if [ "$FAILED_COUNT" -gt 0 ]; then
        kubectl delete pods --field-selector=status.phase=Failed --all-namespaces
        print_success "Deleted $FAILED_COUNT failed pods"
    else
        print_info "No failed pods to delete"
    fi
    echo ""

    print_info "Deleting pods in Unknown state..."
    UNKNOWN_PODS=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.phase=="Unknown") | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null)
    if [ -n "$UNKNOWN_PODS" ]; then
        while IFS= read -r line; do
            NS=$(echo $line | awk '{print $1}')
            POD=$(echo $line | awk '{print $2}')
            kubectl delete pod $POD -n $NS
            print_success "Deleted unknown pod: $NS/$POD"
        done <<< "$UNKNOWN_PODS"
    else
        print_info "No unknown pods to delete"
    fi
    echo ""

    print_info "Restarting CoreDNS if needed..."
    kubectl delete pods -n kube-system -l k8s-app=kube-dns 2>/dev/null || print_info "CoreDNS pods not found or already healthy"
    echo ""

    print_success "Cleanup complete!"
}

# ==========================================
# SECTION 4: VERIFY CLUSTER HEALTH
# ==========================================

verify_cluster() {
    print_header "SECTION 4: Verifying Cluster Health"
    echo ""

    print_info "Checking nodes..."
    READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready" || true)
    TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
    if [ "$READY_NODES" -eq "$TOTAL_NODES" ]; then
        print_success "All $TOTAL_NODES nodes are Ready"
    else
        print_warning "$READY_NODES/$TOTAL_NODES nodes are Ready"
    fi
    kubectl get nodes
    echo ""

    print_info "Checking CoreDNS..."
    COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$COREDNS_RUNNING" -ge 1 ]; then
        print_success "CoreDNS is running ($COREDNS_RUNNING pods)"
    else
        print_warning "CoreDNS is not running properly"
    fi
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
    echo ""

    print_info "Checking Calico..."
    if kubectl get namespace calico-system &>/dev/null; then
        CALICO_RUNNING=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | grep -c "Running" || true)
        print_success "Calico is installed ($CALICO_RUNNING pods running)"
        kubectl get pods -n calico-system
    else
        print_error "Calico is NOT installed!"
    fi
    echo ""

    print_info "Checking application pods in default namespace..."
    kubectl get pods -n default
    echo ""

    print_info "Testing DNS resolution..."
    kubectl run -it --rm dns-test --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default 2>/dev/null || print_warning "DNS test failed or timed out"
    echo ""

    print_success "Verification complete!"
}

# ==========================================
# SECTION 5: DETAILED DIAGNOSTICS
# ==========================================

detailed_diagnostics() {
    print_header "SECTION 5: Detailed Diagnostics"
    echo ""

    print_info "Checking pod resource usage..."
    kubectl top nodes 2>/dev/null || print_warning "Metrics server not installed"
    echo ""

    print_info "Checking persistent volumes..."
    kubectl get pv,pvc --all-namespaces
    echo ""

    print_info "Checking services..."
    kubectl get svc --all-namespaces
    echo ""

    print_info "Checking deployments..."
    kubectl get deployments --all-namespaces
    echo ""

    print_info "Checking daemon sets..."
    kubectl get daemonsets --all-namespaces
    echo ""

    print_info "Recent events (last 30)..."
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -30
    echo ""
}

# ==========================================
# SECTION 6: FIX COMMON ISSUES
# ==========================================

fix_common_issues() {
    print_header "SECTION 6: Fixing Common Issues"
    echo ""

    # Check if CNI is missing
    if ! kubectl get namespace calico-system &>/dev/null; then
        print_warning "CNI (Calico) is not installed!"
        read -p "Do you want to install Calico now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_calico
        fi
    fi

    # Check for failed pods
    FAILED_COUNT=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
    if [ "$FAILED_COUNT" -gt 0 ]; then
        print_warning "Found $FAILED_COUNT failed pods"
        read -p "Do you want to clean up failed pods? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_failed_pods
        fi
    fi

    # Check CoreDNS
    COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || true)
    if [ "$COREDNS_RUNNING" -eq 0 ]; then
        print_warning "CoreDNS is not running"
        read -p "Do you want to restart CoreDNS? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete pods -n kube-system -l k8s-app=kube-dns
            print_success "CoreDNS pods deleted, they will restart automatically"
        fi
    fi

    print_success "Common issues check complete!"
}

# ==========================================
# MAIN MENU
# ==========================================

show_menu() {
    echo ""
    print_header "Kubernetes Troubleshooting Menu"
    echo ""
    echo "1) Run Full Health Check"
    echo "2) Verify CNI Configuration"
    echo "3) Complete CNI Cleanup (Calico/Flannel)"
    echo "4) Install Calico CNI"
    echo "5) Clean Up Failed Pods"
    echo "6) Verify Cluster Health"
    echo "7) Detailed Diagnostics"
    echo "8) Fix Common Issues (Interactive)"
    echo "9) Run All (Health Check + Verify)"
    echo "10) Exit"
    echo ""
    read -p "Select an option [1-10]: " choice
    
    case $choice in
        1) health_check ;;
        2) verify_cni_config ;;
        3) complete_cni_cleanup ;;
        4) install_calico ;;
        5) cleanup_failed_pods ;;
        6) verify_cluster ;;
        7) detailed_diagnostics ;;
        8) fix_common_issues ;;
        9) health_check; echo ""; verify_cluster ;;
        10) print_info "Exiting..."; exit 0 ;;
        *) print_error "Invalid option. Please try again." ;;
    esac
    
    show_menu
}

# ==========================================
# SCRIPT ENTRY POINT
# ==========================================

# Check if running with arguments
if [ $# -eq 0 ]; then
    # Interactive mode
    show_menu
else
    # Command line mode
    case $1 in
        health|check)
            health_check
            ;;
        verify-cni|cni-verify)
            verify_cni_config
            ;;
        cleanup-cni|cni-cleanup)
            complete_cni_cleanup
            ;;
        install-calico|calico)
            install_calico
            ;;
        cleanup|clean)
            cleanup_failed_pods
            ;;
        verify)
            verify_cluster
            ;;
        diagnostics|diag)
            detailed_diagnostics
            ;;
        fix)
            fix_common_issues
            ;;
        all)
            health_check
            echo ""
            verify_cluster
            ;;
        *)
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  health            - Run health check"
            echo "  verify-cni        - Verify CNI configuration"
            echo "  cleanup-cni       - Complete CNI cleanup (Calico/Flannel)"
            echo "  install-calico    - Install Calico CNI"
            echo "  cleanup           - Clean up failed pods"
            echo "  verify            - Verify cluster health"
            echo "  diagnostics       - Run detailed diagnostics"
            echo "  fix               - Fix common issues (interactive)"
            echo "  all               - Run health check and verify"
            echo ""
            echo "Run without arguments for interactive menu"
            exit 1
            ;;
    esac
fi
