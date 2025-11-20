#!/bin/bash
set -e

echo "=== Starting Kubernetes Master Setup ==="

# --- 1. Configure Hostname & Local DNS Resolution ---
echo "[Step 1] Configuring Hostname..."
NEW_HOSTNAME="K8s-Master-Server"
hostnamectl set-hostname ${NEW_HOSTNAME}

# FIX: Add the new hostname to /etc/hosts to resolve the lookup error
# We map it to the private IP of the instance
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "${PRIVATE_IP} ${NEW_HOSTNAME}" >> /etc/hosts
echo "127.0.0.1   ${NEW_HOSTNAME}" >> /etc/hosts

# --- 2. Update & Install Dependencies ---
echo "[Step 2] Installing Dependencies..."
sudo dnf update -y
# FIX: Added 'conntrack' (required by kubeadm) and 'iproute-tc' (traffic control)
sudo dnf install -y wget iproute-tc conntrack

# --- 3. Configure Kernel Modules & Sysctl ---
echo "[Step 3] Configuring Kernel Modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl params for K8s networking
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
sudo dnf install -y containerd
sudo systemctl enable --now containerd

# Generate default config and configure SystemdCgroup
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl restart containerd

# --- 7. Configure Kubernetes Repository ---
echo "[Step 7] Adding Kubernetes Repository..."
# Note: Using v1.31 repository
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
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

# --- 9. Initialize Cluster (Master Node Only) ---
echo "[Step 9] Initializing Kubernetes Cluster..."

# Check if cluster is already running to prevent errors
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "Cluster already initialized. Skipping kubeadm init."
else
    # FIX: Removed '--kubernetes-version' flag. 
    # Letting kubeadm detect the installed version prevents "remote version is much newer" warnings.
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU
fi

# --- 10. Configure Kubectl for Root User ---
echo "[Step 10] Configuring kubectl..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# --- 11. Install Pod Network (Calico) ---
echo "[Step 11] Installing Calico Network Plugin..."
# [Image of Calico network diagram]
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# --- 12. Generate Join Script ---
echo "[Step 12] Generating Worker Join Script..."
kubeadm token create --print-join-command > /root/k8s_join_command.sh
chmod +x /root/k8s_join_command.sh

echo ""
echo "=== MASTER SETUP COMPLETE ==="
echo "Run the following command on your Worker Nodes to join the cluster:"
cat /root/k8s_join_command.sh