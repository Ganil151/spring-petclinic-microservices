#!/bin/bash
# Kubernetes Installation Diagnostic and Fix Script
# Run this on K8s Master to diagnose and fix installation issues

set -e

echo "=========================================="
echo "Kubernetes Installation Diagnostic"
echo "=========================================="
echo ""

# Check if commands exist
echo "1. Checking if Kubernetes binaries are installed..."
if command -v kubeadm &>/dev/null; then
    echo "✓ kubeadm is installed: $(kubeadm version -o short)"
else
    echo "✗ kubeadm is NOT installed"
fi

if command -v kubelet &>/dev/null; then
    echo "✓ kubelet is installed: $(kubelet --version)"
else
    echo "✗ kubelet is NOT installed"
fi

if command -v kubectl &>/dev/null; then
    echo "✓ kubectl is installed: $(kubectl version --client -o yaml | grep gitVersion)"
else
    echo "✗ kubectl is NOT installed"
fi
echo ""

# Check systemd services
echo "2. Checking systemd services..."
if systemctl list-unit-files | grep -q kubelet; then
    echo "✓ kubelet service exists"
    systemctl status kubelet --no-pager || true
else
    echo "✗ kubelet service does NOT exist"
fi
echo ""

# Check repository
echo "3. Checking Kubernetes repository..."
if [ -f /etc/yum.repos.d/kubernetes.repo ]; then
    echo "✓ Kubernetes repo file exists"
    cat /etc/yum.repos.d/kubernetes.repo
else
    echo "✗ Kubernetes repo file does NOT exist"
fi
echo ""

# Check if packages are available
echo "4. Checking if packages are available in repo..."
sudo dnf list available kubelet kubeadm kubectl --disableexcludes=kubernetes 2>&1 || echo "Packages not available"
echo ""

# Check installation logs
echo "5. Checking recent dnf logs..."
sudo grep -i "kubelet\|kubeadm\|kubectl" /var/log/dnf.log | tail -20 || echo "No installation logs found"
echo ""

echo "=========================================="
echo "Diagnosis Complete"
echo "=========================================="
echo ""

# Offer to fix
read -p "Do you want to attempt to fix the installation? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "=========================================="
    echo "Fixing Kubernetes Installation"
    echo "=========================================="
    echo ""
    
    # Step 1: Clean up any partial installation
    echo "[Step 1] Cleaning up any partial installation..."
    sudo dnf remove -y kubelet kubeadm kubectl 2>/dev/null || true
    sudo rm -rf /etc/kubernetes
    sudo rm -rf /var/lib/kubelet
    sudo rm -rf /var/lib/etcd
    echo ""
    
    # Step 2: Add repository
    echo "[Step 2] Adding Kubernetes repository..."
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    echo ""
    
    # Step 3: Clean dnf cache
    echo "[Step 3] Cleaning dnf cache..."
    sudo dnf clean all
    sudo dnf makecache
    echo ""
    
    # Step 4: Install Kubernetes components
    echo "[Step 4] Installing Kubernetes components..."
    sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    echo ""
    
    # Step 5: Enable and start kubelet
    echo "[Step 5] Enabling kubelet service..."
    sudo systemctl enable kubelet
    sudo systemctl start kubelet || echo "Note: kubelet will fail until cluster is initialized (this is normal)"
    echo ""
    
    # Step 6: Verify installation
    echo "[Step 6] Verifying installation..."
    echo "kubeadm version:"
    kubeadm version -o short
    echo ""
    echo "kubelet version:"
    kubelet --version
    echo ""
    echo "kubectl version:"
    kubectl version --client --short
    echo ""
    
    echo "=========================================="
    echo "Fix Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Initialize the cluster: sudo kubeadm init --pod-network-cidr=192.168.0.0/16"
    echo "2. Configure kubectl: mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config"
    echo "3. Install Calico: kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml"
fi
