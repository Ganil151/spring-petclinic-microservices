#!/bin/bash
set -e

echo "=== Fixing Kubernetes Deployment ==="

# Apply updated manifests
echo "1. Applying updated deployments..."
kubectl apply -f base/deployments/deployment.yaml

# Wait a bit
sleep 5

# Restart config-server first
echo "2. Restarting config-server..."
kubectl rollout restart deployment/config-server
kubectl rollout status deployment/config-server --timeout=300s

# Restart discovery-server
echo "3. Restarting discovery-server..."
kubectl rollout restart deployment/discovery-server
kubectl rollout status deployment/discovery-server --timeout=300s

# Restart services
echo "4. Restarting microservices..."
kubectl rollout restart deployment/customers-service
kubectl rollout restart deployment/vets-service
kubectl rollout restart deployment/visits-service

# Wait for services
kubectl rollout status deployment/customers-service --timeout=300s
kubectl rollout status deployment/vets-service --timeout=300s
kubectl rollout status deployment/visits-service --timeout=300s

# Restart gateway and admin
echo "5. Restarting gateway and admin..."
kubectl rollout restart deployment/api-gateway
kubectl rollout restart deployment/admin-server

kubectl rollout status deployment/api-gateway --timeout=300s
kubectl rollout status deployment/admin-server --timeout=300s

echo "=== Deployment Complete ==="
kubectl get pods -o wide
