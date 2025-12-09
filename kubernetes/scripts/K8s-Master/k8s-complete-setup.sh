#!/bin/bash
################################################################################
# Kubernetes Master Setup and Configuration Script
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
POD_NETWORK_CIDR="192.168.0.0/16"
CALICO_VERSION="v3.27.2"
CALICO_OPERATOR_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
CALICO_CUSTOM_RESOURCES_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"
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

# Get the actual user (not root when using sudo)
get_actual_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
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
        error_exit "kubeadm is not installed. Please run k8s_master.sh first."
    fi
    print_success "kubeadm is installed"
    
    # Check if kubectl is installed
    if ! command -v kubectl &>/dev/null; then
        error_exit "kubectl is not installed. Please run k8s_master.sh first."
    fi
    print_success "kubectl is installed"
    
    # Check if kubelet is installed
    if ! command -v kubelet &>/dev/null; then
        error_exit "kubelet is not installed. Please run k8s_master.sh first."
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
    
    echo ""
}

check_cluster_initialized() {
    print_header "Step 2: Checking Cluster Status"
    
    if [ -f /etc/kubernetes/admin.conf ]; then
        print_success "Cluster appears to be initialized (admin.conf exists)"
        return 0
    else
        print_warning "Cluster is NOT initialized (admin.conf not found)"
        return 1
    fi
}

################################################################################
# Main Functions
################################################################################

initialize_cluster() {
    print_header "Step 3: Initializing Kubernetes Cluster"
    
    # Check if already initialized
    if [ -f /etc/kubernetes/admin.conf ]; then
        print_info "Cluster already initialized. Skipping kubeadm init."
        return 0
    fi
    
    # Check if port 10250 is in use (partial initialization)
    if netstat -tuln | grep :10250 >/dev/null 2>&1; then
        print_warning "Port 10250 is in use. Resetting previous initialization..."
        kubeadm reset -f || print_warning "kubeadm reset failed, continuing..."
        rm -rf /etc/cni/net.d /var/lib/etcd /var/lib/kubelet
    fi
    
    print_info "Running kubeadm init with pod network CIDR: $POD_NETWORK_CIDR"
    
    # Initialize cluster
    if kubeadm init --pod-network-cidr="$POD_NETWORK_CIDR" --ignore-preflight-errors=NumCPU; then
        print_success "Cluster initialized successfully"
    else
        error_exit "Failed to initialize cluster with kubeadm init"
    fi
    
    # Wait for API server to be ready
    wait_for_condition "API server" "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes" 60
    
    echo ""
}

configure_kubectl() {
    print_header "Step 4: Configuring kubectl"
    
    local ACTUAL_USER=$(get_actual_user)
    local USER_HOME=$(eval echo ~$ACTUAL_USER)
    
    print_info "Configuring kubectl for user: $ACTUAL_USER"
    print_info "Home directory: $USER_HOME"
    
    # Create .kube directory
    if [ ! -d "$USER_HOME/.kube" ]; then
        mkdir -p "$USER_HOME/.kube"
        print_success "Created .kube directory"
    else
        print_info ".kube directory already exists"
    fi
    
    # Copy admin.conf
    if [ ! -f /etc/kubernetes/admin.conf ]; then
        error_exit "admin.conf not found. Cluster may not be initialized."
    fi
    
    cp -f /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
    print_success "Copied admin.conf to ~/.kube/config"
    
    # Fix ownership
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.kube"
    chmod 600 "$USER_HOME/.kube/config"
    print_success "Fixed ownership and permissions"
    
    # Verify kubectl works
    if sudo -u "$ACTUAL_USER" kubectl get nodes &>/dev/null; then
        print_success "kubectl is configured and working"
    else
        error_exit "kubectl configuration failed - cannot connect to cluster"
    fi
    
    echo ""
}

install_calico() {
    print_header "Step 5: Installing Calico CNI"
    
    local ACTUAL_USER=$(get_actual_user)
    
    # Check if Calico is already installed
    if sudo -u "$ACTUAL_USER" kubectl get namespace calico-system &>/dev/null; then
        print_info "Calico already installed. Checking status..."
        sudo -u "$ACTUAL_USER" kubectl get pods -n calico-system
        return 0
    fi
    
    # Clean up any failed previous attempts
    print_info "Cleaning up any previous failed installations..."
    sudo -u "$ACTUAL_USER" kubectl delete -f "$CALICO_OPERATOR_URL" --ignore-not-found &>/dev/null || true
    sudo -u "$ACTUAL_USER" kubectl delete namespace tigera-operator --ignore-not-found --timeout=30s &>/dev/null || true
    sleep 5
    
    # Install Tigera operator using CREATE (not apply) to avoid annotation size limit
    print_info "Installing Tigera operator (using kubectl create)..."
    if sudo -u "$ACTUAL_USER" kubectl create -f "$CALICO_OPERATOR_URL"; then
        print_success "Tigera operator manifest created"
    else
        print_error "Failed to create Tigera operator manifest"
        print_info "Trying with server-side apply as fallback..."
        if sudo -u "$ACTUAL_USER" kubectl apply --server-side -f "$CALICO_OPERATOR_URL"; then
            print_success "Tigera operator manifest applied (server-side)"
        else
            error_exit "Failed to install Tigera operator"
        fi
    fi
    
    # Wait for Tigera operator to be ready
    print_info "Waiting for Tigera operator to be ready..."
    if wait_for_condition "Tigera operator deployment" \
        "sudo -u $ACTUAL_USER kubectl get deployment tigera-operator -n tigera-operator" 120; then
        
        # Wait for deployment to be available
        if sudo -u "$ACTUAL_USER" kubectl wait --for=condition=available \
            --timeout=120s deployment/tigera-operator -n tigera-operator; then
            print_success "Tigera operator is ready"
        else
            print_warning "Tigera operator may not be fully ready, continuing..."
        fi
    else
        error_exit "Tigera operator failed to deploy"
    fi
    
    # Install Calico custom resources using CREATE
    print_info "Installing Calico custom resources (using kubectl create)..."
    if sudo -u "$ACTUAL_USER" kubectl create -f "$CALICO_CUSTOM_RESOURCES_URL"; then
        print_success "Calico custom resources created"
    else
        print_warning "Create failed, trying server-side apply..."
        if sudo -u "$ACTUAL_USER" kubectl apply --server-side -f "$CALICO_CUSTOM_RESOURCES_URL"; then
            print_success "Calico custom resources applied (server-side)"
        else
            error_exit "Failed to install Calico custom resources"
        fi
    fi
    
    # Wait for Calico pods to start
    print_info "Waiting for Calico pods to start (this may take 2-3 minutes)..."
    if wait_for_condition "Calico system namespace" \
        "sudo -u $ACTUAL_USER kubectl get pods -n calico-system" 180; then
        print_success "Calico pods are starting"
    else
        print_warning "Calico pods may still be initializing"
    fi
    
    echo ""
}

