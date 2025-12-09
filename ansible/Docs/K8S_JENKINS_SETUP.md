# Jenkinsfile and Ansible Kubernetes Setup - Summary

## What Was Done

### 1. Created Missing Kubernetes Playbooks

We created three new Ansible playbooks that were referenced in README.md but didn't exist:

#### `ansible/playbooks/k8s-master.yml`
- **Purpose**: Set up and initialize the Kubernetes master (control plane) node
- **Key Tasks**:
  - Disables swap and configures kernel modules
  - Installs containerd as container runtime
  - Installs kubeadm, kubelet, and kubectl v1.28
  - Initializes Kubernetes cluster with `kubeadm init`
  - Installs Calico CNI plugin
  - Configures kubectl for ec2-user
  - Generates worker join command and saves to `/tmp/k8s_join_command.sh`
  - Labels node with `control-plane` role

#### `ansible/playbooks/k8s-workers.yml`
- **Purpose**: Set up worker nodes and join them to the cluster
- **Key Tasks**:
  - Prepares worker nodes (swap, kernel modules, containerd)
  - Installs kubeadm and kubelet
  - Retrieves join command from master
  - Joins workers to the cluster
  - Applies node labels:
    - Primary workers: `node-role.kubernetes.io/worker`, `workload-type=primary`, `node-role.kubernetes.io/frontend`
    - Secondary workers: `node-role.kubernetes.io/worker`, `workload-type=secondary`
  - Verifies cluster health

#### `ansible/playbooks/k8s-cluster.yml`
- **Purpose**: Orchestration playbook that runs both master and workers setup
- **What it does**:
  - Runs `k8s-master.yml`
  - Runs `k8s-workers.yml`
  - Performs comprehensive cluster verification
  - Displays cluster info and next steps

### 2. Updated Jenkinsfile

Added 4 new stages to the Jenkins pipeline after the "Configure MySQL Database" stage:

#### Stage: "Setup Kubernetes Master"
- **When**: `DEPLOYMENT_TARGET` is 'kubernetes' or 'both'
- **Actions**:
  - Tests connectivity to K8s master node
  - Runs `ansible-playbook playbooks/k8s-master.yml`
  - Sets up control plane

#### Stage: "Setup Kubernetes Workers"
- **When**: `DEPLOYMENT_TARGET` is 'kubernetes' or 'both'
- **Actions**:
  - Tests connectivity to worker nodes
  - Runs `ansible-playbook playbooks/k8s-workers.yml`
  - Joins workers to cluster

#### Stage: "Deploy to Kubernetes"
- **When**: `DEPLOYMENT_TARGET` is 'kubernetes' or 'both'
- **Actions**:
  - Extracts K8s master IP from Ansible inventory
  - Copies `kubernetes/` manifests to master node
  - Deploys Kubernetes manifests using kustomize
  - Waits for critical pods (config-server, discovery-server)
  - Shows cluster status

#### Stage: "Verify Kubernetes Deployment"
- **When**: `DEPLOYMENT_TARGET` is 'kubernetes' or 'both'
- **Actions**:
  - Connects to master node
  - Displays nodes, pods, and services
  - Shows API Gateway NodePort URL for accessing the application

## Pipeline Flow

The updated Jenkins pipeline now supports:

```
1. Checkout
2. Prepare tools
3. Modify docker-compose.yml
4. Build JAR
5. Docker Build & Push
6. Provision or Reuse Docker-Server
7. Bootstrap Docker-Server
8. Deploy to Docker-Server (when DEPLOYMENT_TARGET = 'docker' or 'both')
9. Verify Docker Deployment (when DEPLOYMENT_TARGET = 'docker' or 'both')
10. Configure MySQL Database (when CONFIGURE_MYSQL = true)
11. Setup Kubernetes Master (when DEPLOYMENT_TARGET = 'kubernetes' or 'both')  ✨ NEW
12. Setup Kubernetes Workers (when DEPLOYMENT_TARGET = 'kubernetes' or 'both') ✨ NEW
13. Deploy to Kubernetes (when DEPLOYMENT_TARGET = 'kubernetes' or 'both')    ✨ NEW
14. Verify Kubernetes Deployment (when DEPLOYMENT_TARGET = 'kubernetes' or 'both') ✨ NEW
```

