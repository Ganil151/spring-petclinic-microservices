# Kubernetes Worker Server Commands Reference

Complete command reference for managing and troubleshooting Kubernetes worker nodes.

---

## 📋 Table of Contents

- [Initial Setup](#initial-setup)
- [Joining the Cluster](#joining-the-cluster)
- [Node Management](#node-management)
- [Container Management](#container-management)
- [Troubleshooting](#troubleshooting)
- [System Verification](#system-verification)
- [Maintenance](#maintenance)

---

## Initial Setup

### Check Prerequisites

```bash
# Verify swap is disabled
sudo swapon --show
# Should return nothing

# Verify containerd is running
sudo systemctl status containerd

# Verify kubelet is installed
kubelet --version

# Verify kubeadm is installed
kubeadm version
```

### Install Kubernetes Components (if not installed)

```bash
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Clean cache
sudo dnf clean all

# Install kubeadm and kubelet
sudo dnf install -y kubelet kubeadm --disableexcludes=kubernetes

# Enable and start kubelet
sudo systemctl enable --now kubelet
```

---

## Joining the Cluster

### Get Join Command from Master

**On Master Node:**
```bash
sudo kubeadm token create --print-join-command
```

**Example Output:**
```
kubeadm join 10.0.1.100:6443 --token abc123.xyz789 --discovery-token-ca-cert-hash sha256:abc123...
```

### Join the Cluster

**On Worker Node:**
```bash
# Use the command from master (add sudo)
sudo kubeadm join <master-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

### Verify Join Success

```bash
# Check if kubelet.conf was created
ls -la /etc/kubernetes/kubelet.conf

# Check kubelet status
sudo systemctl status kubelet

# View kubelet logs
sudo journalctl -u kubelet -f
```

---

## Node Management

### Check Node Status

```bash
# Check kubelet service
sudo systemctl status kubelet

# Restart kubelet
sudo systemctl restart kubelet

# Enable kubelet on boot
sudo systemctl enable kubelet

# View kubelet logs (real-time)
sudo journalctl -u kubelet -f

# View last 100 lines of kubelet logs
sudo journalctl -u kubelet -n 100 --no-pager
```

### Reset Worker Node

```bash
# Reset the node (removes from cluster)
sudo kubeadm reset -f

# Clean up directories
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /etc/kubernetes/*

# Restart kubelet
sudo systemctl restart kubelet

# Now you can rejoin the cluster
```

---

## Container Management

### Using crictl (Container Runtime Interface)

```bash
# List running containers
sudo crictl ps

# List all containers (including stopped)
sudo crictl ps -a

# List images
sudo crictl images

# View container logs
sudo crictl logs <container-id>

# Inspect a container
sudo crictl inspect <container-id>

# List pods
sudo crictl pods

# View pod details
sudo crictl inspectp <pod-id>

# Execute command in container
sudo crictl exec -it <container-id> /bin/sh
```

### Using Docker (if installed for Jenkins)

```bash
# List Docker containers
sudo docker ps

# View Docker logs
sudo docker logs <container-name>

# Check Docker status
sudo systemctl status docker
```

---

## Troubleshooting

### Common Issues

#### Kubelet Not Starting

```bash
# Check kubelet status
sudo systemctl status kubelet

# View detailed logs
sudo journalctl -u kubelet -xe

# Common fixes:
sudo swapoff -a                    # Disable swap
sudo systemctl restart containerd  # Restart containerd
sudo systemctl restart kubelet     # Restart kubelet
```

#### Node Not Ready

```bash
# Check kubelet logs for CNI errors
sudo journalctl -u kubelet | grep -i cni

# Check if CNI plugins are installed
ls -la /opt/cni/bin/

# Check CNI configuration
ls -la /etc/cni/net.d/

# Restart kubelet
sudo systemctl restart kubelet
```

#### Container Runtime Issues

```bash
# Check containerd status
sudo systemctl status containerd

# Restart containerd
sudo systemctl restart containerd

# View containerd logs
sudo journalctl -u containerd -f

# Check containerd config
sudo cat /etc/containerd/config.toml
```

#### Network Issues

```bash
# Check network interfaces
ip addr show

# Check routing table
ip route show

# Test connectivity to master
ping <master-ip>

# Check if port 10250 is listening (kubelet)
sudo netstat -tulpn | grep 10250

# Check firewall status
sudo firewall-cmd --list-all
```

---

## System Verification

### Verify System Configuration

```bash
# Check hostname
hostname
hostnamectl

# Check IP address
hostname -I

# Verify swap is disabled
free -h
sudo swapon --show

# Check SELinux status
getenforce

# Verify kernel modules
lsmod | grep br_netfilter
lsmod | grep overlay

# Check sysctl settings
sudo sysctl net.bridge.bridge-nf-call-iptables
sudo sysctl net.ipv4.ip_forward
```

### Check Kubernetes Components

```bash
# Check kubeadm version
kubeadm version

# Check kubelet version
kubelet --version

# Check containerd version
containerd --version

# Check crictl version
crictl --version
```

### Verify Certificates

```bash
# Check kubelet certificates
sudo ls -la /var/lib/kubelet/pki/

# Check if kubelet.conf exists
sudo ls -la /etc/kubernetes/kubelet.conf

# View certificate expiration
sudo kubeadm certs check-expiration
```

---

## Maintenance

### Update Kubernetes Components

```bash
# Check available versions
sudo dnf list --showduplicates kubeadm --disableexcludes=kubernetes

# Upgrade kubeadm
sudo dnf install -y kubeadm-1.31.x --disableexcludes=kubernetes

# Upgrade kubelet
sudo dnf install -y kubelet-1.31.x --disableexcludes=kubernetes

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Clean Up Resources

```bash
# Remove unused container images
sudo crictl rmi --prune

# Clean up stopped containers
sudo crictl rm $(sudo crictl ps -a -q --state=exited)

# Clean DNF cache
sudo dnf clean all
```

### Backup Important Files

```bash
# Backup kubelet configuration
sudo cp /etc/kubernetes/kubelet.conf /backup/kubelet.conf.bak

# Backup containerd configuration
sudo cp /etc/containerd/config.toml /backup/config.toml.bak
```

---

## Quick Reference Commands

### Most Used Commands

```bash
# Check kubelet status
sudo systemctl status kubelet

# View kubelet logs
sudo journalctl -u kubelet -f

# List running containers
sudo crictl ps

# Restart kubelet
sudo systemctl restart kubelet

# Reset node
sudo kubeadm reset -f

# Join cluster
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### Emergency Commands

```bash
# Force stop kubelet
sudo systemctl stop kubelet

# Kill all kubelet processes
sudo pkill -9 kubelet

# Restart containerd
sudo systemctl restart containerd

# Reboot the server
sudo reboot
```

---

## 📝 Notes

- **Worker nodes don't have kubectl** - Use master node for cluster management
- **Always use sudo** for Kubernetes commands on worker nodes
- **Check logs first** when troubleshooting issues
- **Restart kubelet** after configuration changes
- **Verify from master** using `kubectl get nodes` after making changes

---

## 🔗 Related Documentation

- [Worker Setup Scripts](./WORKER_SCRIPTS_FIXES.md)
- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Troubleshooting Guide](https://kubernetes.io/docs/tasks/debug/)
