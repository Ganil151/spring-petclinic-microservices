# K3s vs K8s Comparison and Migration Guide

## Overview

This guide explains the differences between K3s and full Kubernetes (K8s) and provides migration instructions.

## Quick Comparison

| Feature | K8s (kubeadm) | K3s |
|---------|---------------|-----|
| **Installation Time** | 15-30 minutes | 2-5 minutes |
| **Memory Usage** | ~1.5-2GB | ~512MB |
| **Binary Size** | ~1GB | ~60MB |
| **Components** | Separate (etcd, kube-apiserver, etc.) | Single binary |
| **Default Ingress** | None | Traefik (can disable) |
| **Storage** | Manual setup | Local-path provisioner |
| **Load Balancer** | Manual/Cloud | ServiceLB (can disable) |
| **Best For** | Production, multi-node | Development, edge, IoT |

## Why Choose K3s?

### Advantages
- ✅ **Faster setup** - Single command installation
- ✅ **Lower resource usage** - Perfect for development/testing
- ✅ **Simpler management** - Less components to manage
- ✅ **Built-in features** - Ingress, storage, LB included
- ✅ **Same API** - 100% compatible with K8s manifests
- ✅ **Easier upgrades** - Single binary to update

### Disadvantages
- ❌ **Less customizable** - Fewer configuration options
- ❌ **Embedded etcd** - Not suitable for large-scale production
- ❌ **Limited HA options** - Simpler than full K8s HA

## Installation

### 1. K3s Server (Single Node)

```bash
# On your EC2 instance
cd ~/spring-petclinic-microservices/terraform/app/scripts/
chmod +x k3s_server.sh
./k3s_server.sh
```

### 2. K3s Agent (Optional - for multi-node)

```bash
# Get token from server
ssh ec2-user@<server-ip> "sudo cat /var/lib/rancher/k3s/server/node-token"

# On worker node
export K3S_SERVER_IP="<server-ip>"
export K3S_TOKEN="<token-from-above>"
chmod +x k3s_agent.sh
./k3s_agent.sh
```

### 3. Deploy Spring Petclinic

```bash
cd ~/spring-petclinic-microservices/kubernetes/scripts/
chmod +x deploy-to-k3s.sh
./deploy-to-k3s.sh
```

## Migration from K8s to K3s

### Option 1: Fresh Install (Recommended)

1. **Backup current K8s resources**
   ```bash
   # Export all resources
   kubectl get all --all-namespaces -o yaml > k8s-backup.yaml
   kubectl get configmaps --all-namespaces -o yaml > configmaps-backup.yaml
   kubectl get secrets --all-namespaces -o yaml > secrets-backup.yaml
   ```

2. **Install K3s on new instance**
   ```bash
   ./k3s_server.sh
   ```

3. **Deploy applications**
   ```bash
   ./deploy-to-k3s.sh
   ```

### Option 2: In-Place Migration (Advanced)

⚠️ **Warning**: This will destroy your existing K8s cluster!

1. **Backup everything**
   ```bash
   kubectl get all --all-namespaces -o yaml > full-backup.yaml
   ```

2. **Uninstall K8s**
   ```bash
   sudo kubeadm reset -f
   sudo systemctl stop kubelet
   sudo systemctl disable kubelet
   sudo rm -rf /etc/kubernetes/
   sudo rm -rf ~/.kube/
   sudo rm -rf /var/lib/kubelet/
   sudo rm -rf /var/lib/etcd/
   ```

3. **Install K3s**
   ```bash
   ./k3s_server.sh
   ```

4. **Restore applications**
   ```bash
   kubectl apply -f full-backup.yaml
   ```

## Terraform Integration

### Update main.tf for K3s

Replace the K8s master user_data with:

```hcl
resource "aws_instance" "k3s_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"
  
  user_data = file("${path.module}/scripts/k3s_server.sh")
  
  tags = {
    Name = "K3s-Server"
  }
}
```

### Remove Worker Nodes (Optional)

K3s can run everything on a single node:

```hcl
# Comment out or remove worker instances
# resource "aws_instance" "k8s_worker" { ... }
```

## Key Differences in Usage

### kubectl Commands
**Exactly the same!** All kubectl commands work identically.

```bash
kubectl get pods
kubectl logs <pod-name>
kubectl apply -f deployment.yaml
```

### Configuration Location
- **K8s**: `/etc/kubernetes/admin.conf`
- **K3s**: `/etc/rancher/k3s/k3s.yaml`

### Service Management
- **K8s**: `systemctl status kubelet`
- **K3s**: `systemctl status k3s`

### Uninstall
- **K8s**: `kubeadm reset`
- **K3s**: `/usr/local/bin/k3s-uninstall.sh`

## Troubleshooting

### K3s won't start
```bash
# Check logs
sudo journalctl -u k3s -f

# Check status
sudo systemctl status k3s
```

### kubectl not working
```bash
# Reconfigure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Pods in CrashLoopBackOff
```bash
# Same as K8s - check logs
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

## Performance Comparison

### Resource Usage (Idle Cluster)

| Metric | K8s | K3s |
|--------|-----|-----|
| Memory | ~2GB | ~512MB |
| CPU | ~0.5 cores | ~0.1 cores |
| Disk | ~10GB | ~2GB |

### Startup Time

| Operation | K8s | K3s |
|-----------|-----|-----|
| Install | 15-30 min | 2-5 min |
| Boot | 2-3 min | 30-60 sec |
| Deploy app | Same | Same |

## Recommendation

### Use K3s if:
- ✅ Development/testing environment
- ✅ Single node or small cluster (< 5 nodes)
- ✅ Limited resources
- ✅ Quick setup needed
- ✅ Edge computing / IoT

### Use K8s if:
- ✅ Production environment with high availability
- ✅ Large cluster (> 10 nodes)
- ✅ Need specific control plane customization
- ✅ Enterprise requirements
- ✅ Multi-master HA setup

## Next Steps

1. **Try K3s first** - It's easier and faster
2. **Test your application** - Ensure it works on K3s
3. **Migrate to full K8s** - Only if you need the extra features
4. **Or migrate to EKS** - For production workloads on AWS

## Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [K3s GitHub](https://github.com/k3s-io/k3s)
- [K3s vs K8s Comparison](https://www.suse.com/c/rancher_blog/k3s-vs-k8s/)
