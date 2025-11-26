# K3s Simple Setup Guide

## Overview

Simplified K3s setup with minimal dependencies:
- **Server**: Installs K3s and displays join command
- **Agent**: Minimal installation, just needs server IP and token

## Installation Steps

### 1. Install K3s Server

The server script runs automatically via Terraform user_data.

After installation completes, you'll see:

```
==========================================
Add Worker Nodes
==========================================

On each worker node, run these commands:

  export K3S_SERVER_IP="10.0.1.X"
  export K3S_TOKEN="K10abc123..."
  curl -sfL https://get.k3s.io | sh -s - agent

Or copy and paste this single command:

  K3S_URL=https://10.0.1.X:6443 K3S_TOKEN=K10abc123... curl -sfL https://get.k3s.io | sh -

==========================================
```

### 2. Join Worker Nodes

#### Option A: Using Environment Variables (Recommended)

On the worker node:

```bash
# Copy these from server output
export K3S_SERVER_IP="10.0.1.X"
export K3S_TOKEN="K10abc123..."

# Run the agent script
bash /var/cloud/instance/scripts/part-001
```

#### Option B: One-Line Command

Copy the single command from server output and run it on the worker:

```bash
K3S_URL=https://10.0.1.X:6443 K3S_TOKEN=K10abc123... curl -sfL https://get.k3s.io | sh -
```

### 3. Verify Cluster

On the K3s server:

```bash
# Check nodes
kubectl get nodes

# Should show:
# NAME                STATUS   ROLES                  AGE   VERSION
# k3s-server          Ready    control-plane,master   5m    v1.28.5+k3s1
# k3s-agent-worker    Ready    <none>                 1m    v1.28.5+k3s1
```

## What Each Script Does

### k3s_server.sh

**Installs**:
- curl, wget, git, jq, vim, net-tools, bind-utils, tar, unzip
- K3s server
- kubectl (configured automatically)
- Helm
- metrics-server
- Spring Petclinic repository

**Configures**:
- SELinux (permissive)
- Swap (disabled)
- Kernel modules (overlay, br_netfilter)
- Sysctl parameters

**Outputs**:
- Server IP
- Join token
- Complete join command for workers

### k3s_agent.sh

**Installs**:
- curl (only essential package)
- K3s agent

**Requires**:
- `K3S_SERVER_IP` environment variable
- `K3S_TOKEN` environment variable

**Configures**:
- SELinux (permissive)
- Swap (disabled)
- Minimal system prep

## Troubleshooting

### Worker can't join

**Check connectivity**:
```bash
# On worker
ping <server-ip>
telnet <server-ip> 6443
```

**Check security groups**:
- Port 6443 must be open between server and workers
- All ports in terraform.tfvars should be allowed

### Get join info manually

**On server**:
```bash
# Get server IP
hostname -I | awk '{print $1}'

# Get token
sudo cat /var/lib/rancher/k3s/server/node-token
```

### Check logs

**Server**:
```bash
sudo journalctl -u k3s -f
```

**Agent**:
```bash
sudo journalctl -u k3s-agent -f
```

### Restart services

**Server**:
```bash
sudo systemctl restart k3s
```

**Agent**:
```bash
sudo systemctl restart k3s-agent
```

## Deploy Spring Petclinic

After cluster is ready:

```bash
# On K3s server
cd ~/spring-petclinic-microservices/kubernetes/deployments
kubectl apply -f .

# Monitor deployment
kubectl get pods -w

# Check services
kubectl get services

# Access API Gateway
kubectl get service api-gateway
```

## Key Differences from Previous Version

| Feature | Old Version | New Version |
|---------|-------------|-------------|
| **Agent Dependencies** | Many packages, AWS CLI | Only curl |
| **Server Discovery** | AWS API calls, tags | Manual IP/token |
| **IAM Requirements** | SSM, EC2 permissions | None |
| **Complexity** | High | Low |
| **Reliability** | Depends on AWS APIs | Direct connection |
| **Setup Time** | Slower | Faster |

## Benefits

✅ **Simpler** - No AWS API dependencies
✅ **Faster** - Minimal package installation
✅ **More Reliable** - Direct connection, no API calls
✅ **Easier to Debug** - Clear error messages
✅ **Works Anywhere** - Not AWS-specific

## Next Steps

1. **Terraform Apply** - Deploy infrastructure
2. **Wait for Server** - Server installation takes ~5 minutes
3. **Get Join Command** - SSH to server and copy join command
4. **Join Workers** - Run join command on worker nodes
5. **Deploy Apps** - Deploy Spring Petclinic
6. **Verify** - Check all pods are running

## Complete Example

```bash
# 1. Deploy with Terraform
terraform apply

# 2. SSH to K3s server
ssh -i master_keys.pem ec2-user@<server-public-ip>

# 3. Wait for installation to complete
tail -f /var/log/k3s-installation.log

# 4. Copy the join command from output

# 5. SSH to worker
ssh -i master_keys.pem ec2-user@<worker-public-ip>

# 6. Set variables and join
export K3S_SERVER_IP="10.0.1.X"
export K3S_TOKEN="K10abc123..."
bash /var/cloud/instance/scripts/part-001

# 7. Back on server, verify
kubectl get nodes

# 8. Deploy application
cd ~/spring-petclinic-microservices/kubernetes/deployments
kubectl apply -f .
kubectl get pods -w
```

That's it! Your K3s cluster is ready. 🚀
