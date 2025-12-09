# Ansible Roles and Kubernetes Setup - Troubleshooting Guide

## Overview

The updated Ansible configuration uses proper roles structure to:
1. **common-prereqs**: Install and configure all K8s prerequisites (kernel modules, container runtime, kubelet)
2. **k8s_master**: Initialize the Kubernetes control plane
3. **k8s_worker**: Join worker nodes to the cluster

## Playbook Structure

```
ansible/
├── playbooks/
│   ├── k8s-cluster-roles.yml  (NEW - uses roles)
│   ├── k8s-master.yml         (legacy - can be deprecated)
│   └── k8s-workers.yml        (legacy - can be deprecated)
├── roles/
│   ├── common-prereqs/        (NEW)
│   │   ├── tasks/main.yml     (Kernel config, container runtime, K8s components)
│   │   └── handlers/main.yml  (Service restart handlers)
│   ├── k8s_master/            (NEW)
│   │   ├── tasks/main.yml     (Master initialization)
│   │   └── defaults/main.yml  (Default variables)
│   └── k8s_worker/            (NEW)
│       ├── tasks/main.yml     (Worker join)
│       └── defaults/main.yml  (Default variables)
└── inventory.ini              (Inventory with proper groups)
```

## Inventory Groups

The inventory.ini defines these groups:

```ini
[k8s_master]
k8s-master-server

[k8s_primary_workers]
k8s-worker1-server

[k8s_secondary_workers]
k8s-worker2-server

[kube_cluster:children]  # Meta-group for all K8s nodes
k8s_master
k8s_primary_workers
k8s_secondary_workers
```

## Running the Playbook

### Option 1: Full Cluster Setup
```bash
cd /home/ganil/spring-petclinic-microservices/ansible
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v
```

### Option 2: Setup Only Master Node
```bash
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v -l k8s_master
```

### Option 3: Setup Only Worker Nodes
```bash
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v -l k8s_primary_workers,k8s_secondary_workers
```

## Verifying Setup

After running the playbook:

```bash
# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check all namespaces
kubectl get pods -A

# Check for errors in specific pod
kubectl logs -n kube-system <pod-name>
```

## Common Issues and Solutions

### Issue 1: "kube_cluster" group not found
**Cause**: Playbook references undefined group  
**Solution**: Use proper group names from inventory.ini (k8s_master, k8s_primary_workers, k8s_secondary_workers)

### Issue 2: Roles not executing
**Cause**: Role paths not in Ansible search path  
**Solution**: Ensure roles are in `/ansible/roles/` directory with proper structure:
```
roles/
└── role_name/
    ├── tasks/
    │   └── main.yml
    ├── handlers/
    │   └── main.yml
    ├── defaults/
    │   └── main.yml
    └── ...
```

### Issue 3: Containerd not starting
**Cause**: Configuration issues or missing dependencies  
**Solution**: 
```bash
# Verify containerd is installed
sudo yum list installed | grep containerd

# Check service status
sudo systemctl status containerd

# View logs
sudo journalctl -u containerd -f
```

### Issue 4: Kubelet failing to start
**Cause**: Kernel modules not loaded or cgroup driver mismatch  
**Solution**: 
```bash
# Check kernel modules
lsmod | grep -E 'overlay|br_netfilter'

# Check kubelet status
sudo systemctl status kubelet

# View kubelet logs
sudo journalctl -u kubelet -f

# Verify containerd socket
ls -la /run/containerd/containerd.sock
```

### Issue 5: Nodes not joining cluster
**Cause**: Network connectivity, certificates, or wrong join command  
**Solution**:
```bash
# Verify master API is accessible
curl -k https://10.0.1.205:6443/api/v1/

# Check kubelet logs on worker
sudo journalctl -u kubelet -f

# Regenerate join command on master
kubeadm token create --print-join-command
```

## Role Variables

### common-prereqs
No required variables - uses defaults for all configurations

### k8s_master
- `kubernetes_version`: Default "1.31.14"
- `pod_subnet`: Default "10.244.0.0/16"
- `service_subnet`: Default "10.96.0.0/12"

### k8s_worker
- `kubernetes_version`: Default "1.31.14"

## Kubernetes Application Deployment

After cluster is up, deploy applications with correct DNS:

```bash
# Redeploy with fixed discovery-server FQDN
bash /home/ganil/spring-petclinic-microservices/kubernetes/scripts/setup-cluster-and-deploy.sh
```

This script will:
1. Delete old deployments
2. Wait for pods to terminate
3. Apply updated manifests with:
   - `config-server.default.svc.cluster.local` for config server
   - `discovery-server.default.svc.cluster.local` for service discovery
   - Proper resource requests/limits

## Debugging Role Execution

To debug what's happening in roles:

```bash
# Run with extra verbosity
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -vvv

# Run specific role only
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml --tags master

# Run specific task
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -k "Initialize Kubernetes"
```

## Next Steps

1. Run the cluster setup: `ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v`
2. Wait for all nodes to be Ready: `kubectl get nodes -w`
3. Deploy applications: `bash /kubernetes/scripts/setup-cluster-and-deploy.sh`
4. Verify applications: `kubectl get pods -A` and `kubectl logs <pod-name>`