## How to Use

### Option 1: Deploy to Kubernetes Only
```groovy
// In Jenkins, set parameters:
DEPLOYMENT_TARGET = 'kubernetes'
CONFIGURE_MYSQL = true  // If databases need setup
```

### Option 2: Deploy to Both Docker and Kubernetes
```groovy
DEPLOYMENT_TARGET = 'both'
CONFIGURE_MYSQL = true
```

### Option 3: Run Manually via Ansible

From your local machine or Jenkins worker:

```bash
cd ansible

# Setup complete cluster (master + workers)
ansible-playbook -i inventory.ini playbooks/k8s-cluster.yml

# Or run individually:
ansible-playbook -i inventory.ini playbooks/k8s-master.yml
ansible-playbook -i inventory.ini playbooks/k8s-workers.yml
```

## Prerequisites

### Inventory Requirements

Your `ansible/inventory.ini` must have these groups defined:
- `[k8s_master]` - The master/control-plane node
- `[k8s_primary_workers]` - Primary worker nodes
- `[k8s_secondary_workers]` - Secondary worker nodes (optional)

Example:
```ini
[k8s_master]
k8s-master-server ansible_host=54.161.1.1 ansible_user=ec2-user

[k8s_primary_workers]
k8s-worker1-server ansible_host=54.161.1.2 ansible_user=ec2-user

[k8s_secondary_workers]
k8s-worker2-server ansible_host=54.161.1.3 ansible_user=ec2-user
```

### Group Variables

The playbooks use variables from `ansible/group_vars/k8s_master.yml`:
- `k8s_version` - Kubernetes version (default: 1.28.0)
- `pod_network_cidr` - Pod network range (default: 10.244.0.0/16)
- `service_cidr` - Service network range (default: 10.96.0.0/12)

## What About the Empty MySQL Tables?

**This is normal!** The `petclinic_vets` database exists but has no tables because:

1. **Ansible creates the databases** (✅ Done)
   - `petclinic_customers`, `petclinic_vets`, `petclinic_visits`

2. **Spring Boot creates the tables** (Happens when apps start)
   - Each microservice uses JPA/Hibernate to automatically create its schema
   - Tables are created when the Spring app first connects to MySQL

3. **To populate tables**, you need to:
   - Deploy the microservices (Docker or Kubernetes)
   - The Spring apps will connect to MySQL and create tables
   - Sample data will be loaded via `data.sql` or similar

## Next Steps

1. **Verify your Ansible inventory** has K8s nodes defined
2. **Run the pipeline** with `DEPLOYMENT_TARGET='kubernetes'`
3. **Monitor the stages** for any errors
4. **Access the application** via the NodePort URL shown in verification stage
5. **Check MySQL tables** after apps are running:
   ```sql
   SHOW TABLES FROM petclinic_vets;
   ```
   You should see tables like `vets`, `specialties`, `vet_specialties`

## Troubleshooting

### If pipeline fails on K8s stages:
- Check Ansible can reach K8s nodes: `ansible k8s_master -i inventory.ini -m ping`
- Verify SSH credentials are configured in Jenkins
- Check security groups allow SSH (port 22)

### If pods don't start:
- SSH to master: `ssh -i ~/.ssh/master_keys.pem ec2-user@<master-ip>`
- Check pods: `kubectl get pods -o wide`
- Check logs: `kubectl logs <pod-name>`

### If tables are still empty after deployment:
- Check if pods are running: `kubectl get pods`
- Check pod logs for connection errors: `kubectl logs <service-pod>`
- Verify environment variables for database connection
- The config server needs database connection details (see earlier discussion about config repository)

---

**Created**: 2024-12-05
**Ansible Version**: 2.15+
**Kubernetes Version**: 1.28
**MySQL Version**: 8.0
