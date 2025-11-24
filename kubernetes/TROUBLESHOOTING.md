# Kubernetes Troubleshooting Guide - Current Status

## 🎯 Current Situation Analysis

Based on your logs from `kube-scheduler` and `kube-apiserver`, your **control plane is healthy**! ✅

### What's Working:
- ✅ **kube-apiserver** is running (v1.31.14)
- ✅ **kube-scheduler** is running and has acquired leadership
- ✅ All API groups are loaded correctly
- ✅ Control plane components are communicating

### Minor Warnings (Non-Critical):
- ⚠️ Scheduler RBAC warning about `extension-apiserver-authentication` - **This is cosmetic and doesn't affect functionality**

---

## 🔍 Next Steps to Diagnose Your Cluster

### Step 1: Check Node Status

Run this command to see if your nodes are Ready:

```bash
kubectl get nodes -o wide
```

**Expected Output:**
```
NAME                STATUS   ROLES           AGE   VERSION
k8s-master-server   Ready    control-plane   XXh   v1.31.14
k8s-worker-server   Ready    <none>          XXh   v1.31.14
```

**If nodes show "NotReady"**, proceed to Step 2.

---

### Step 2: Check Network Plugin (Calico)

Your cluster needs a CNI plugin to be fully functional. Check if Calico is running:

```bash
# Check Calico system pods
kubectl get pods -n calico-system

# Or check in kube-system namespace
kubectl get pods -n kube-system -l k8s-app=calico-node
```

**Expected Output:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-xxxxxxxxxx-xxxxx   1/1     Running   0          XXh
calico-node-xxxxx                          1/1     Running   0          XXh
calico-node-yyyyy                          1/1     Running   0          XXh
calico-typha-xxxxxxxxxx-xxxxx              1/1     Running   0          XXh
```

**If Calico pods are not running or missing**, install Calico:

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Wait for Calico to be ready
kubectl get pods -n calico-system -w
```

---

### Step 3: Check CoreDNS

DNS is critical for service discovery:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Expected Output:**
```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-xxxxxxxxxx-xxxxx   1/1     Running   0          XXh
coredns-xxxxxxxxxx-yyyyy   1/1     Running   0          XXh
```

**If CoreDNS is Pending**, it's likely waiting for the network plugin (Calico) to be ready.

---

### Step 4: Check All System Pods

Get a complete view of all system components:

```bash
kubectl get pods -n kube-system -o wide
```

Look for any pods in:
- **Pending** - Usually resource or scheduling issues
- **CrashLoopBackOff** - Application errors
- **ImagePullBackOff** - Image download issues
- **Error** - Failed pods

---

### Step 5: Check Cluster Events

Events show what's happening in your cluster:

```bash
# Recent events across all namespaces
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -30

# Or just kube-system namespace
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

---

## 🛠️ Common Issues and Fixes

### Issue 1: Nodes are NotReady

**Cause**: Network plugin not installed or not working

**Fix**:
```bash
# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Wait 2-3 minutes, then check nodes
kubectl get nodes
```

---

### Issue 2: CoreDNS Pods Pending

**Cause**: Network plugin not ready, or node taints

**Check taints**:
```bash
kubectl describe node k8s-master-server | grep -A 5 Taints
kubectl describe node k8s-worker-server | grep -A 5 Taints
```

**If master has NoSchedule taint and you want to run pods on it**:
```bash
kubectl taint nodes k8s-master-server node-role.kubernetes.io/control-plane:NoSchedule-
```

---

### Issue 3: Pods Can't Pull Images

**Symptoms**: ImagePullBackOff status

**Check**:
```bash
kubectl describe pod <pod-name> -n kube-system
```

**Fix**: Ensure containerd is running on all nodes:
```bash
# On each node (master and worker)
sudo systemctl status containerd
sudo systemctl restart containerd
```

---

### Issue 4: Scheduler RBAC Warning (Your Current Warning)

**Warning Message**:
```
Unable to get configmap/extension-apiserver-authentication in kube-system
```

**Impact**: **None** - This is a cosmetic warning. The scheduler works fine without this ConfigMap.

**Optional Fix** (if you want to remove the warning):
```bash
kubectl create rolebinding kube-scheduler-extension-apiserver-authentication-reader \
  --role=extension-apiserver-authentication-reader \
  --serviceaccount=kube-system:kube-scheduler \
  -n kube-system
