#!/bin/bash
set -e

# fix_all_pods.sh
# Comprehensive fix for stuck/crashing pods

echo "=== Fixing All Pod Issues ==="

# Step 1: Delete all old pods to break the rolling update deadlock
echo "[Step 1] Deleting all pods to clear stuck state..."
kubectl delete pods --all --wait=false

# Step 2: Wait for pods to be deleted
echo "[Step 2] Waiting for pods to terminate..."
sleep 10

# Step 3: Wait for config-server to start (it's the critical dependency)
echo "[Step 3] Waiting for Config Server to be ready..."
echo "This may take up to 3 minutes (initial delay is 180s)..."

# Wait up to 5 minutes for config-server to be ready
timeout 300 bash -c 'until kubectl get pods -l app=config-server | grep -q "1/1.*Running"; do sleep 5; echo -n "."; done' || {
    echo ""
    echo "⚠️  Config Server did not become ready in 5 minutes."
    echo "Checking logs..."
    kubectl logs -l app=config-server --tail=30
    echo ""
    echo "Checking pod describe..."
    kubectl describe pod -l app=config-server | tail -30
    exit 1
}

echo ""
echo "✓ Config Server is Ready!"

# Step 4: Wait for other services to stabilize
echo "[Step 4] Waiting for other services to start..."
sleep 30

# Step 5: Show current status
echo "[Step 5] Current Pod Status:"
kubectl get pods

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Monitor with: kubectl get pods -w"
echo ""
echo "If pods are still crashing, check logs:"
echo "  kubectl logs -l app=discovery-server --tail=20"
echo "  kubectl logs -l app=customers-service --tail=20"
