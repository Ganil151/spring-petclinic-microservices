#!/bin/bash
################################################################################
# Kubernetes Worker Setup and Configuration Script
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MASTER_IP="${1:-}"
JOIN_TOKEN="${2:-}"
JOIN_CA_HASH="${3:-}"
TIMEOUT=300  # 5 minutes timeout for operations

################################################################################
# Helper Functions
################################################################################

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

# Error handler
error_exit() {
    print_error "$1"
    exit 1
}

# Check if running as root or with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root or with sudo"
    fi
}

# Wait for condition with timeout
wait_for_condition() {
    local description="$1"
    local command="$2"
    local timeout="${3:-$TIMEOUT}"
    local interval=5
    local elapsed=0

    print_info "Waiting for: $description (timeout: ${timeout}s)"
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$command" &>/dev/null; then
            print_success "$description - Ready!"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    print_error "$description - Timeout after ${timeout}s"
    return 1
}

################################################################################
# Validation Functions
################################################################################

validate_prerequisites() {
    print_header "Step 1: Validating Prerequisites"
    
    # Check if kubeadm is installed
    if ! command -v kubeadm &>/dev/null; then
        error_exit "kubeadm is not installed. Please run k8s_worker.sh first."
    fi
    print_success "kubeadm is installed"
    
    # Check if kubectl is installed
    if ! command -v kubectl &>/dev/null; then
        error_exit "kubectl is not installed. Please run k8s_worker.sh first."
    fi
    print_success "kubectl is installed"
    
    # Check if kubelet is installed
    if ! command -v kubelet &>/dev/null; then
        error_exit "kubelet is not installed. Please run k8s_worker.sh first."
    fi
    print_success "kubelet is installed"
    
    # Check if kubelet is running
    if ! systemctl is-active --quiet kubelet; then
        print_warning "kubelet is not running. Starting it..."
        systemctl start kubelet || error_exit "Failed to start kubelet"
    fi
    print_success "kubelet is running"
    
    # Check if containerd is running
    if ! systemctl is-active --quiet containerd; then
        error_exit "containerd is not running. Please check container runtime."
    fi
    print_success "containerd is running"
    
    # Check if Docker is running (for Jenkins builds)
    if systemctl is-active --quiet docker; then
        print_success "Docker is running (for Jenkins builds)"
    else
        print_warning "Docker is not running (optional for Jenkins builds)"
    fi
    
    echo ""
}

check_already_joined() {
    print_header "Step 2: Checking Worker Status"
    
    # Check if kubelet config exists
    if [ -f /etc/kubernetes/kubelet.conf ]; then
        print_warning "Worker appears to be already joined to a cluster"
        print_info "Current kubelet config exists at /etc/kubernetes/kubelet.conf"
        
        read -p "Do you want to reset and rejoin? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1  # Need to reset
        else
            print_info "Keeping existing configuration"
            return 0  # Already joined, keep it
        fi
    else
        print_info "Worker is not joined to any cluster"
        return 1  # Need to join
    fi
}

################################################################################
# Main Functions
################################################################################

reset_worker() {
    print_header "Step 3: Resetting Worker Node"
    
    print_info "Resetting any previous cluster configuration..."
    
    # Reset kubeadm
    if kubeadm reset -f; then
        print_success "kubeadm reset completed"
    else
        print_warning "kubeadm reset had some issues, continuing..."
    fi
    
    # Clean up directories
    print_info "Cleaning up directories..."
    rm -rf /etc/cni/net.d
    rm -rf /var/lib/etcd
    rm -rf /var/lib/kubelet
    rm -rf /etc/kubernetes
    print_success "Cleanup completed"
    
    # Restart kubelet
    systemctl restart kubelet
    print_success "kubelet restarted"
    
    echo ""
}

get_join_command() {
    print_header "Step 4: Getting Join Command"
    
    # Check if join parameters were provided
    if [ -n "$MASTER_IP" ] && [ -n "$JOIN_TOKEN" ] && [ -n "$JOIN_CA_HASH" ]; then
        print_info "Using provided join parameters"
        JOIN_COMMAND="kubeadm join ${MASTER_IP}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash ${JOIN_CA_HASH}"
        print_success "Join command constructed from parameters"
        return 0
    fi
    
    # Try to get from master server
    print_info "Attempting to retrieve join command from master..."
    
    # Prompt for master IP if not provided
    if [ -z "$MASTER_IP" ]; then
        read -p "Enter K8s Master IP address: " MASTER_IP
    fi
    
    # Try to SSH and get join command
    print_info "Trying to retrieve join command from master at $MASTER_IP..."
    
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@"$MASTER_IP" \
        "sudo kubeadm token create --print-join-command" > /tmp/join_command.txt 2>/dev/null; then
        
        JOIN_COMMAND=$(cat /tmp/join_command.txt)
        rm -f /tmp/join_command.txt
        print_success "Retrieved join command from master"
        return 0
    else
        print_warning "Could not retrieve join command from master"
        print_info "Please run this on the master node:"
        echo -e "${YELLOW}  sudo kubeadm token create --print-join-command${NC}"
        echo ""
        read -p "Enter the complete join command: " JOIN_COMMAND
        
        if [ -z "$JOIN_COMMAND" ]; then
            error_exit "Join command is required"
        fi
    fi
    
    echo ""
}

