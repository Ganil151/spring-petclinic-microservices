#!/bin/bash

echo "=== Kubernetes Cluster Diagnostics for Pending Pods ==="
echo ""

echo "1. Checking cluster nodes..."
kubectl get nodes -o wide
echo ""

echo "2. Checking node status details..."
kubectl describe nodes | grep -A 5 "Conditions:"
echo ""

echo "3. Checking if CNI (pod network) is installed..."
kubectl get pods -n kube-system -o wide
echo ""

echo "4. Checking one pending pod for details..."
PENDING_POD=$(kubectl get pods --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
if [ -n "$PENDING_POD" ]; then
    echo "Describing pod: $PENDING_POD"
    kubectl describe pod $PENDING_POD | grep -A 20 "Events:"
else
    echo "No pending pods found"
fi
echo ""

echo "5. Checking for taints on nodes..."
kubectl get nodes -o json | jq -r '.items[] | .metadata.name + ": " + (.spec.taints // [] | tostring)'
echo ""

echo "=== Diagnosis Summary ==="
echo ""

NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready ")
CNI_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)

echo "Total nodes: $NODE_COUNT"
echo "Ready nodes: $READY_NODES"
echo "CNI pods running: $CNI_PODS"
echo ""

if [ "$NODE_COUNT" -eq 0 ]; then
    echo "⚠ CRITICAL: No nodes found in cluster!"
    echo "  Action: Check if worker nodes have joined the cluster"
elif [ "$READY_NODES" -eq 0 ]; then
    echo "⚠ CRITICAL: No nodes are in Ready state!"
    echo "  Action: Check node status with 'kubectl describe nodes'"
elif [ "$CNI_PODS" -eq 0 ]; then
    echo "⚠ CRITICAL: No CNI (Calico) pods found!"
    echo "  Action: Install pod network with:"
    echo "    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
else
    echo "✓ Cluster looks healthy. Check pod events for specific issues."
fi
