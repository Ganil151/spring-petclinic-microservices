#!/bin/bash

#############################################################################
# Kubernetes Master-Worker Connectivity Fix Script
# This script diagnoses and fixes connectivity issues between K8s nodes
#############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#############################################################################
# 1. CHECK KUBERNETES CLUSTER STATUS
#############################################################################
check_cluster_status() {
    log_info "========================================="
    log_info "1. CHECKING KUBERNETES CLUSTER STATUS"
    log_info "========================================="
    
    log_info "Kubernetes version:"
    kubectl version --short 2>&1 || true
    
    log_info "\nCluster info:"
    kubectl cluster-info 2>&1 || true
    
    log_info "\nNode status:"
    kubectl get nodes -o wide
    
    log_info "\nNode details:"
    kubectl describe nodes 2>&1 | grep -A 5 "Name:\|Status\|Roles\|Allocatable\|Allocated resources" || true
}

#############################################################################
# 2. CHECK NODE CONNECTIVITY
#############################################################################
check_node_connectivity() {
    log_info "\n========================================="
    log_info "2. CHECKING NODE-TO-NODE CONNECTIVITY"
    log_info "========================================="
    
    # Get all nodes
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$nodes" ]; then
        log_error "No nodes found in cluster"
        return 1
    fi
    
    for node in $nodes; do
        log_info "\n--- Node: $node ---"
        
        # Get node IP addresses
        local internal_ip=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
        local external_ip=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="ExternalIP")].address}')
        local hostname=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="Hostname")].address}')
        
        log_info "Internal IP: $internal_ip"
        [ -n "$external_ip" ] && log_info "External IP: $external_ip" || log_warn "No external IP assigned"
        log_info "Hostname: $hostname"
        
        # Check node conditions
        log_info "Node Conditions:"
        kubectl describe node "$node" 2>&1 | grep -A 10 "Conditions:" || true
    done
}

#############################################################################
# 3. CHECK KUBELET STATUS ON NODES
#############################################################################
check_kubelet_status() {
    log_info "\n========================================="
    log_info "3. CHECKING KUBELET STATUS"
    log_info "========================================="
    
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    for node in $nodes; do
        log_info "\n--- Kubelet on $node ---"
        
        # Check kubelet status via node status
        kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")]}' 2>&1 || true
        echo
        
        # Check node resource allocation
        kubectl describe node "$node" 2>&1 | grep -A 5 "Allocated resources" || true
    done
}

#############################################################################
# 4. CHECK NETWORK PLUGIN (CNI)
#############################################################################
check_cni_status() {
    log_info "\n========================================="
    log_info "4. CHECKING NETWORK PLUGIN (CNI)"
    log_info "========================================="
    
    log_info "Network plugin pods:"
    kubectl get pods -A | grep -E "calico|weave|flannel|cilium" || log_warn "No common CNI pods found"
    
    log_info "\nAll network-related pods in kube-system:"
    kubectl get pods -n kube-system -o wide 2>&1 | head -20
}

