#!/bin/bash

#############################################
# K3s Server Installation Script
# Simplified version - stores IP in file
#############################################

set -euo pipefail

# Logging setup
LOG_FILE="/var/log/k3s-installation.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "K3s Server Installation"
echo "=========================================="
echo ""
date
echo ""

# Configuration variables
K3S_VERSION="v1.28.5+k3s1"
INSTALL_DIR="/opt/k3s-setup"

# Create installation directory
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

#############################################
# System Preparation
#############################################

echo "=== Step 1: System Preparation ==="

# Update system packages
echo "Updating system packages..."
sudo dnf update -y

# Install required packages (with --allowerasing to handle curl conflicts)
echo "Installing required packages..."
sudo dnf install -y --allowerasing \
    curl \
    wget \
    git \
    jq \
    vim \
    net-tools \
    bind-utils \
    tar \
    unzip

# Verify curl is installed
curl --version || {
    echo "ERROR: curl installation failed"
    exit 1
}

# Disable SELinux
echo "Configuring SELinux..."
sudo setenforce 0 2>/dev/null || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Disable swap
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
echo "Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl for Kubernetes
echo "Configuring sysctl parameters..."
cat <<EOF | sudo tee /etc/sysctl.d/k3s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "✓ System preparation complete"
echo ""

#############################################
# K3s Installation
#############################################

echo "=== Step 2: Installing K3s ==="

# Get IPs
EXTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
INTERNAL_IP=$(hostname -I | awk '{print $1}')

echo "External IP: $EXTERNAL_IP"
echo "Internal IP: $INTERNAL_IP"

# Install K3s with production settings
echo "Installing K3s $K3S_VERSION..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --disable servicelb \
    --node-name k3s-server \
    --node-ip "$INTERNAL_IP" \
    --cluster-init \
    --tls-san "$EXTERNAL_IP" \
    --tls-san "$INTERNAL_IP" \
    --kube-apiserver-arg "service-node-port-range=30000-32767"

# Wait for K3s to be ready
echo ""
echo "Waiting for K3s to be ready..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet k3s; then
        echo "✓ K3s service is active"
        break
    fi
    echo "Waiting for K3s service... ($i/30)"
    sleep 2
done

echo "✓ K3s installation complete"
echo ""

#############################################
# kubectl Configuration
#############################################

echo "=== Step 3: Configuring kubectl ==="

# Configure kubectl for ec2-user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Update kubeconfig to use external IP if available
if [ -n "$EXTERNAL_IP" ]; then
    sed -i "s/127.0.0.1/$EXTERNAL_IP/g" ~/.kube/config
fi

# Add kubectl completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc

# Verify kubectl
echo ""
echo "Verifying kubectl configuration..."
kubectl version --short 2>/dev/null || kubectl version
echo ""
kubectl get nodes -o wide

echo "✓ kubectl configured"
echo ""

#############################################
# Install Essential Components
#############################################

echo "=== Step 4: Installing Essential Components ==="

# Install Helm
echo "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Install metrics-server
echo ""
echo "Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server for K3s
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for metrics-server
echo "Waiting for metrics-server to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/metrics-server -n kube-system || true

echo "✓ Essential components installed"
echo ""

#############################################
# Clone Spring Petclinic Repository
#############################################

echo "=== Step 5: Cloning Spring Petclinic Repository ==="

REPO_DIR="$HOME/spring-petclinic-microservices"

if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning Spring Petclinic repository..."
    git clone https://github.com/spring-petclinic/spring-petclinic-microservices.git "$REPO_DIR"
    echo "✓ Repository cloned to $REPO_DIR"
else
    echo "Repository already exists at $REPO_DIR"
fi

echo ""

#############################################
# Save Cluster Information
#############################################

echo "=== Step 6: Saving Cluster Information ==="

# Save K3s token
sudo cat /var/lib/rancher/k3s/server/node-token > ~/k3s-token.txt
chmod 600 ~/k3s-token.txt

# Save server IP to shared location (for agents)
echo "$INTERNAL_IP" | sudo tee /var/lib/rancher/k3s/server-ip.txt
sudo chmod 644 /var/lib/rancher/k3s/server-ip.txt

# Create cluster info file
cat > ~/k3s-cluster-info.txt <<EOF
K3s Cluster Information
=======================
Installation Date: $(date)
K3s Version: $K3S_VERSION

Server Details:
  External IP: $EXTERNAL_IP
  Internal IP: $INTERNAL_IP
  Node Name: k3s-server

Access Information:
  Kubeconfig: ~/.kube/config
  Node Token: ~/k3s-token.txt
  Server IP File: /var/lib/rancher/k3s/server-ip.txt

Useful Commands:
  kubectl get nodes
  kubectl get pods -A
  kubectl top nodes
  kubectl top pods -A

Add Worker Node:
  On worker, run:
  export K3S_SERVER_IP="$INTERNAL_IP"
  export K3S_TOKEN="\$(cat ~/k3s-token.txt)"
  curl -sfL https://get.k3s.io | K3S_URL=https://\${K3S_SERVER_IP}:6443 K3S_TOKEN=\${K3S_TOKEN} sh -

Spring Petclinic:
  Repository: $REPO_DIR
  Deploy: kubectl apply -f $REPO_DIR/kubernetes/deployments/
EOF

chmod 600 ~/k3s-cluster-info.txt

echo "✓ Cluster information saved"
echo ""

#############################################
# Final Verification
#############################################

echo "=== Step 7: Final Verification ==="

echo ""
echo "Cluster nodes:"
kubectl get nodes -o wide

echo ""
echo "System pods:"
kubectl get pods -n kube-system

echo ""

#############################################
# Installation Complete
#############################################

echo "=========================================="
echo "K3s Installation Complete!"
echo "=========================================="
echo ""
echo "Cluster Information:"
echo "  External IP: $EXTERNAL_IP"
echo "  Internal IP: $INTERNAL_IP"
echo "  Kubeconfig: ~/.kube/config"
echo "  Cluster Info: ~/k3s-cluster-info.txt"
echo "  Installation Log: $LOG_FILE"
echo ""
echo "Next Steps:"
echo "  1. Deploy Spring Petclinic:"
echo "     cd $REPO_DIR/kubernetes/deployments"
echo "     kubectl apply -f ."
echo ""
echo "  2. Monitor deployment:"
echo "     kubectl get pods -w"
echo ""
echo "=========================================="
echo "Add Worker Nodes"
echo "=========================================="
echo ""
echo "On each worker node, run these commands:"
echo ""
echo "  export K3S_SERVER_IP=\"$INTERNAL_IP\""
echo "  export K3S_TOKEN=\"$(cat ~/k3s-token.txt)\""
echo "  curl -sfL https://get.k3s.io | sh -s - agent"
echo ""
echo "Or copy and paste this single command:"
echo ""
echo "  K3S_URL=https://$INTERNAL_IP:6443 K3S_TOKEN=$(cat ~/k3s-token.txt) curl -sfL https://get.k3s.io | sh -"
echo ""
echo "=========================================="