join_cluster() {
    print_header "Step 5: Joining Kubernetes Cluster"
    
    print_info "Executing join command..."
    echo -e "${YELLOW}$JOIN_COMMAND${NC}"
    echo ""
    
    # Execute join command
    if eval "$JOIN_COMMAND"; then
        print_success "Successfully joined the cluster!"
    else
        error_exit "Failed to join the cluster. Check the join command and network connectivity."
    fi
    
    # Wait for kubelet to stabilize
    sleep 5
    
    # Check if kubelet is running
    if systemctl is-active --quiet kubelet; then
        print_success "kubelet is running"
    else
        print_warning "kubelet may not be running properly"
        systemctl status kubelet --no-pager || true
    fi
    
    echo ""
}

verify_join() {
    print_header "Step 6: Verifying Worker Node"
    
    print_info "Checking if worker joined successfully..."
    
    # Check if kubelet.conf exists
    if [ -f /etc/kubernetes/kubelet.conf ]; then
        print_success "kubelet.conf created"
    else
        print_error "kubelet.conf not found - join may have failed"
    fi
    
    # Check kubelet status
    print_info "Kubelet status:"
    systemctl status kubelet --no-pager | head -10
    echo ""
    
    # Check running containers
    print_info "Checking running containers..."
    CONTAINER_COUNT=$(crictl ps 2>/dev/null | grep -v CONTAINER | wc -l)
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        print_success "Found $CONTAINER_COUNT running containers"
        crictl ps
    else
        print_warning "No containers running yet (may take a few minutes)"
    fi
    
    echo ""
    
    # Instructions for master
    print_info "To verify from the master node, run:"
    echo -e "${YELLOW}  kubectl get nodes${NC}"
    echo ""
    print_info "The worker should appear as:"
    echo "  K8s-Worker-Server   NotReady   <none>   Xs    v1.31.14"
    echo ""
    print_info "It will change to 'Ready' once CNI is configured (2-3 minutes)"
    
    echo ""
}

configure_docker_permissions() {
    print_header "Step 7: Configuring Docker Permissions"
    
    # Add ec2-user to docker group for Jenkins builds
    if command -v docker &>/dev/null; then
        print_info "Adding ec2-user to docker group..."
        usermod -aG docker ec2-user || print_warning "Failed to add user to docker group"
        print_success "ec2-user added to docker group"
        print_info "User needs to log out and back in for group changes to take effect"
    else
        print_warning "Docker not installed - skipping docker group configuration"
    fi
    
    echo ""
}

display_summary() {
    print_header "Worker Setup Complete!"
    
    echo ""
    print_success "Worker node has been configured and joined to the cluster!"
    echo ""
    print_info "Next Steps:"
    echo "  1. Verify from master node:"
    echo "     kubectl get nodes"
    echo "     kubectl get pods -A"
    echo ""
    echo "  2. Wait for node to become Ready (2-3 minutes)"
    echo "     The node will show 'NotReady' until CNI is fully configured"
    echo ""
    echo "  3. Check node status:"
    echo "     kubectl describe node K8s-Worker-Server"
    echo ""
    print_info "Worker Node Information:"
    echo "  • Hostname: $(hostname)"
    echo "  • IP Address: $(hostname -I | awk '{print $1}')"
    echo "  • Kubelet Status: $(systemctl is-active kubelet)"
    echo "  • Containerd Status: $(systemctl is-active containerd)"
    if command -v docker &>/dev/null; then
        echo "  • Docker Status: $(systemctl is-active docker)"
    fi
    echo ""
    print_info "Troubleshooting:"
    echo "  • Check kubelet logs: sudo journalctl -u kubelet -f"
    echo "  • Check containers: sudo crictl ps"
    echo "  • Check node from master: kubectl describe node K8s-Worker-Server"
    echo ""
}

show_usage() {
    echo "Usage: sudo bash k8s-worker-complete-setup.sh [MASTER_IP] [TOKEN] [CA_HASH]"
    echo ""
    echo "Examples:"
    echo "  # Interactive mode (will prompt for join command)"
    echo "  sudo bash k8s-worker-complete-setup.sh"
    echo ""
    echo "  # With master IP (will try to retrieve join command)"
    echo "  sudo bash k8s-worker-complete-setup.sh 10.0.1.100"
    echo ""
    echo "  # With full join parameters"
    echo "  sudo bash k8s-worker-complete-setup.sh 10.0.1.100 abcdef.1234567890abcdef sha256:abc123..."
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "Kubernetes Worker Complete Setup Script"
    echo ""
    print_info "This script will:"
    echo "  1. Validate prerequisites"
    echo "  2. Check worker status"
    echo "  3. Reset previous configuration (if needed)"
    echo "  4. Get join command"
    echo "  5. Join the cluster"
    echo "  6. Verify the join"
    echo "  7. Configure Docker permissions"
    echo ""
    
    # Show usage if help requested
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    # Confirm execution
    read -p "Continue? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled by user"
        exit 0
    fi
    
    # Run setup steps
    check_sudo
    validate_prerequisites
    
    if ! check_already_joined; then
        reset_worker
        get_join_command
        join_cluster
    else
        print_info "Worker is already joined. Skipping join process."
    fi
    
    verify_join
    configure_docker_permissions
    display_summary
    
    print_success "All steps completed successfully!"
}

# Run main function
main "$@"
