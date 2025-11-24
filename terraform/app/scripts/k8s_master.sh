#!/bin/bash
set -e

echo "=== Starting Kubernetes Master Setup ==="

# --- 1. Configure Hostname & Local DNS Resolution ---
echo "[Step 1] Configuring Hostname..."
NEW_HOSTNAME="K8s-Master-Server"
hostnamectl set-hostname ${NEW_HOSTNAME}

PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "${PRIVATE_IP} ${NEW_HOSTNAME}" >> /etc/hosts

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

# --- 5. Configure SELinux ---
echo "[Step 5] Setting SELinux to Permissive..."
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# --- 6. Install & Configure Container Runtime (Containerd) ---
echo "[Step 6] Installing Containerd..."
sudo yum install -y containerd
sudo systemctl enable --now containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.6"|sandbox_image = "registry.k8s.io/pause:3.10"|g' /etc/containerd/config.toml

sudo systemctl restart containerd

# --- 7. Configure Kubernetes Repository ---
echo "[Step 7] Adding Kubernetes Repository..."
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

# --- 9. Initialize Cluster (Master Node Only) ---
echo "[Step 9] Initializing Kubernetes Cluster..."

if [ -f /etc/kubernetes/admin.conf ]; then
    echo "Cluster already initialized. Skipping kubeadm init."
else
    if netstat -tuln | grep :10250 >/dev/null; then
        echo "WARN: Port 10250 in use but admin.conf missing. Resetting..."
        sudo kubeadm reset -f || true
        sudo rm -rf /etc/cni/net.d /var/lib/etcd /var/lib/kubelet
    fi
    
    # Use 192.168.0.0/16 to match Calico's default
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU
fi

# --- 10. Configure Kubectl for Root User ---
echo "[Step 10] Configuring kubectl..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# --- 11. Install Calico Network Plugin ---
echo "[Step 11] Installing Calico Network Plugin..."

# Check if Calico is already installed
if kubectl get namespace calico-system &>/dev/null; then
    echo "Calico already installed. Skipping."
else
    # Use apply instead of create to be idempotent
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
    
    # Wait for operator to be ready
    echo "Waiting for Tigera operator..."
    kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator || true
    
    # Apply custom resources
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml
    
    echo "Calico installation initiated. Pods will start in 2-3 minutes."
fi

# --- 12. Generate Join Script ---
echo "[Step 12] Generating Worker Join Script..."
cat <<'EOF' > /root/k8s_join_command.sh
#!/bin/bash
set -e

echo "=== Joining Cluster ==="

if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "Node already joined."
    exit 0
fi

if netstat -tuln | grep :10250 >/dev/null; then
    echo "WARN: Resetting node before join..."
    sudo kubeadm reset -f || true
    sudo rm -rf /etc/cni/net.d /var/lib/kubelet
fi

$(kubeadm token create --print-join-command)
EOF
chmod +x /root/k8s_join_command.sh

echo ""
echo "=== MASTER SETUP COMPLETE ==="
echo "Calico will be ready in 2-3 minutes. Check with: kubectl get pods -n calico-system"
echo ""
echo "Worker join command saved to: /root/k8s_join_command.sh"