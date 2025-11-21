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
# Install Docker (needed for Jenkins Agent to build images)
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# Generate default config and configure SystemdCgroup
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# CRITICAL FIX: Ensure SystemdCgroup is true (already present, but confirmed here)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
# FIX: Set the correct sandbox image for Kubernetes v1.31+
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.6"|sandbox_image = "registry.k8s.io/pause:3.10"|g' /etc/containerd/config.toml


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

# --- 9. Prepare for Join ---
echo "[Step 9] Preparing Node for Join..."

# Check for partial initialization (Port 10250 in use)
if netstat -tuln | grep :10250 >/dev/null; then
    echo "WARN: Port 10250 is in use. Resetting kubeadm to ensure clean state..."
    sudo kubeadm reset -f || true
    sudo rm -rf /etc/cni/net.d
    sudo rm -rf /var/lib/etcd
    sudo rm -rf /var/lib/kubelet
fi

echo ""
echo "=== WORKER SETUP COMPLETE ==="
echo "This node is now ready to join the cluster."
echo "Run the 'kubeadm join' command from the Master node here (using sudo)."