#############################################################################
# 5. CHECK DNS RESOLUTION
#############################################################################
check_dns_resolution() {
    log_info "\n========================================="
    log_info "5. CHECKING DNS RESOLUTION"
    log_info "========================================="
    
    log_info "CoreDNS pods:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>&1 || true
    
    log_info "\nDNS service:"
    kubectl get svc -n kube-system kube-dns 2>&1 || true
    
    log_info "\nTesting DNS from a pod (if available):"
    # Try to find a running pod to test DNS
    local test_pod=$(kubectl get pods -A -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    local test_ns=$(kubectl get pods -A -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    
    if [ -n "$test_pod" ] && [ -n "$test_ns" ]; then
        log_info "Testing DNS from pod: $test_pod (namespace: $test_ns)"
        kubectl exec -it "$test_pod" -n "$test_ns" -- nslookup kubernetes.default 2>&1 || true
    else
        log_warn "No running pods available for DNS test"
    fi
}

#############################################################################
# 6. CHECK FIREWALL/SECURITY GROUPS (AWS-specific)
#############################################################################
check_security_groups() {
    log_info "\n========================================="
    log_info "6. CHECKING SECURITY GROUPS (AWS)"
    log_info "========================================="
    
    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not installed, skipping security group check"
        return
    fi
    
    # Get security group info from node metadata if available
    log_info "Attempting to retrieve security group info..."
    
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    for node in $nodes; do
        log_info "\nNode: $node"
        kubectl describe node "$node" 2>&1 | grep -i "provider-id" || true
    done
}

#############################################################################
# 7. CHECK FIREWALL RULES ON NODES
#############################################################################
check_local_firewall() {
    log_info "\n========================================="
    log_info "7. CHECKING LOCAL FIREWALL ON NODES"
    log_info "========================================="
    
    log_info "Checking if nodes have local firewall rules..."
    log_info "(This requires SSH access to nodes)"
    
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    
    for node_ip in $nodes; do
        log_info "\n--- Node IP: $node_ip ---"
        
        # Try to check firewall rules
        if ping -c 1 -W 2 "$node_ip" &> /dev/null; then
            log_success "Node $node_ip is reachable"
        else
            log_error "Node $node_ip is NOT reachable"
        fi
    done
}

#############################################################################
# 8. FIX: RESTART KUBELET ON ALL NODES
#############################################################################
restart_kubelet() {
    log_info "\n========================================="
    log_info "8. RESTARTING KUBELET ON ALL NODES"
    log_info "========================================="
    
    log_warn "This action requires SSH access to nodes"
    log_info "Kubelet is typically restarted via systemctl on Linux nodes"
    
    # This is informational since we don't have direct access
    cat << 'EOF'
To manually restart kubelet on each worker node, SSH into the node and run:
    sudo systemctl restart kubelet
    sudo systemctl status kubelet

To restart on all nodes (if you have SSH access), you can run:
    for node in <node1> <node2> <node3>; do
        ssh -i /path/to/key ec2-user@$node "sudo systemctl restart kubelet"
    done
EOF
}

#############################################################################
# 9. FIX: DRAIN AND CORDONE NODES
#############################################################################
manage_node_status() {
    log_info "\n========================================="
    log_info "9. MANAGING NODE STATUS"
    log_info "========================================="
    
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    log_info "Current node status:"
    kubectl get nodes -o wide
    
    log_info "\nTo drain a node (removes all pods, graceful):"
    log_info "kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data"
    
    log_info "\nTo cordon a node (prevents new pods):"
    log_info "kubectl cordon <node-name>"
    
    log_info "\nTo uncordon a node (allows new pods):"
    log_info "kubectl uncordon <node-name>"
}

#############################################################################
# 10. FIX: RESTART FAILED PODS
#############################################################################
restart_failed_pods() {
    log_info "\n========================================="
    log_info "10. RESTARTING FAILED PODS"
    log_info "========================================="
    
    log_info "Failed pods in default namespace:"
    kubectl get pods -n default -o wide | grep -E "CrashLoop|Pending|Error" || log_success "No failed pods found"
    
    log_info "\nFailed pods in kube-system namespace:"
    kubectl get pods -n kube-system -o wide | grep -E "CrashLoop|Pending|Error" || log_success "No failed pods found"
    
    log_info "\nTo delete and recreate a failed deployment:"
    log_info "kubectl rollout restart deployment/<deployment-name> -n <namespace>"
}

#############################################################################
# 11. CHECK API SERVER CONNECTIVITY
#############################################################################
check_api_server() {
    log_info "\n========================================="
    log_info "11. CHECKING API SERVER CONNECTIVITY"
    log_info "========================================="
    
    log_info "API Server endpoint:"
    kubectl cluster-info | grep 'Kubernetes master'
    
    log_info "\nAPI Server health:"
    kubectl get componentstatus 2>&1 || log_warn "componentstatus not available in newer K8s versions"
    
    log_info "\nControl plane pods:"
    kubectl get pods -n kube-system -l tier=control-plane -o wide 2>&1 || true
}

#############################################################################
# 12. CHECK ETCD STATUS
#############################################################################
check_etcd_status() {
    log_info "\n========================================="
    log_info "12. CHECKING ETCD STATUS"
    log_info "========================================="
    
    log_info "etcd pods:"
    kubectl get pods -n kube-system | grep etcd || log_warn "No etcd pods found (may be running as static pod)"
    
    log_info "\nChecking etcd via API:"
    kubectl get endpoints etcd-servers -n kube-system 2>&1 || log_warn "etcd-servers endpoint not found"
}

#############################################################################
# 13. AUTOMATIC FIX: UNCORDON ALL NODES
#############################################################################
uncordon_all_nodes() {
    log_info "\n========================================="
    log_info "13. UNCORDONING ALL NODES"
    log_info "========================================="
    
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    local cordoned_count=0
    
    for node in $nodes; do
        local status=$(kubectl get node "$node" -o jsonpath='{.spec.unschedulable}')
        if [ "$status" = "true" ]; then
            log_warn "Node $node is cordoned, uncordoning..."
            kubectl uncordon "$node"
            cordoned_count=$((cordoned_count + 1))
        fi
    done
    
    if [ $cordoned_count -eq 0 ]; then
        log_success "No cordoned nodes found"
    else
        log_success "Uncordoned $cordoned_count node(s)"
    fi
}

#############################################################################
# 14. AUTOMATIC FIX: CHECK NODE DISK SPACE
#############################################################################
check_node_disk_space() {
    log_info "\n========================================="
    log_info "14. CHECKING NODE DISK SPACE"
    log_info "========================================="
    
    log_info "Node disk pressure:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="DiskPressure")].status}{"\n"}{end}'
    
    log_info "\nNode memory pressure:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="MemoryPressure")].status}{"\n"}{end}'
    
    log_info "\nNode PID pressure:"
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="PIDPressure")].status}{"\n"}{end}'
}

