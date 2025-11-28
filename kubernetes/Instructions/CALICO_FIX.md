# Calico Installation Fix - CRD Annotation Size Error

## 🚨 **Problem**

```
The CustomResourceDefinition "installations.operator.tigera.io" is invalid: 
metadata.annotations: Too long: must have at most 262144 bytes
```

This error occurs because `kubectl apply` tries to store the entire manifest in the `kubectl.kubernetes.io/last-applied-configuration` annotation, which exceeds the 256KB limit.

---

## ✅ **Quick Fix**

### **Method 1: Use kubectl create (Recommended)**

```bash
# Remove failed installation
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml --ignore-not-found

# Install using create instead of apply
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml

# Wait for operator
kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator

# Install custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Check status
kubectl get pods -n calico-system
kubectl get nodes
```

### **Method 2: Use server-side apply**

```bash
# Remove failed installation
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml --ignore-not-found

# Install using server-side apply
kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml

# Wait for operator
kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator

# Install custom resources
kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Check status
kubectl get pods -n calico-system
kubectl get nodes
```

---

## 🔍 **Complete Cleanup and Reinstall**

If you need to start fresh:

```bash
# 1. Delete Calico components
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml --ignore-not-found

# 2. Delete namespaces
kubectl delete namespace calico-system --ignore-not-found
kubectl delete namespace tigera-operator --ignore-not-found

# 3. Delete CRDs
kubectl delete crd installations.operator.tigera.io --ignore-not-found
kubectl delete crd tigerastatuses.operator.tigera.io --ignore-not-found

# 4. Wait for cleanup (30 seconds)
sleep 30

# 5. Reinstall using create
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml

# 6. Wait for operator (2 minutes)
kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator

# 7. Install custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# 8. Watch Calico pods start
kubectl get pods -n calico-system -w

# 9. Check nodes (will become Ready in 2-3 minutes)
kubectl get nodes -w
```

---

## 📋 **Automated Fix Script**

Run this complete fix:

```bash
#!/bin/bash
echo "Fixing Calico installation..."

# Cleanup
echo "1. Cleaning up failed installation..."
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml --ignore-not-found
kubectl delete namespace calico-system --ignore-not-found --timeout=60s
kubectl delete namespace tigera-operator --ignore-not-found --timeout=60s

echo "Waiting for cleanup..."
sleep 30

# Install
echo "2. Installing Tigera operator..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml

echo "3. Waiting for operator..."
kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator || echo "Operator may still be starting..."

echo "4. Installing Calico custom resources..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

echo "5. Checking Calico pods..."
kubectl get pods -n calico-system

echo "6. Checking nodes..."
kubectl get nodes

echo ""
echo "Done! Wait 2-3 minutes for nodes to become Ready"
echo "Monitor with: kubectl get nodes -w"
```

---

## 🛠️ **Why This Happens**

- **kubectl apply** stores the entire manifest in an annotation for tracking changes
- Calico's CRD manifest is very large (>256KB)
- This exceeds Kubernetes' annotation size limit
- **kubectl create** doesn't store the annotation, so it works
- **kubectl apply --server-side** uses server-side tracking instead of annotations

---

## ✅ **Verify Installation**

```bash
# Check operator
kubectl get deployment -n tigera-operator

# Check Calico pods
kubectl get pods -n calico-system

# Check nodes (should become Ready)
kubectl get nodes

# Check Calico installation status
kubectl get installation default -o yaml

# Check Calico daemonsets
kubectl get daemonset -n calico-system
```

---

## 📊 **Expected Timeline**

1. **Operator install**: 30 seconds
2. **Operator ready**: 1-2 minutes
3. **Calico pods starting**: 2-3 minutes
4. **Nodes Ready**: 3-5 minutes total

---

## 💡 **Prevention**

For future installations, always use:
- `kubectl create` for initial Calico installation
- `kubectl apply --server-side` if you need apply semantics
- Never use plain `kubectl apply` for large CRDs

---

## 🚨 **If Nodes Still NotReady**

```bash
# Check Calico pods
kubectl get pods -n calico-system

# Check pod logs
kubectl logs -n calico-system -l k8s-app=calico-node --tail=50

# Describe node
kubectl describe node k8s-master-server

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

## 📞 **Quick Commands**

```bash
# One-liner fix
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml --ignore-not-found && sleep 10 && kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml && kubectl wait --for=condition=available --timeout=120s deployment/tigera-operator -n tigera-operator && kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# Watch nodes become Ready
watch kubectl get nodes

# Watch Calico pods
watch kubectl get pods -n calico-system
```
