#!/bin/bash

# Script to fix common Kubernetes DNS and Network issues
# Restarts CoreDNS and CNI pods to resolve connectivity problems

set -e

echo "=== Fixing DNS and Network Issues ==="
echo ""

echo "Step 1: Restarting CoreDNS pods..."
echo "----------------------------------"
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=60s
echo "✓ CoreDNS restarted"
echo ""

echo "Step 2: Restarting Calico/CNI pods..."
echo "-------------------------------------"
# Check for Calico in different namespaces
if kubectl get ds calico-node -n kube-system &>/dev/null; then
    echo "Restarting Calico in kube-system..."
    kubectl rollout restart ds calico-node -n kube-system
    kubectl rollout status ds calico-node -n kube-system --timeout=60s
elif kubectl get ds calico-node -n calico-system &>/dev/null; then
    echo "Restarting Calico in calico-system..."
    kubectl rollout restart ds calico-node -n calico-system
    kubectl rollout status ds calico-node -n calico-system --timeout=60s
else
    echo "Could not find Calico DaemonSet to restart. Checking for other CNIs..."
    kubectl get pods -A -o wide | grep -E "flannel|weave|cilium" || echo "No other common CNI found."
fi
echo "✓ CNI check/restart complete"
echo ""

echo "Step 3: Verifying DNS Resolution..."
echo "-----------------------------------"
# Launch a temporary busybox pod to test DNS
echo "Launching temporary dns-test-fix pod..."
kubectl run dns-test-fix --image=busybox:1.28 --restart=Never -- rm -rf dns-test-fix || true
kubectl run dns-test-fix --image=busybox:1.28 --restart=Never -- sleep 60

echo "Waiting for dns-test-fix pod to be running..."
kubectl wait --for=condition=ready pod/dns-test-fix --timeout=60s || echo "Pod failed to start"

echo ""
echo "Testing github.com resolution..."
if kubectl exec -i dns-test-fix -- nslookup github.com > /dev/null 2>&1; then
    echo "✅ DNS Resolution Fixed! github.com is reachable."
else
    echo "❌ DNS Resolution still failing for github.com."
    echo "Check host networking and firewall rules."
fi

echo ""
echo "Cleaning up..."
kubectl delete pod dns-test-fix --force --grace-period=0 2>/dev/null

echo ""
echo "=== Fix Attempt Complete ==="
