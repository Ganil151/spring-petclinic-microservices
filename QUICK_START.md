# Quick Start Guide - Kubernetes Setup & Application Deployment

## Overview

This guide walks you through the complete process of setting up your Kubernetes cluster and deploying the Spring Petclinic microservices application with all fixes applied.

## What Was Fixed

1. **✓ Ansible Roles Structure** - Proper role-based playbook organization
2. **✓ DNS Resolution** - Fixed service discovery using FQDN
3. **✓ Resource Allocation** - Added resource requests/limits to all pods
4. **✓ Kubeconfig** - Proper configuration for both root and ec2-user

## Prerequisites

- Access to master and worker nodes via SSH
- Ansible installed on the control machine
- kubectl configured with access to the cluster

## Step-by-Step Setup

### Step 1: Validate Ansible Configuration (Optional)

```bash
cd /home/ganil/spring-petclinic-microservices/ansible
ansible-inventory -i inventory.ini --graph
```

Expected output should show:
```
@all:
  |--@k8s_master:
  |  |--k8s-master-server
  |--@k8s_primary_workers:
  |  |--k8s-worker1-server
  |--@k8s_secondary_workers:
  |  |--k8s-worker2-server
  |--@kube_cluster:
```

### Step 2: Setup Kubernetes Cluster with Proper Roles

**Important**: Run this from a machine with SSH access to all nodes

```bash
cd /home/ganil/spring-petclinic-microservices/ansible

# Run the complete cluster setup
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v
```

This will:
- Install container runtime (containerd)
- Install Kubernetes components (kubelet, kubeadm, kubectl)
- Configure kernel modules and parameters
- Initialize the control plane on the master node
- Join all worker nodes to the cluster
- Label worker nodes appropriately

**Estimated time**: 10-15 minutes

### Step 3: Verify Cluster Setup

```bash
# Check that all nodes are Ready
kubectl get nodes -o wide

# Output should show:
# NAME                  STATUS   ROLES           
# k8s-master-server     Ready    control-plane   
# k8s-worker1-server    Ready    <none>          
# k8s-worker2-server    Ready    <none>          

# Check system pods
kubectl get pods -n kube-system

# Verify CoreDNS is running
kubectl get pods -n kube-system | grep coredns
```

### Step 4: Deploy Applications

```bash
cd /home/ganil/spring-petclinic-microservices

# Delete old deployments
kubectl delete deployment admin-server api-gateway customers-service \
  discovery-server genai-service vets-service visits-service -n default \
  --ignore-not-found=true

# Wait 20 seconds for pods to terminate
sleep 20

# Apply updated manifests with correct DNS configuration
kubectl apply -f kubernetes/base/deployments/

# Verify deployments
kubectl get deployments -n default
```

### Step 5: Monitor Application Startup

```bash
# Watch pods starting up
kubectl get pods -w

# Or check status every few seconds
watch kubectl get pods -n default
```

Wait for all pods to reach "Running" state. This may take 2-5 minutes.

### Step 6: Verify Applications are Healthy

```bash
# Check pod logs for any errors
kubectl logs <pod-name>

# Example: Check customers-service logs
kubectl logs -l app=customers-service -f

# Check if pods can reach each other
kubectl exec -it <pod-name> -- nslookup discovery-server.default.svc.cluster.local
```

## Verification Checklist

- [ ] All nodes show `STATUS: Ready` with `kubectl get nodes`
- [ ] All pods show `STATUS: Running` with `kubectl get pods -A`
- [ ] No `CrashLoopBackOff` or `Pending` pods
- [ ] Services are accessible within the cluster
- [ ] Microservices can reach config-server and discovery-server

## Troubleshooting

### Issue: Nodes not showing as Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs on the node
ssh ec2-user@<node-ip>
sudo journalctl -u kubelet -f
```

### Issue: Pods in CrashLoopBackOff

```bash
# Check pod logs
kubectl logs <pod-name> --previous
kubectl logs <pod-name>

