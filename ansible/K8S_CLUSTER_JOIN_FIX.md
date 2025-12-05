# Kubernetes Cluster Join Issue - Resolution Guide

## Problem Summary
Worker nodes are failing to join the Kubernetes cluster with two main issues:
1. **Hostname resolution failure** - DNS lookups failing
2. **API Server connectivity timeout** - Cannot reach master at `10.0.1.82:6443`

## Root Causes

### 1. Hostname Resolution 
- Worker nodes cannot resolve hostnames via DNS
- `/etc/hosts` file doesn't contain cluster node mappings

### 2. Network Connectivity
The workers need to connect to the master's API server on port 6443, but this may be blocked by:
- **Security Groups** - AWS security groups may not allow traffic
- **VPC/Subnet Configuration** - Nodes may not be in the same VPC or have proper routing
- **Network ACLs** - Additional firewall rules blocking traffic

## Solutions Implemented

### ✅ 1. Added /etc/hosts Configuration (DONE)
Both `k8s-master.yml` and `k8s-workers.yml` now:
- Gather facts from all cluster nodes
- Configure `/etc/hosts` with private IP mappings for all nodes
- This ensures hostname resolution works without DNS

Example `/etc/hosts` entry:
```
10.0.1.82 k8s-master-server ip-10-0-1-82
10.0.1.45 k8s-worker1-server ip-10-0-1-45
10.0.1.67 k8s-worker2-server ip-10-0-1-67
```

### ✅ 2. Added Connectivity Check (DONE)
The workers playbook now tests connectivity to master:6443 before attempting to join

## Required Manual Verification

### 🔍 Check AWS Security Groups

You **MUST** verify that security groups allow the following traffic:

#### Master Node Security Group - Inbound Rules:
```
Port 6443/tcp   - Source: Worker nodes security group  # Kubernetes API Server
Port 2379-2380/tcp - Source: Master security group     # etcd server
Port 10250/tcp  - Source: Master + Workers SG          # Kubelet API
Port 10259/tcp  - Source: Master security group        # kube-scheduler
Port 10257/tcp  - Source: Master security group        # kube-controller-manager
```

#### Worker Nodes Security Group - Inbound Rules:
```
Port 10250/tcp  - Source: Master security group        # Kubelet API  
Port 30000-32767/tcp - Source: As needed               # NodePort Services
```

#### All Nodes - Must Allow:
```
All traffic between cluster nodes (Master <-> Workers communication)
```

### 🔍 Check VPC Configuration

Verify that:
1. All K8s nodes (master + workers) are in the **same VPC**
2. Subnets have proper routing tables configured
3. No Network ACLs blocking traffic between subnets

### 🔍 Verify Terraform Security Group Configuration

Check your Terraform files for security group rules:

```bash
# Search for security group configurations
grep -r "security_group" terraform/
grep -r "6443" terraform/
```

Look for files like:
- `terraform/modules/Ec2/security_groups.tf`
- `terraform/main.tf`

## Testing Connectivity

### From Worker Node to Master:

```bash
# Test API server port
nc -zv 10.0.1.82 6443

# Or with telnet
telnet 10.0.1.82 6443

# Or with curl
curl -k https://10.0.1.82:6443

# Ping test
ping k8s-master-server
```

If these fail, the security groups are likely blocking traffic.

## Next Steps

1. **Verify Security Groups** in AWS Console or Terraform code
2. **Update Security Groups** to allow required ports (see above)
3. **Re-run the playbooks**:
   ```bash
   # First ensure master is initialized
   ansible-playbook -i ansible/inventory.ini ansible/playbooks/k8s-master.yml
   
   # Then join workers
   ansible-playbook -i ansible/inventory.ini ansible/playbooks/k8s-workers.yml
   ```

## Expected Behavior After Fix

- `/etc/hosts` will contain all node mappings
- Workers can resolve hostnames locally
- Workers can reach master:6443
- `kubeadm join` will succeed
- Nodes will appear in `kubectl get nodes`

## Debugging Commands

```bash
# On master - check if API server is listening
sudo netstat -tlnp | grep 6443
sudo ss -tlnp | grep 6443

# On worker - test connectivity (run before join)
telnet 10.0.1.82 6443
curl -k https://10.0.1.82:6443/version

# Check /etc/hosts
cat /etc/hosts

# View kubeadm join with debug output
kubeadm join 10.0.1.82:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --v=5
```
