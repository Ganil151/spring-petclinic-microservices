#!/bin/bash
set -e

# Define Kubernetes version for initialization (Must match repo version in Step 7)
K8S_VERSION="v1.31.0"

echo "=== Starting Kubernetes Master Setup (Version ${K8S_VERSION}) ==="

# --- 1. Configure Hostname & Local DNS Resolution ---
echo "[Step 1] Configuring Hostname..."
NEW_HOSTNAME="K8s-Master-Server"
echo "Setting hostname to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# Get the primary private IP address
PRIVATE_IP=$(hostname -I | awk '{print $1}')
# Append IP and hostname to /etc/hosts for local resolution
if ! sudo grep -q "${NEW_HOSTNAME}" /etc/hosts; then
    echo "${PRIVATE_IP} ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts
    echo "Added ${NEW_HOSTNAME} to /etc/hosts."
else
    echo "Hostname already present in /etc/hosts. Skipping modification."
fi

# --- 2. Update & Install Dependencies ---
echo "[Step 2] Installing Dependencies..."
sudo yum update -y
sudo yum install -y wget iproute-tc conntrack

# --- 3. Configure Kernel Modules & Sysctl ---
echo "[Step 3] Configuring Kernel Modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# --- 4. Disable Swap ---
echo "[Step 4] Disabling Swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "Swap disabled."

# --- 5. Configure SELinux ---
echo "[Step 5] Setting SELinux to Permissive..."
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
echo "SELinux set to permissive mode."

# --- 6. Install & Configure Container Runtime (Containerd) ---
echo "[Step 6] Installing Containerd and setting systemd cgroup driver..."
sudo yum install -y containerd
sudo systemctl enable --now containerd

# Verify containerd is running
if sudo systemctl is-active --quiet containerd; then
    echo "✓ Containerd service started successfully."
else
    echo "✗ ERROR: Containerd service failed to start."
    exit 1
fi

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Set SystemdCgroup = true for kubelet compatibility
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Set the pause image (usually auto-managed by kubelet, but good practice to set a compatible one)
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.6"|sandbox_image = "registry.k8s.io/pause:3.10"|g' /etc/containerd/config.toml

echo "Restarting containerd with updated configuration..."
sudo systemctl restart containerd

# Verify containerd restarted successfully
if sudo systemctl is-active --quiet containerd; then
    echo "✓ Containerd restarted successfully with updated config."
else
    echo "✗ ERROR: Containerd failed to restart."
    exit 1
fi

# --- 7. Configure Kubernetes Repository ---
echo "[Step 7] Adding Kubernetes Repository (v1.31)..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# --- 8. Install Kubernetes Components ---
echo "[Step 8] Installing Kubeadm, Kubelet, Kubectl..."
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
echo "K8s components installed and Kubelet enabled."

# --- 9. Initialize Cluster (Master Node Only) ---
echo "[Step 9] Initializing Kubernetes Cluster..."

if [ -f /etc/kubernetes/admin.conf ]; then
    echo "Cluster already initialized. Skipping kubeadm init."
else
    # Check if a stale instance is running
    if sudo netstat -tuln | grep :10250 >/dev/null; then
        echo "WARN: Port 10250 in use but admin.conf missing. Resetting..."
        sudo kubeadm reset -f || true
        sudo rm -rf /etc/cni/net.d /var/lib/etcd /var/lib/kubelet
    fi
    
    # Initialize the cluster, specifying version and CNI CIDR for Calico
    # 
    sudo kubeadm init \
        --kubernetes-version=${K8S_VERSION} \
        --pod-network-cidr=192.168.0.0/16 \
        --ignore-preflight-errors=NumCPU
    echo "Cluster initialized."
fi

# --- 10. Configure Kubectl for Root User ---
echo "[Step 10] Configuring kubectl for root user..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
echo "kubectl config setup completed."

# --- 11. Install Calico Network Plugin ---
echo "[Step 11] Installing Calico Network Plugin (v3.27.2)..."

# Check if Calico is already installed
if kubectl get namespace calico-system &>/dev/null; then
    echo "Calico already installed. Skipping CNI installation."
else
    # Install Tigera Operator using server-side apply to avoid annotation size limits
    echo "Installing Tigera Operator..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml --save-config || \
    kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
    
    # Wait for operator to be ready
    echo "Waiting for Tigera operator (up to 120 seconds)..."
    kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator || true
    
    # Apply custom resources which trigger Calico deployment (using server-side apply)
    echo "Installing Calico custom resources..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml --save-config || \
    kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml
    
    echo "Calico installation initiated. Pods will start in 2-3 minutes."
fi

# --- 12. Generate Join Command ---
echo "[Step 12] Generating Worker Join Command..."

# Save the current join command to a file
JOIN_CMD_FILE="/root/k8s_join_command.sh"
sudo kubeadm token create --print-join-command > "${JOIN_CMD_FILE}"
sudo chmod +x "${JOIN_CMD_FILE}"

echo "Join command saved to: ${JOIN_CMD_FILE}"
echo "Transfer this file to worker nodes and execute it with sudo."

# --- 13. /tmp Filesystem Tuning ---
echo "[Step 13] Configuring /tmp filesystem..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully with 1.5GB size."
else
    echo "WARNING: Failed to remount /tmp immediately. A system reboot is required for the change to take full effect."
fi

# --- 14. Node Labeling and Role Assignment ---
echo "[Step 14] Configuring node labels and roles..."
echo "Waiting for nodes to be ready before applying labels..."

# Wait a bit for the master node to be fully ready
sleep 10

# Label the master node with its role
echo "Applying role label to master node..."
kubectl label node ${NEW_HOSTNAME} node-role.kubernetes.io/control-plane=control-plane --overwrite || true
kubectl label node ${NEW_HOSTNAME} node.kubernetes.io/role=control-plane --overwrite || true

echo ""
echo "=== MASTER SETUP COMPLETE ==="
echo ""
echo "✓ Kubernetes v${K8S_VERSION} master node initialized"
echo "✓ Calico CNI is installing. Check with: kubectl get pods -n calico-system"
echo "✓ Join command saved to: ${JOIN_CMD_FILE}"
echo ""
echo "IMPORTANT - Node Labeling Instructions:"
echo "=========================================="
echo "After worker nodes join the cluster, apply labels to assign roles:"
echo ""
echo "For K8s-primary-agent (Agent 1):" 
echo "  kubectl label node K8s-Worker-Server node-role.kubernetes.io/worker=worker"
echo "  kubectl label node K8s-Worker-Server node.kubernetes.io/role=K8s-primary-agent"
echo ""
echo "For K8s-secondary-agent (Agent 2):"
echo "  kubectl label node K8s-Agent-2-Server node-role.kubernetes.io/worker=worker"
echo "  kubectl label node K8s-Agent-2-Server node.kubernetes.io/role=K8s-secondary-agent"
echo ""
echo "To verify node labels:"
echo "  kubectl get nodes --show-labels"
echo ""
echo "To get the join command for workers:"
echo "  cat ${JOIN_CMD_FILE}"
echo ""