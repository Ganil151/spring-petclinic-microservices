#!/usr/bin/env bash
# install_kube_worker_amzlinux2023.sh
# Prepares an Amazon Linux 2023 worker node for joining a kubeadm cluster.

set -euo pipefail

echo "[1/7] Installing system dependencies..."
sudo yum -y upgrade
sudo yum -y install jq iproute iproute-tc iptables containerd wget conntrack

echo "[2/7] Load kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "[3/7] Configure containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# Fix sandbox image for K8s v1.31
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.6"|sandbox_image = "registry.k8s.io/pause:3.10"|g' /etc/containerd/config.toml
sudo systemctl enable --now containerd

echo "[4/7] Disable swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab || true

echo "[5/7] Configure SELinux..."
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config || true

echo "[6/7] Install Kubernetes repo and packages..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Install with --allowerasing to resolve curl conflict
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes --allowerasing
sudo systemctl enable --now kubelet

echo "[7/7] Apply kernel params..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Verify installation
echo ""
echo "Verifying installation..."
kubeadm version
kubelet --version

echo ""
echo "=============================================================="
echo " Worker node setup complete!"
echo " Next step: Get the join command from your master node:"
echo "   ssh ec2-user@<MASTER_IP>"
echo "   kubeadm token create --print-join-command"
echo " Then run it here with sudo."
echo "=============================================================="
