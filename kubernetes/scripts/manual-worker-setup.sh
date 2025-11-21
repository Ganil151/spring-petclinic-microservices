#!/bin/bash
# manual-worker-setup.sh
# Run this script on the K8s-Worker-Server to manually install Kubernetes components
# This is needed if the Terraform user_data script didn't complete successfully

set -ex

echo "=== Manual Kubernetes Worker Setup ==="

# --- 1. Configure Hostname & Local DNS Resolution ---
echo "[Step 1] Configuring Hostname..."
NEW_HOSTNAME="K8s-Worker-Server"
sudo hostnamectl set-hostname ${NEW_HOSTNAME}

# Add the new hostname to /etc/hosts
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "${PRIVATE_IP} ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts
echo "127.0.0.1   ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts

# --- 2. Update & Install Dependencies ---
echo "[Step 2] Installing Dependencies..."
sudo dnf update -y
sudo dnf install -y wget iproute-tc conntrack

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
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# --- 6. Install & Configure Container Runtime (Containerd) ---
echo "[Step 6] Installing and Configuring Containerd..."
sudo dnf install -y containerd docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Configure SystemdCgroup and sandbox image
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.6"|sandbox_image = "registry.k8s.io/pause:3.10"|g' /etc/containerd/config.toml

sudo systemctl enable --now containerd
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

# --- 8. Install Kubernetes ---
echo "[Step 8] Installing Kubelet, Kubeadm, Kubectl..."
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# --- 9. Prepare for Join ---
echo "[Step 9] Preparing Node for Join..."

# Check for partial initialization
if netstat -tuln 2>/dev/null | grep :10250 >/dev/null; then
    echo "WARN: Port 10250 is in use. Resetting kubeadm..."
    sudo kubeadm reset -f || true
    sudo rm -rf /etc/cni/net.d
    sudo rm -rf /var/lib/etcd
    sudo rm -rf /var/lib/kubelet
fi

echo ""
echo "=== WORKER SETUP COMPLETE ==="
echo "Verify installation:"
echo "  kubeadm version"
echo "  kubelet --version"
echo ""
echo "Now you can run the join command from the master node."
