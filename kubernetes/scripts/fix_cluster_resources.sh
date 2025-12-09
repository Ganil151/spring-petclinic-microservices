#!/bin/bash
set -e

echo "=== Optimizing Cluster Resources ==="

echo "[Step 1] Scaling down replicas..."
kubectl scale deployment --all --replicas=1

echo "[Step 2] Applying optimized manifests..."
kubectl apply -k ../base/

echo "[Step 3] Restarting Config Server..."
kubectl rollout restart deployment config-server

echo "=== Optimization Complete ==="
echo "Monitor status with: kubectl get pods -w"
