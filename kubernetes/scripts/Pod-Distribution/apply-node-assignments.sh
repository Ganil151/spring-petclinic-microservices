#!/bin/bash

# Script to apply pod-to-node assignments using existing node roles
# No additional labeling needed - uses existing K8s-primary-agent and K8s-secondary-agent roles

set -e

echo "=== Applying Pod-to-Node Assignments ==="
echo ""

echo "Step 1: Verifying node roles..."
echo "--------------------------------"
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,ROLES:.metadata.labels --no-headers | grep -E "k8s-ap|k8s-as|k8s-master"
echo ""

echo "Step 2: Applying updated deployment configuration..."
echo "-----------------------------------------------------"
kubectl apply -f kubernetes/deployments/deployment.yaml
echo "✓ Deployment configuration applied"
echo ""

echo "Step 3: Restarting deployments with nodeSelector..."
echo "---------------------------------------------------"

# Restart frontend services
echo "Restarting frontend services (k8s-ap-server)..."
kubectl rollout restart deployment/api-gateway
kubectl rollout restart deployment/admin-server

# Restart backend services
echo "Restarting backend services (k8s-as-server)..."
kubectl rollout restart deployment/customers-service
kubectl rollout restart deployment/vets-service
kubectl rollout restart deployment/visits-service

echo ""
echo "✓ All deployments restarted"
echo ""

echo "Step 4: Waiting for rollouts to complete..."
echo "--------------------------------------------"
kubectl rollout status deployment/api-gateway --timeout=300s
kubectl rollout status deployment/customers-service --timeout=300s
kubectl rollout status deployment/vets-service --timeout=300s

echo ""
echo "✓ Rollouts complete"
echo ""

echo "=== Pod Distribution Summary ==="
echo ""

echo "📍 Frontend Node (k8s-ap-server) - K8s-primary-agent:"
echo "------------------------------------------------------"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-ap-server 2>/dev/null || echo "  No pods scheduled yet"
echo ""

echo "📍 Backend Node (k8s-as-server) - K8s-secondary-agent:"
echo "-------------------------------------------------------"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-as-server 2>/dev/null || echo "  No pods scheduled yet"
echo ""

echo "=== All Pods Overview ==="
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
echo ""

echo "=== Configuration Complete! ==="
echo ""
echo "Pod assignments:"
echo "  Frontend (k8s-ap-server): api-gateway, admin-server"
echo "  Backend (k8s-as-server): customers-service, vets-service, visits-service"
echo "  Any node: config-server, discovery-server, infrastructure services"
echo ""
echo "To verify distribution anytime:"
echo "  kubectl get pods -o wide"
