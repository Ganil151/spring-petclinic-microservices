#!/bin/bash
# Using 'set -ex' ensures all commands are echoed and exit immediately on failure.
set -ex

echo "=== Starting Kubernetes Worker Setup ==="

# --- 1. Configure Hostname & Local DNS Resolution ---
echo "[Step 1] Configuring Hostname..."
NEW_HOSTNAME="K8s-Worker-Server"
hostnamectl set-hostname ${NEW_HOSTNAME}

# FIX: Add the new hostname to /etc/hosts to resolve local lookups
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "${PRIVATE_IP} ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts
echo "127.0.0.1   ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts

# --- 2. Update & Install Dependencies ---
echo "[Step 2] Installing Dependencies..."
# Using sudo dnf is more explicit for Amazon Linux 2023
sudo dnf update -y
# FIX: Added 'conntrack' to solve the "[ERROR FileExisting-conntrack]" failure
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
# Use the safe substitution command for fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# --- 5. Configure SELinux ---
echo "[Step 5] Setting SELinux to Permissive..."
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# --- 6. Install & Configure Container Runtime (Containerd) ---
echo "[Step 6] Installing and Configuring Containerd..."
sudo dnf install -y containerd

# Generate default config and configure SystemdCgroup
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# CRITICAL FIX: Ensure SystemdCgroup is true (already present, but confirmed here)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl enable --now containerd
sudo systemctl restart containerd

# --- 7. Configure Kubernetes Repository ---
echo "[Step 7] Adding Kubernetes Repository..."
# Explicitly define the repo file
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# --- 8. Install Kubernetes ---
echo "[Step 8] Installing Kubelet, Kubeadm, Kubectl..."
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# --- 9. Initialize Cluster (Master Node Only) ---
echo "[Step 9] Initializing Kubernetes Cluster..."

# Check if cluster is already running to prevent errors
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "Cluster already initialized. Skipping kubeadm init."
else
    # The kubeadm init command MUST be run as root
    # Using 'sudo' here ensures the command runs with the required privileges.
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU
fi

# --- 10. Configure Kubectl for the standard user ---
echo "[Step 10] Configuring kubectl..."
# This step does NOT require sudo, but operates on user's home directory.
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# --- 11. Install Pod Network (Calico) ---
echo "[Step 11] Installing Calico Network Plugin..."
# kubectl commands use the configuration file created in Step 10 and do not require sudo.
if ! kubectl get deployment tigera-operator -n calico-system >/dev/null 2>&1; then
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
fi
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# --- 12. Generate Join Script ---
echo "[Step 12] Generating Worker Join Script..."
# We generate the join command with 'sudo' prepended so the worker can just run the output.
sudo kubeadm token create --print-join-command > /root/k8s_join_command.sh
chmod +x /root/k8s_join_command.sh

echo ""
echo "=== MASTER SETUP COMPLETE ==="
echo "To check the cluster status: kubectl get nodes"
echo "Run the following command on your Worker Nodes to join the cluster:"
cat /root/k8s_join_command.sh

echo ""
echo "=== WORKER READY TO JOIN ==="
echo "Now copy the 'kubeadm join' command from the K8s-Master node and run it here (using sudo)."
echo "Example command structure: sudo kubeadm join <MASTER_IP>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"