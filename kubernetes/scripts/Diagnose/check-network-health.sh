#!/bin/bash

# Script to check Kubernetes Network and DNS Health
# Diagnoses UnknownHostException and connectivity issues

set -e

echo "=== Network & DNS Health Check ==="
echo ""

echo "Step 1: Checking CoreDNS Status (kube-system)"
echo "---------------------------------------------"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
echo ""

echo "Step 2: Checking CNI Status (Calico/Flannel/etc)"
echo "------------------------------------------------"
# Check for common CNI namespaces
if kubectl get ns calico-system &>/dev/null; then
    echo "Calico System Pods:"
    kubectl get pods -n calico-system -o wide
elif kubectl get ns tigera-operator &>/dev/null; then
    echo "Tigera Operator Pods:"
    kubectl get pods -n tigera-operator -o wide
else
    echo "Checking kube-system for CNI pods:"
    kubectl get pods -n kube-system -o wide | grep -E "calico|flannel|weave|cilium" || echo "No obvious CNI pods found in kube-system"
fi
echo ""

echo "Step 3: Testing DNS Resolution from within Cluster"
echo "--------------------------------------------------"
# Launch a temporary busybox pod to test DNS
echo "Launching temporary dns-test pod..."
kubectl run dns-test --image=busybox:1.28 --restart=Never -- rm -rf dns-test || true
kubectl run dns-test --image=busybox:1.28 --restart=Never -- sleep 3600

echo "Waiting for dns-test pod to be running..."
kubectl wait --for=condition=ready pod/dns-test --timeout=60s || echo "Pod failed to start"

echo ""
echo "Test 1: Resolve internal kubernetes service"
kubectl exec -i dns-test -- nslookup kubernetes.default

echo ""
echo "Test 2: Resolve external domain (github.com)"
kubectl exec -i dns-test -- nslookup github.com

echo ""
echo "Test 3: Check /etc/resolv.conf in pod"
kubectl exec -i dns-test -- cat /etc/resolv.conf

echo ""
echo "Cleaning up..."
kubectl delete pod dns-test --force --grace-period=0 2>/dev/null

echo ""
echo "=== End of Network Check ==="
