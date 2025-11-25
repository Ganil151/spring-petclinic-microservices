#!/bin/bash
################################################################################
# Kubernetes Worker Setup and Configuration Script
################################################################################

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Exit if any unset variable is referenced.

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
TIMEOUT=300   # 5 minutes timeout for operations

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

################################################################################
# Environment Setup & Validation
################################################################################

disable_swap() {
    print_header "Step 0: Disabling Swap (Kubernetes Prerequisite)"
    
    if grep -q "swap" /etc/fstab; then
        print_info "Swap detected in /etc/fstab. Commenting out..."
        sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab
        print_success "/etc/fstab updated."
    fi

    if swapoff -a; then
        print_success "Swap disabled for current session."
    else
        print_warning "Failed to disable swap with swapoff -a (may already be disabled)."
    fi
    
    # Verify swap is off
    if ! swapon --show | grep -q "swap"; then
        print_success "Verification: Swap is permanently disabled."
    else
        print_error "Verification: Swap is still active. Manual check needed."
    fi
    echo ""
}


validate_prerequisites() {
    print_header "Step 1: Validating Prerequisites"
    
    # Check if kubeadm is installed
    if ! command -v kubeadm &>/dev/null; then
        error_exit "kubeadm is not installed. Please install k8s components first."
    fi
    print_success "kubeadm is installed"
    
    # Check if kubelet is installed (kubectl is not strictly needed on the worker)
    if ! command -v kubelet &>/dev/null; then
        error_exit "kubelet is not installed. Please install k8s components first."
    fi
    print_success "kubelet is installed"
    
    # Check if kubelet is running
    if ! systemctl is-active --quiet kubelet; then
        print_warning "kubelet is not running. Starting it..."
        systemctl enable kubelet --now || error_exit "Failed to enable and start kubelet"
    fi
    print_success "kubelet is running"
    
    # Check if containerd is running
    if ! systemctl is-active --quiet containerd; then
        print_error "containerd is not running. Attempting to start..."
        systemctl enable containerd --now || error_exit "Failed to enable and start containerd"
    fi
    print_success "containerd is running"
    
    # Check if Docker is running (optional for Jenkins builds)
    if systemctl is-active --quiet docker; then
        print_success "Docker is running (Available for Jenkins builds)"
    else
        print_warning "Docker is not running (optional for Jenkins builds)"
    fi
    
    echo ""
}

