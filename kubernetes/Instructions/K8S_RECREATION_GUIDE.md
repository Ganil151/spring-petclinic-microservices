# K8s Cluster Recreation Guide

## 🚀 Step-by-Step Instructions

### Step 1: Create K8s Instances with Terraform

```bash
cd terraform/app

# Apply Terraform to create K8s instances
terraform apply

# Type 'yes' when prompted
```

**Wait time:** 5-10 minutes for instances to be created and K8s to initialize.

---

### Step 2: Verify Instances are Running

```bash
# Check Terraform outputs
terraform output

# Note the IPs:
# - K8s Master IP
# - K8s Worker IP
```

---

### Step 3: Wait for K8s Cluster Initialization

The user_data scripts will automatically:
- Install Kubernetes
- Initialize the cluster (master)
- Join worker to master

**Wait 10-15 minutes** for the cluster to fully initialize.

---

### Step 4: Verify Cluster is Ready

SSH into the K8s master:

```bash
ssh -i your-key.pem ec2-user@<K8S-MASTER-IP>

# Check nodes
kubectl get nodes

# Expected output:
# NAME                STATUS   ROLES           AGE   VERSION
# k8s-master-server   Ready    control-plane   5m    v1.x.x
# k8s-worker-server   Ready    <none>          3m    v1.x.x
```

---

### Step 5: Add Resource Limits to Deployments

**CRITICAL:** This prevents the CrashLoopBackOff issues you experienced before.

For each deployment file in `kubernetes/deployments/`, add resource limits:

```yaml
spec:
  containers:
  - name: service-name
    image: ...
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
```

**I'll create a script to do this automatically.**

---

### Step 6: Deploy Applications

```bash
# On K8s master
kubectl apply -f kubernetes/deployments/

# Watch pods start
kubectl get pods -w
```

---

### Step 7: Monitor and Troubleshoot

```bash
# Check pod status
kubectl get pods

# If any pod is not Running, check logs
kubectl logs <pod-name>

# Check resource usage
kubectl top nodes
kubectl top pods
```

---

## 🔧 Key Differences from Before

### What We're Fixing:

1. **Resource Limits**: Added memory/CPU limits to prevent OOM kills
2. **Probe Timeouts**: Already increased (60s initial delay)
3. **Monitoring**: Will watch resource usage closely

### Resource Allocation Strategy:

| Service | Memory Request | Memory Limit | CPU Request | CPU Limit |
|---------|---------------|--------------|-------------|-----------|
| config-server | 512Mi | 1Gi | 250m | 500m |
| discovery-server | 512Mi | 1Gi | 250m | 500m |
| api-gateway | 512Mi | 1Gi | 250m | 500m |
| Business services | 512Mi | 1Gi | 250m | 500m |
| admin-server | 256Mi | 512Mi | 100m | 250m |
| Monitoring | 256Mi | 512Mi | 100m | 250m |

**Total needed:** ~6GB RAM, 2-3 vCPUs
**Available:** 2x t2.large = 16GB RAM, 4 vCPUs ✅

---

## ⚠️ Important Notes

1. **Don't deploy yet** - Wait for me to add resource limits to all deployments
2. **Monitor closely** - Watch for any CrashLoopBackOff
3. **Plan for EKS** - Once stable, we can migrate to EKS for better management

---

## 📋 Next Steps After Terraform Apply

1. ✅ Terraform creates instances (5-10 min)
2. ⏳ Wait for K8s initialization (10-15 min)
3. ✅ I'll update deployment files with resource limits
4. ✅ You deploy applications
5. ✅ Verify all pods are Running
6. ✅ Test application functionality

**Total time:** ~30-40 minutes
