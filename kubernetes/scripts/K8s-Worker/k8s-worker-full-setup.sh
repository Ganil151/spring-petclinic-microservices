#!/bin/bash
################################################################################
# Complete Kubernetes Worker Setup Script
# This script installs K8s components AND joins the cluster
################################################################################

set -e
set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MASTER_IP="${1:-}"
JOIN_TOKEN="${2:-}"
JOIN_CA_HASH="${3:-}"

print_header() { echo -e "${BLUE}========================================\n$1\n==========================================${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
error_exit() { print_error "$1"; exit 1; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root or with sudo"
fi

################################################################################
# PART 1: INSTALL KUBERNETES COMPONENTS
################################################################################

install_k8s_components() {
    print_header "Part 1: Installing Kubernetes Components"
    
    # Configure Hostname
    print_info "Configuring hostname..."
    NEW_HOSTNAME="K8s-Worker-Server"
    hostnamectl set-hostname ${NEW_HOSTNAME}
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    echo "${PRIVATE_IP} ${NEW_HOSTNAME}" >> /etc/hosts
    print_success "Hostname configured"
    
    # Install Dependencies
    print_info "Installing dependencies..."
    dnf update -y
    dnf install -y wget iproute-tc conntrack
    print_success "Dependencies installed"
    
    # Kernel Modules
    print_info "Configuring kernel modules..."
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.rp_filter         = 0
net.ipv4.conf.default.rp_filter     = 0
EOF
    
    sysctl --system
    print_success "Kernel modules configured"
    
    # Disable Swap
    print_info "Disabling swap..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
    print_success "Swap disabled"
    
    # SELinux
    print_info "Configuring SELinux..."
    setenforce 0 || true
    sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
    print_success "SELinux configured"
    
    # Install Containerd
    print_info "Installing containerd..."
    dnf install -y containerd
    systemctl enable --now containerd
    
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml >/dev/null
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sed -i 's|pause:3.6|pause:3.10|' /etc/containerd/config.toml
    
    systemctl restart containerd
    print_success "Containerd installed and configured"
    
    # Configure kubelet
    mkdir -p /etc/systemd/system/kubelet.service.d
    cat <<EOF | tee /etc/systemd/system/kubelet.service.d/10-containerd.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF
    
    systemctl daemon-reload
    
    # Kubernetes Repo
    print_info "Adding Kubernetes repository..."
    cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    print_success "Kubernetes repository added"
    
    # Install Kubeadm / Kubelet (kubectl not needed on worker)
    print_info "Installing kubeadm and kubelet..."
    dnf install -y kubelet kubeadm --disableexcludes=kubernetes
    systemctl enable --now kubelet
    print_success "Kubernetes components installed"
    
    # Clean Old State
    rm -rf /etc/cni/net.d/* /var/lib/kubelet/*
    
    print_success "Part 1 Complete: Kubernetes components installed"
    echo ""
}

################################################################################
# PART 2: JOIN CLUSTER
################################################################################

get_join_command() {
    print_header "Part 2: Getting Join Command"
    
    # Use provided parameters first
    if [ -n "$MASTER_IP" ] && [ -n "$JOIN_TOKEN" ] && [ -n "$JOIN_CA_HASH" ]; then
        print_info "Using provided join parameters"
        JOIN_COMMAND="kubeadm join ${MASTER_IP}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash ${JOIN_CA_HASH}"
        print_success "Join command constructed"
        return 0
    fi
    
    # Prompt for master IP
    if [ -z "$MASTER_IP" ]; then
        read -p "Enter K8s Master IP address: " MASTER_IP
    fi
    
    # Try to get from master
    if [ -n "$MASTER_IP" ]; then
        print_info "Attempting to retrieve join command from master..."
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@"$MASTER_IP" \
            "sudo kubeadm token create --print-join-command" > /tmp/join_command.txt 2>/dev/null; then
            
            JOIN_COMMAND=$(cat /tmp/join_command.txt)
            rm -f /tmp/join_command.txt
            print_success "Retrieved join command from master"
            return 0
        fi
    fi
    
    # Manual entry
    print_warning "Could not retrieve join command automatically"
    print_info "Run this on the master: sudo kubeadm token create --print-join-command"
    read -p "Enter the join command: " JOIN_COMMAND
    
    if [ -z "$JOIN_COMMAND" ]; then
        error_exit "Join command is required"
    fi
}

join_cluster() {
    print_header "Joining Kubernetes Cluster"
    
    print_info "Executing join command..."
    echo -e "${YELLOW}$JOIN_COMMAND${NC}"
    
    if eval "$JOIN_COMMAND"; then
        print_success "Successfully joined the cluster!"
    else
        error_exit "Failed to join cluster"
    fi
    
    sleep 5
    systemctl restart kubelet
    print_success "Kubelet restarted"
}

verify_setup() {
    print_header "Verifying Setup"
    
    # Check kubelet.conf
    if [ -f /etc/kubernetes/kubelet.conf ]; then
        print_success "kubelet.conf created"
    else
        print_error "kubelet.conf not found"
    fi
    
    # Check containers
    CONTAINER_COUNT=$(crictl ps 2>/dev/null | grep -v CONTAINER | wc -l || echo 0)
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        print_success "Found $CONTAINER_COUNT running containers"
    else
        print_warning "No containers running yet"
    fi
    
    print_info "Verify from master: kubectl get nodes"
}

################################################################################
# MAIN
################################################################################

main() {
    print_header "Kubernetes Worker Full Setup"
    
    read -p "Start setup? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    install_k8s_components
    get_join_command
    join_cluster
    verify_setup
    
    print_success "Worker setup complete!"
    print_info "Worker: $(hostname) @ $(hostname -I | awk '{print $1}')"
}

main "$@"