```

---

## 🧪 Quick Health Check Script

I've created a comprehensive health check script for you:

**Location**: `kubernetes/troubleshooting-commands.sh`

**Run it**:
```bash
cd /path/to/spring-petclinic-microservices/kubernetes
bash troubleshooting-commands.sh
```

This will check:
1. Node status
2. Control plane pods
3. All system pods
4. Network plugin (Calico)
5. CoreDNS
6. Pending/Failed pods
7. Recent events

---

## 📋 Diagnostic Commands Reference

### Node Diagnostics
```bash
# Check nodes
kubectl get nodes -o wide

# Describe a node
kubectl describe node k8s-master-server

# Check node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'
```

### Pod Diagnostics
```bash
# All pods in all namespaces
kubectl get pods --all-namespaces -o wide

# Describe a pod
kubectl describe pod <pod-name> -n <namespace>

# Get pod logs
kubectl logs <pod-name> -n <namespace>

# Get previous container logs (if crashed)
kubectl logs <pod-name> -n <namespace> --previous
```

### Network Diagnostics
```bash
# Check Calico status
kubectl get pods -n calico-system
kubectl get installation default -o yaml

# Check network policies
kubectl get networkpolicies --all-namespaces

# Test DNS from a pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Control Plane Diagnostics
```bash
# Check control plane pods
kubectl get pods -n kube-system -l tier=control-plane

# Check API server
kubectl get --raw='/healthz?verbose'
kubectl get --raw='/readyz?verbose'

# Check scheduler logs
kubectl logs -n kube-system kube-scheduler-k8s-master-server

# Check controller manager logs
kubectl logs -n kube-system kube-controller-manager-k8s-master-server
```

---

## 🎯 What to Check Next

Based on your current logs showing healthy control plane, please run:

1. **Check node status**:
   ```bash
   kubectl get nodes
   ```

2. **Check if Calico is installed**:
   ```bash
   kubectl get pods -n calico-system
   ```

3. **Check all system pods**:
   ```bash
   kubectl get pods -n kube-system
   ```

4. **Share the output** so I can help diagnose any remaining issues!

---

## 🚀 Expected Healthy Cluster Output

When everything is working, you should see:

```bash
$ kubectl get nodes
NAME                STATUS   ROLES           AGE   VERSION
k8s-master-server   Ready    control-plane   1h    v1.31.14
k8s-worker-server   Ready    <none>          1h    v1.31.14

$ kubectl get pods -n kube-system
NAME                                        READY   STATUS    RESTARTS   AGE
calico-kube-controllers-xxx                 1/1     Running   0          1h
calico-node-xxx                             1/1     Running   0          1h
calico-node-yyy                             1/1     Running   0          1h
coredns-xxx                                 1/1     Running   0          1h
coredns-yyy                                 1/1     Running   0          1h
etcd-k8s-master-server                      1/1     Running   0          1h
kube-apiserver-k8s-master-server            1/1     Running   0          1h
kube-controller-manager-k8s-master-server   1/1     Running   0          1h
kube-proxy-xxx                              1/1     Running   0          1h
kube-proxy-yyy                              1/1     Running   0          1h
kube-scheduler-k8s-master-server            1/1     Running   0          1h
```

---

## 📞 Next Steps

Please run the diagnostic commands above and share:
1. `kubectl get nodes` output
2. `kubectl get pods -n kube-system` output
3. `kubectl get pods -n calico-system` output (if exists)

This will help me identify exactly what needs to be fixed! 🔧
