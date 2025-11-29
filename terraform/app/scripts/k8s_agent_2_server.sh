#!/bin/bash
set -e

echo "=== Starting Kubernetes Agent 2 Server Setup ==="

# --- 1. Configure Hostname ---
NEW_HOSTNAME="K8s-Agent-2-Server"
echo "Setting hostname to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# Add to /etc/hosts if not already present
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
if ! sudo grep -q "${NEW_HOSTNAME}" /etc/hosts; then
    echo "${PRIVATE_IP} ${NEW_HOSTNAME}" | sudo tee -a /etc/hosts
else
    echo "Hostname already in /etc/hosts"
fi

# --- 2. Install Dependencies ---
echo "Installing system dependencies..."
sudo dnf update -y
sudo dnf install -y wget iproute-tc conntrack

# --- 3. Kernel Modules ---
echo "Configuring kernel modules for Kubernetes..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Configuring network settings..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.rp_filter         = 0
net.ipv4.conf.default.rp_filter     = 0
EOF

sudo sysctl --system

# --- 4. Disable Swap ---
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- 5. SELinux ---
echo "Configuring SELinux to permissive mode..."
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# --- 6. Install Containerd ---
echo "Installing and configuring containerd..."
sudo dnf install -y containerd
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
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's|pause:3.6|pause:3.10|' /etc/containerd/config.toml

echo "Restarting containerd with updated configuration..."
sudo systemctl restart containerd

# Verify containerd restarted successfully
if sudo systemctl is-active --quiet containerd; then
    echo "✓ Containerd restarted successfully with updated config."
else
    echo "✗ ERROR: Containerd failed to restart."
    exit 1
fi

# Configure kubelet to use containerd
echo "Configuring kubelet for containerd runtime..."
sudo mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/10-containerd.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

sudo systemctl daemon-reload

# --- 7. Kubernetes Repo ---
echo "Adding Kubernetes repository..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# --- 8. Install Kubeadm / Kubelet (kubectl not needed on worker) ---
echo "Installing Kubernetes components (kubelet, kubeadm)..."
sudo dnf install -y kubelet kubeadm --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

echo "Note: kubelet will be in a crash loop until the node joins the cluster. This is expected."

# --- 9. Clean Old State (Safe) ---
echo "Cleaning old state..."
sudo rm -rf /etc/cni/net.d/* /var/lib/kubelet/*

# --- 10. /tmp Filesystem Tuning ---
echo "Configuring /tmp filesystem..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully with 1.5GB size."
else
    echo "WARNING: Failed to remount /tmp immediately. A system reboot is required for the change to take full effect."
fi

echo ""
echo "=== K8s SECONDARY AGENT (Agent 2) SETUP COMPLETE ==="
echo ""
echo "NEXT STEPS:"
echo "============"
echo "1. Get the join command from the master node:"
echo "   ssh master-node 'sudo kubeadm token create --print-join-command'"
echo ""
echo "2. Execute the join command on this node:"
echo "   Example: sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo ""
echo "3. After joining, apply node labels FROM THE MASTER:"
echo "   kubectl label node ${NEW_HOSTNAME} node-role.kubernetes.io/worker=worker"
echo "   kubectl label node ${NEW_HOSTNAME} node.kubernetes.io/role=K8s-secondary-agent"
echo ""
echo "4. Verify the node joined successfully:"
echo "   kubectl get nodes"
echo ""
