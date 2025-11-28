# Pod to Node Assignment Configuration

## Node Roles in Your Cluster

```
NAME                STATUS   ROLES                                          AGE     VERSION
k8s-ap-server       Ready    K8s-primary-agent,K8s-secondary-agent,worker   5h47m   v1.31.14
k8s-as-server       Ready    K8s-secondary-agent                            5h47m   v1.31.14
k8s-master-server   Ready    control-plane                                  6h38m   v1.31.14
```

## Pod Assignment Strategy

### Frontend Node: `k8s-ap-server`
**Node Role:** `node-role.kubernetes.io/K8s-primary-agent`

**Assigned Pods:**
- ✅ `api-gateway` (2 replicas)
- ✅ `admin-server` (2 replicas)

**NodeSelector Configuration:**
```yaml
nodeSelector:
  node-role.kubernetes.io/K8s-primary-agent: ""
```

---

### Backend Node: `k8s-as-server`
**Node Role:** `node-role.kubernetes.io/K8s-secondary-agent`

**Assigned Pods:**
- ✅ `customers-service` (2 replicas)
- ✅ `vets-service` (2 replicas)
- ✅ `visits-service` (2 replicas)

**NodeSelector Configuration:**
```yaml
nodeSelector:
  node-role.kubernetes.io/K8s-secondary-agent: ""
```

---

### Infrastructure Services (No Node Assignment)
**Runs on:** Any worker node

**Pods:**
- `config-server` (2 replicas)
- `discovery-server` (2 replicas)
- `genai-service` (1 replica)
- `prometheus-server` (1 replica)
- `tracing-server` (1 replica)

---

## Deployment Status

The `deployment.yaml` file has been configured with nodeSelector for:
1. ✅ API Gateway → Frontend node
2. ✅ Admin Server → Frontend node
3. ✅ Customers Service → Backend node
4. ✅ Vets Service → Backend node
5. ✅ Visits Service → Backend node

## Applying the Configuration

```bash
# Apply the deployment
kubectl apply -f kubernetes/deployments/deployment.yaml

# Restart affected deployments
kubectl rollout restart deployment/api-gateway
kubectl rollout restart deployment/admin-server
kubectl rollout restart deployment/customers-service
kubectl rollout restart deployment/vets-service
kubectl rollout restart deployment/visits-service

# Check distribution
kubectl get pods -o wide
```

## Verification Commands

```bash
# Pods on frontend node (k8s-ap-server)
kubectl get pods -o wide --field-selector spec.nodeName=k8s-ap-server

# Pods on backend node (k8s-as-server)
kubectl get pods -o wide --field-selector spec.nodeName=k8s-as-server

# All pods with node assignment
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

## Why This Configuration?

- **Frontend isolation**: API Gateway and Admin Server handle external traffic and monitoring
- **Backend isolation**: Business services (customers, vets, visits) process data operations
- **Resource optimization**: Separates gateway/monitoring from data processing workloads
- **High availability**: Infrastructure services can run on any node for flexibility