# Describe pod for more info
kubectl describe pod <pod-name>
```

### Issue: DNS resolution not working

```bash
# Test DNS from within a pod
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup discovery-server.default.svc.cluster.local

# Or test from within an existing pod
kubectl exec -it <pod-name> -- nslookup discovery-server.default.svc.cluster.local
```

### Issue: Services not accessible

```bash
# Verify service exists
kubectl get svc

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://discovery-server:8761/eureka/
```

## Advanced Diagnostics

Run the comprehensive diagnostic report:

```bash
bash /home/ganil/spring-petclinic-microservices/scripts/full-diagnostic.sh
```

This will generate a complete report of:
- Ansible configuration
- Kubernetes cluster status
- Network diagnostics
- Container runtime status
- Deployment manifests
- Common issues

## Manual Cluster Fixes (If Needed)

### Fix kubeconfig for all users

```bash
sudo bash /home/ganil/spring-petclinic-microservices/kubernetes/scripts/setup-kubeconfig.sh
```

### Redeploy only applications

```bash
bash /home/ganil/spring-petclinic-microservices/kubernetes/scripts/setup-cluster-and-deploy.sh
```

### Fix Ansible roles and redeploy

```bash
cd /home/ganil/spring-petclinic-microservices/ansible
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v
```

## Key Configuration Files

- **Inventory**: `ansible/inventory.ini` - Defines hosts and groups
- **Playbook**: `ansible/playbooks/k8s-cluster-roles.yml` - Main setup playbook
- **Roles**: 
  - `ansible/roles/common-prereqs/` - Kernel and runtime setup
  - `ansible/roles/k8s_master/` - Control plane setup
  - `ansible/roles/k8s_worker/` - Worker node setup
- **Deployments**: `kubernetes/base/deployments/*.yaml` - App manifests

## Documentation

- `FIXES_SUMMARY.md` - Summary of all fixes applied
- `ANSIBLE_ROLES_SETUP.md` - Detailed Ansible roles documentation
- `kubernetes/base/deployments/` - Individual deployment manifests

## Support Scripts

- `kubernetes/scripts/setup-kubeconfig.sh` - Configure kubeconfig
- `kubernetes/scripts/fix-kubeconfig-and-redeploy.sh` - Fix kubeconfig and redeploy
- `kubernetes/scripts/setup-cluster-and-deploy.sh` - Complete setup and deployment
- `kubernetes/scripts/redeploy-apps.sh` - Redeploy applications only
- `ansible/scripts/diagnose-playbooks.sh` - Diagnose Ansible configuration
- `scripts/full-diagnostic.sh` - Complete cluster diagnostic report

## Next Steps

1. **Monitor Applications**: Use `kubectl logs` and `kubectl get pods` to verify everything is running
2. **Configure Monitoring**: Set up Prometheus and Grafana for cluster monitoring
3. **Configure Ingress**: Set up an Ingress controller for external access
4. **Backup Configuration**: Back up kubeconfig and important cluster configuration
5. **Scale Applications**: Adjust replica counts based on your needs

## Common Commands Reference

```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A

# Deployment management
kubectl apply -f <file.yaml>
kubectl delete deployment <name>
kubectl rollout restart deployment/<name>

# Debugging
kubectl logs <pod>
kubectl exec -it <pod> -- /bin/bash
kubectl describe pod <pod>
kubectl port-forward <pod> 8080:8080

# Services
kubectl get svc
kubectl port-forward svc/<service> 8080:8080

# Configuration
kubectl get configmap
kubectl get secret
```

## Need Help?

1. Check logs: `kubectl logs <pod-name>`
2. Describe resources: `kubectl describe pod <pod-name>`
3. Run diagnostics: `bash scripts/full-diagnostic.sh`
4. Check documentation in the repository root for detailed guides