verify_installation() {
    print_header "Step 6: Verifying Installation"
    
    local ACTUAL_USER=$(get_actual_user)
    
    # Check nodes
    print_info "Checking cluster nodes..."
    sudo -u "$ACTUAL_USER" kubectl get nodes
    echo ""
    
    # Check system pods
    print_info "Checking system pods..."
    sudo -u "$ACTUAL_USER" kubectl get pods -n kube-system
    echo ""
    
    # Check Calico pods
    print_info "Checking Calico pods..."
    sudo -u "$ACTUAL_USER" kubectl get pods -n calico-system
    echo ""
    
    # Check if node is Ready
    NODE_STATUS=$(sudo -u "$ACTUAL_USER" kubectl get nodes --no-headers | awk '{print $2}')
    if [ "$NODE_STATUS" = "Ready" ]; then
        print_success "Node is Ready!"
    else
        print_warning "Node status: $NODE_STATUS (may take a few minutes to become Ready)"
    fi
    
    echo ""
}

generate_join_command() {
    print_header "Step 7: Generating Worker Join Command"
    
    print_info "Creating join command for worker nodes..."
    
    # Generate join command
    JOIN_COMMAND=$(kubeadm token create --print-join-command 2>/dev/null)
    
    if [ -z "$JOIN_COMMAND" ]; then
        print_warning "Failed to generate join command"
        return 1
    fi
    
    # Save to file
    cat > /root/k8s_join_command.sh <<EOF
#!/bin/bash
# Kubernetes Worker Join Command
# Generated: $(date)
# Run this on worker nodes to join the cluster

# Reset any previous configuration
sudo kubeadm reset -f || true
sudo rm -rf /etc/cni/net.d /var/lib/etcd /var/lib/kubelet

# Join the cluster
sudo $JOIN_COMMAND

echo "Worker node joined successfully!"
echo "Check status from master: kubectl get nodes"
EOF
    
    chmod +x /root/k8s_join_command.sh
    
    print_success "Join command saved to: /root/k8s_join_command.sh"
    echo ""
    print_info "To join a worker node, run on the worker:"
    echo -e "${YELLOW}$JOIN_COMMAND${NC}"
    echo ""
}

display_summary() {
    print_header "Setup Complete!"
    
    local ACTUAL_USER=$(get_actual_user)
    
    echo ""
    print_success "Kubernetes cluster is ready!"
    echo ""
    print_info "Next Steps:"
    echo "  1. Verify cluster status:"
    echo "     kubectl get nodes"
    echo "     kubectl get pods -A"
    echo ""
    echo "  2. Join worker nodes using:"
    echo "     cat /root/k8s_join_command.sh"
    echo ""
    echo "  3. Deploy applications:"
    echo "     kubectl apply -k kubernetes/base/"
    echo ""
    print_info "Useful Commands:"
    echo "  • Check node status: kubectl get nodes"
    echo "  • Check all pods: kubectl get pods -A"
    echo "  • Check Calico: kubectl get pods -n calico-system"
    echo "  • View logs: kubectl logs -f <pod-name> -n <namespace>"
    echo ""
    print_info "Troubleshooting:"
    echo "  • If node is NotReady, wait 2-3 minutes for Calico to initialize"
    echo "  • Check Calico pods: kubectl get pods -n calico-system"
    echo "  • View events: kubectl get events -A --sort-by='.lastTimestamp'"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "Kubernetes Master Complete Setup Script"
    echo ""
    print_info "This script will:"
    echo "  1. Validate prerequisites"
    echo "  2. Check cluster status"
    echo "  3. Initialize cluster (if needed)"
    echo "  4. Configure kubectl"
    echo "  5. Install Calico CNI"
    echo "  6. Verify installation"
    echo "  7. Generate worker join command"
    echo ""
    
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
    
    if ! check_cluster_initialized; then
        initialize_cluster
    fi
    
    configure_kubectl
    install_calico
    verify_installation
    generate_join_command
    display_summary
    
    print_success "All steps completed successfully!"
}

# Run main function
main "$@"
