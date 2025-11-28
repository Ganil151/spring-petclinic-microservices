#!/bin/bash

# Script to label worker nodes with proper roles
# Run this on the master node

set -e

echo "=== Labeling Kubernetes Worker Nodes ==="
echo ""

# Get all nodes without the control-plane role
WORKER_NODES=$(kubectl get nodes --no-headers | grep -v "control-plane" | awk '{print $1}')

if [ -z "$WORKER_NODES" ]; then
    echo "No worker nodes found!"
    exit 1
fi

echo "Found worker nodes:"
for node in $WORKER_NODES; do
    echo "  - $node"
done
echo ""

# Label each worker node
for node in $WORKER_NODES; do
    echo "Labeling $node as worker..."
    kubectl label node "$node" node-role.kubernetes.io/worker=worker --overwrite
    echo "✓ $node labeled"
done

echo ""
echo "=== Current Node Status ==="
kubectl get nodes

echo ""
echo "=== Additional Node Labels ==="
echo "You can also add custom labels like:"
echo "  kubectl label node <node-name> environment=production"
echo "  kubectl label node <node-name> workload-type=compute-intensive"
echo "  kubectl label node <node-name> zone=us-east-1a"
