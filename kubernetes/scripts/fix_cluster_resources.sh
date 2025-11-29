#!/bin/bash
set -e

# fix_cluster_resources.sh
# Optimizes deployment.yaml to fit on t3.large nodes by reducing replicas and resource requests.

DEPLOYMENT_FILE="../deployments/deployment.yaml"

echo "=== Optimizing Cluster Resources ==="

# 1. Backup original file
cp "$DEPLOYMENT_FILE" "${DEPLOYMENT_FILE}.bak"
echo "Backed up deployment.yaml to deployment.yaml.bak"

# 2. Reduce Replicas from 2 to 1
echo "[Step 1] Scaling down replicas to 1..."
sed -i 's/replicas: 2/replicas: 1/g' "$DEPLOYMENT_FILE"

# 3. Reduce CPU Requests (250m -> 100m) to fit more pods
echo "[Step 2] Reducing CPU requests..."
sed -i 's/cpu: "250m"/cpu: "100m"/g' "$DEPLOYMENT_FILE"

# 4. Reduce CPU Limits (500m -> 300m) to prevent starvation
echo "[Step 3] Reducing CPU limits..."
sed -i 's/cpu: "500m"/cpu: "300m"/g' "$DEPLOYMENT_FILE"
sed -i 's/cpu: "1000m"/cpu: "500m"/g' "$DEPLOYMENT_FILE" # For config-server

# 5. Reduce Memory Requests (256Mi -> 128Mi)
echo "[Step 4] Reducing Memory requests..."
sed -i 's/memory: "256Mi"/memory: "128Mi"/g' "$DEPLOYMENT_FILE"

# 6. Apply changes
echo "[Step 5] Applying optimized deployment..."
kubectl apply -f "$DEPLOYMENT_FILE"

# 7. Restart critical services first
echo "[Step 6] Restarting Config Server..."
kubectl rollout restart deployment config-server

echo "=== Optimization Complete ==="
echo "Monitor status with: kubectl get pods -w"