check_already_joined() {
    print_header "Step 2: Checking Worker Status"
    
    # Check if kubelet config exists (Primary indication of a joined node)
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
    
    # Reset kubeadm with force flag
    if kubeadm reset -f; then
        print_success "kubeadm reset completed"
    else
        print_warning "kubeadm reset encountered minor issues, continuing..."
    fi
    
    # Full cleanup of directories to remove all CNI/K8s remnants
    print_info "Cleaning up directories and configuration files..."
    # The --force flag in kubeadm reset should handle most of this, but redundancy is safe.
    rm -rf /etc/cni/net.d/* || true # Clear CNI config files
    rm -rf /var/lib/kubelet/* || true
    rm -rf /var/lib/etcd/* || true
    rm -rf /etc/kubernetes/* || true
    print_success "Cleanup completed"
    
    # Restart kubelet to clear service state
    systemctl restart kubelet
    print_success "kubelet restarted"
    
    echo ""
}

get_join_command() {
    print_header "Step 4: Getting Join Command"
    
    # Use provided parameters first
    if [ -n "$MASTER_IP" ] && [ -n "$JOIN_TOKEN" ] && [ -n "$JOIN_CA_HASH" ]; then
        print_info "Using provided join parameters from script arguments."
        JOIN_COMMAND="sudo kubeadm join ${MASTER_IP}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash ${JOIN_CA_HASH}"
        print_success "Join command constructed from parameters"
        return 0
    fi
    
    # Try to get from master server
    print_info "Attempting to retrieve join command from master via SSH..."
    
    # Prompt for master IP if not provided
    if [ -z "$MASTER_IP" ]; then
        read -p "Enter K8s Master IP address: " MASTER_IP
        if [ -z "$MASTER_IP" ]; then
            print_warning "Master IP not provided."
        fi
    fi
    
    # Attempt to SSH and get join command (requires SSH key auth without password)
    if [ -n "$MASTER_IP" ]; then
        print_info "Trying to retrieve command from master at $MASTER_IP..."
        
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@"$MASTER_IP" \
            "sudo kubeadm token create --print-join-command" > /tmp/join_command.txt 2>/dev/null; then
            
            # The join command retrieved usually includes 'kubeadm' but might not include 'sudo'.
            JOIN_COMMAND=$(cat /tmp/join_command.txt | sed 's/^kubeadm/sudo kubeadm/')
            rm -f /tmp/join_command.txt
            print_success "Retrieved join command from master"
            return 0
        fi
    fi
    
    # Fallback to manual entry
    print_warning "Could not retrieve join command from master automatically."
    print_info "Please run this on the master node:"
    echo -e "${YELLOW}  sudo kubeadm token create --print-join-command${NC}"
    echo ""
    read -p "Enter the COMPLETE join command (e.g., sudo kubeadm join...): " JOIN_COMMAND
    
    if [ -z "$JOIN_COMMAND" ]; then
        error_exit "Join command is required"
    fi
    
    echo ""
}

join_cluster() {
    print_header "Step 5: Joining Kubernetes Cluster"
    
    print_info "Executing join command..."
    echo -e "${YELLOW}$JOIN_COMMAND${NC}"
    echo ""
    
    # Execute join command
    # Use 'sudo' in the eval command because the JOIN_COMMAND from the master might not include it.
    # If the retrieved command already has sudo, running 'sudo sudo' is harmless.
    if eval "$JOIN_COMMAND"; then
        print_success "Successfully joined the cluster!"
    else
        error_exit "Failed to join the cluster. Check the join command, firewall, and network connectivity."
    fi
    
    # Give kubelet time to reconcile
    sleep 5
    systemctl status kubelet --no-pager || true # Show status even on failure
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
    
    # Check running containers
    print_info "Checking running containers (should see pause container)..."
    CONTAINER_COUNT=$(crictl ps 2>/dev/null | grep -v CONTAINER | wc -l)
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        print_success "Found $CONTAINER_COUNT running containers (including crictl sandbox)"
        # crictl ps
    else
        print_warning "No containers running yet (may indicate CNI/Kubelet issue)"
    fi
    
    echo ""
    
    # Instructions for master
    print_info "To verify from the master node, run:"
    echo -e "${YELLOW}  kubectl get nodes${NC}"
    echo ""
    print_info "The node should appear in the list, likely with status 'NotReady' until CNI is fully configured."
    
    echo ""
}

configure_docker_permissions() {
    print_header "Step 7: Configuring Docker Permissions (for Jenkins Agent)"
    
    # Add ec2-user to docker group for Jenkins builds
    if command -v docker &>/dev/null; then
        print_info "Adding ec2-user to docker group..."
        # Check if ec2-user already belongs to the docker group before adding
        if ! id -nG ec2-user | grep -q '\bdocker\b'; then
             usermod -aG docker ec2-user || print_warning "Failed to add user to docker group"
             print_success "ec2-user added to docker group."
             print_info "You MUST log out and back in as ec2-user for group changes to take effect."
        else
             print_success "ec2-user is already in the docker group."
        fi
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
    print_info "Next Steps (Run from Master Node):"
    echo "  1. Verify node status: \`${YELLOW}kubectl get nodes${NC}\`"
    echo "  2. If the node is NotReady, check Calico/CNI logs on the master/worker."
    echo ""
    print_info "Worker Node Information:"
    echo "  • Hostname: $(hostname)"
    echo "  • IP Address: $(hostname -I | awk '{print $1}')"
    echo "  • Kubelet Status: $(systemctl is-active kubelet)"
    echo "  • Swap Status: $(swapon --show | grep -q "swap" && echo "Active" || echo "Disabled")"
    echo ""
    print_info "Troubleshooting:"
    echo "  • Check kubelet logs: \`${YELLOW}sudo journalctl -u kubelet -f${NC}\`"
    echo "  • Check containers: \`${YELLOW}sudo crictl ps -a${NC}\`"
    echo ""
}

show_usage() {
    echo "Usage: sudo bash k8s-worker-setup.sh [MASTER_IP] [TOKEN] [CA_HASH]"
    echo ""
    echo "This script attempts to join this machine to a Kubernetes cluster."
    echo ""
    echo "If no arguments are provided, it will attempt an interactive setup."
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "Kubernetes Worker Complete Setup Script"
    echo ""
    
    # Show usage if help requested
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    check_sudo
    
    # Confirm execution
    read -p "Start the Kubernetes Worker setup process? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled by user"
        exit 0
    fi
    
    # Run setup steps
    disable_swap  # NEW step: Ensure swap is off
    validate_prerequisites
    
    # Check if a reset or join is needed
    if ! check_already_joined; then
        reset_worker
        get_join_command
        join_cluster
    else
        print_info "Worker is already joined and user chose to skip join process."
    fi
    
    verify_join
    configure_docker_permissions
    display_summary
    
    print_success "All necessary steps completed successfully!"
}

# Run main function
main "$@"