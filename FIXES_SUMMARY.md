# Kubernetes & Ansible Configuration Fixes - Summary

## Issues Fixed

### 1. **Ansible Role Structure Issues**
**Problem**: 
- Roles directory was incomplete
- Playbooks referenced undefined groups like `kube_cluster`
- No proper task organization

**Solution**:
- Created proper role structure with `common-prereqs`, `k8s_master`, and `k8s_worker` roles
- Each role has `tasks/main.yml`, `handlers/main.yml`, and `defaults/main.yml`
- Roles handle installation sequentially and properly

**Files Created**:
```
ansible/roles/common-prereqs/     - Kernel, container runtime, K8s components
ansible/roles/k8s_master/         - Master node initialization
ansible/roles/k8s_worker/         - Worker node join
ansible/playbooks/k8s-cluster-roles.yml  - New playbook using roles
```

### 2. **DNS Resolution Issues in Kubernetes**
**Problem**: 
- Applications trying to connect to `discovery-server` (short hostname) which failed DNS resolution
- Error: `java.net.UnknownHostException: config-server` and `discovery-server`

**Solution**:
- Updated all deployment manifests to use Fully Qualified Domain Names (FQDN)
- Changed `discovery-server:8761` → `discovery-server.default.svc.cluster.local:8761`
- Changed `config-server:8888` → `config-server.default.svc.cluster.local:8888`

**Files Updated**:
```
kubernetes/base/deployments/admin-server.yaml
kubernetes/base/deployments/api-gateway.yaml
kubernetes/base/deployments/customers-service.yaml
kubernetes/base/deployments/discovery-server.yaml
kubernetes/base/deployments/genai-service.yaml
kubernetes/base/deployments/vets-service.yaml
kubernetes/base/deployments/visits-service.yaml
```

### 3. **Resource Constraints**
**Problem**: 
- Pods failing to schedule with "Insufficient cpu" errors
- No resource requests/limits defined

**Solution**:
- Added resource requests and limits to all deployments:
  - Request: 256Mi memory, 250m CPU
  - Limit: 512Mi memory, 500m CPU

### 4. **Kubeconfig Configuration**
**Problem**: 
- kubectl defaulting to `localhost:8080` instead of actual API server
- kubeconfig not available for both root and ec2-user

**Solution**:
- Created `setup-kubeconfig.sh` to properly configure kubeconfig for all users
- Fixed permissions and paths for both root and ec2-user

### 5. **Application Deployment**
**Problem**: 
- Services pointing to short hostnames that don't resolve in Kubernetes
- CrashLoopBackOff errors for most microservices

**Solution**:
- Updated all environment variables to use FQDN for internal service discovery
- Added resource limits to prevent scheduling conflicts
- Created `setup-cluster-and-deploy.sh` for complete deployment pipeline

## Files Created/Modified

### New Files:
- `ansible/roles/common-prereqs/tasks/main.yml`
- `ansible/roles/common-prereqs/handlers/main.yml`
- `ansible/roles/k8s_master/tasks/main.yml`
- `ansible/roles/k8s_master/defaults/main.yml`
- `ansible/roles/k8s_worker/tasks/main.yml`
- `ansible/roles/k8s_worker/defaults/main.yml`
- `ansible/playbooks/k8s-cluster-roles.yml`
- `kubernetes/scripts/setup-kubeconfig.sh`
- `kubernetes/scripts/fix-kubeconfig-and-redeploy.sh`
- `kubernetes/scripts/setup-cluster-and-deploy.sh`
- `ansible/scripts/diagnose-playbooks.sh`
- `ANSIBLE_ROLES_SETUP.md` - Comprehensive guide

### Modified Files:
- `kubernetes/base/deployments/admin-server.yaml` - FQDN + resources
- `kubernetes/base/deployments/api-gateway.yaml` - FQDN + resources
- `kubernetes/base/deployments/customers-service.yaml` - FQDN + resources
- `kubernetes/base/deployments/discovery-server.yaml` - FQDN + resources
- `kubernetes/base/deployments/genai-service.yaml` - FQDN + resources
- `kubernetes/base/deployments/vets-service.yaml` - FQDN + resources
- `kubernetes/base/deployments/visits-service.yaml` - FQDN + resources

## How to Use These Fixes

### Step 1: Setup Kubernetes Cluster with Proper Roles
```bash
cd /home/ganil/spring-petclinic-microservices/ansible
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v
```

### Step 2: Verify Cluster is Ready
```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

### Step 3: Deploy Applications with Correct Configuration
```bash
bash /home/ganil/spring-petclinic-microservices/kubernetes/scripts/setup-cluster-and-deploy.sh
```

### Step 4: Verify Applications
```bash
kubectl get pods -A
kubectl logs <pod-name>
```

## Key Improvements

1. **Proper Ansible Role Structure**: Follows Ansible best practices
2. **Kubernetes DNS Resolution**: Uses FQDN for service discovery
3. **Resource Management**: All pods have defined requests and limits
4. **Error Handling**: Better error messages and validation
5. **Idempotency**: Playbooks can be run multiple times safely
6. **Documentation**: Comprehensive troubleshooting guide included

## Verification Commands

```bash
# Check all nodes are Ready
kubectl get nodes

# Check all pods are Running
kubectl get pods -A

# Check specific service discovery
kubectl get svc

# Check if discovery-server is accessible
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://discovery-server.default.svc.cluster.local:8761/eureka/

# Check if config-server is accessible
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://config-server.default.svc.cluster.local:8888/
```

## Troubleshooting

If pods still fail:
1. Check logs: `kubectl logs <pod-name>`
2. Describe pod: `kubectl describe pod <pod-name>`
3. Check DNS: `kubectl exec -it <pod-name> -- nslookup discovery-server.default.svc.cluster.local`
4. Check network: `kubectl exec -it <pod-name> -- ping discovery-server.default.svc.cluster.local`
