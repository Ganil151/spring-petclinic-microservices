#!/bin/bash
set -e

echo "=== Starting Kubernetes Worker Setup ==="

# --- 1. Configure Hostname ---
NEW_HOSTNAME="K8s-Worker-Server"
hostnamectl set-hostname ${NEW_HOSTNAME}

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "${PRIVATE_IP} ${NEW_HOSTNAME}" >> /etc/hosts

# --- 2. Install Dependencies ---
dnf update -y
dnf install -y wget iproute-tc conntrack

# --- 3. Kernel Modules ---
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

# --- 4. Disable Swap ---
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# --- 5. SELinux ---
setenforce 0 || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# --- 6. Install Containerd ---
dnf install -y containerd
systemctl enable --now containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i 's|pause:3.6|pause:3.10|' /etc/containerd/config.toml

systemctl restart containerd

# Configure kubelet to use containerd
mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF | tee /etc/systemd/system/kubelet.service.d/10-containerd.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

systemctl daemon-reload

# --- 7. Kubernetes Repo ---
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# --- 8. Install Kubeadm / Kubelet (kubectl not needed on worker) ---
dnf install -y kubelet kubeadm --disableexcludes=kubernetes
systemctl enable --now kubelet

# --- 9. Clean Old State (Safe) ---
rm -rf /etc/cni/net.d/* /var/lib/kubelet/*

echo ""
echo "=== WORKER SETUP COMPLETE ==="
echo "Run the join command from the master node:"
echo "Example:"
echo "  sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo ""