#############################################################################
# 15. GENERATE CONNECTIVITY REPORT
#############################################################################
generate_report() {
    log_info "\n========================================="
    log_info "CONNECTIVITY DIAGNOSTIC REPORT"
    log_info "========================================="
    
    local report_file="/tmp/k8s-connectivity-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Kubernetes Connectivity Diagnostic Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        echo "Cluster Info:"
        kubectl cluster-info 2>&1 || true
        echo ""
        echo "Nodes:"
        kubectl get nodes -o wide
        echo ""
        echo "Node Status:"
        kubectl describe nodes 2>&1 | grep -A 10 "Conditions:" || true
        echo ""
        echo "Pod Status (All Namespaces):"
        kubectl get pods -A 2>&1 | grep -E "Pending|CrashLoop|Error" || echo "No failed pods"
        echo ""
        echo "Network Plugins:"
        kubectl get pods -A | grep -E "calico|weave|flannel|cilium" || echo "No common CNI pods found"
        echo ""
        echo "DNS Services:"
        kubectl get pods -n kube-system -l k8s-app=kube-dns 2>&1 || true
    } > "$report_file"
    
    log_success "Diagnostic report saved to: $report_file"
}

#############################################################################
# MAIN EXECUTION
#############################################################################
main() {
    log_info "Starting Kubernetes Connectivity Diagnostic and Fix Script"
    log_info "========================================================"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Run all diagnostics
    check_cluster_status
    check_node_connectivity
    check_kubelet_status
    check_cni_status
    check_dns_resolution
    check_security_groups
    check_local_firewall
    check_api_server
    check_etcd_status
    check_node_disk_space
    
    # Run automatic fixes
    uncordon_all_nodes
    
    # Generate report
    generate_report
    
    log_info "\n========================================="
    log_info "SUMMARY OF ACTIONS"
    log_info "========================================="
    log_info "✓ Diagnostic checks completed"
    log_info "✓ All cordoned nodes uncordoned"
    log_info "✓ Report generated"
    
    log_warn "\nNEXT STEPS:"
    log_info "1. Review the diagnostic output above"
    log_info "2. Check pod logs for specific errors:"
    log_info "   kubectl logs <pod-name> -n <namespace>"
    log_info "3. Restart failed pods:"
    log_info "   kubectl rollout restart deployment/<deployment-name>"
    log_info "4. If nodes are NotReady, SSH to the node and restart kubelet:"
    log_info "   sudo systemctl restart kubelet"
    log_info "5. Check AWS security groups if external connectivity is needed"
}

# Run main function
main "$@"
