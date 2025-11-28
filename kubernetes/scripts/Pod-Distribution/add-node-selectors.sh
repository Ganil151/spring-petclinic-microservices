#!/bin/bash

# Script to add nodeSelector configuration to existing deployments
# This will patch deployments to run on specific worker nodes

set -e

echo "=== Adding Node Selectors to Petclinic Deployments ==="
echo ""

# First, ensure nodes are labeled
echo "Step 1: Labeling worker nodes..."
kubectl label node k8s-ap-server workload-type=frontend zone=zone-a --overwrite
kubectl label node k8s-as-server workload-type=backend zone=zone-b --overwrite

echo "✓ Nodes labeled"
echo ""

# API Gateway and Admin Server -> Frontend Node (k8s-ap-server)
echo "Step 2: Assigning API Gateway to frontend node..."
kubectl patch deployment api-gateway -p '{"spec":{"template":{"spec":{"nodeSelector":{"workload-type":"frontend"}}}}}'

echo "Step 3: Assigning Admin Server to frontend node..."
kubectl patch deployment admin-server -p '{"spec":{"template":{"spec":{"nodeSelector":{"workload-type":"frontend"}}}}}'

# Backend Services -> Backend Node (k8s-as-server)
echo "Step 4: Assigning Customers Service to backend node..."
kubectl patch deployment customers-service -p '{"spec":{"template":{"spec":{"nodeSelector":{"workload-type":"backend"}}}}}'

echo "Step 5: Assigning Vets Service to backend node..."
kubectl patch deployment vets-service -p '{"spec":{"template":{"spec":{"nodeSelector":{"workload-type":"backend"}}}}}'

echo "Step 6: Assigning Visits Service to backend node..."
kubectl patch deployment visits-service -p '{"spec":{"template":{"spec":{"nodeSelector":{"workload-type":"backend"}}}}}'

# Infrastructure services (config-server, discovery-server) - allow on any worker node
# GenAI Service - allow on any worker node
# Prometheus, Tracing - allow on any worker node

echo ""
echo "✓ Node selectors applied!"
echo ""

echo "=== Restarting Deployments to Apply Changes ==="
kubectl rollout restart deployment api-gateway
kubectl rollout restart deployment admin-server
kubectl rollout restart deployment customers-service
kubectl rollout restart deployment vets-service
kubectl rollout restart deployment visits-service

echo ""
echo "Waiting for rollouts to complete..."
kubectl rollout status deployment api-gateway
kubectl rollout status deployment customers-service

echo ""
echo "=== Current Pod Distribution ==="
echo ""
echo "Pods on k8s-ap-server (frontend):"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-ap-server

echo ""
echo "Pods on k8s-as-server (backend):"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-as-server

echo ""
echo "All pods:"
kubectl get pods -o wide

echo ""
echo "=== Distribution Summary ==="
echo "✓ API Gateway → k8s-ap-server (frontend)"
echo "✓ Admin Server → k8s-ap-server (frontend)"
echo "✓ Customers Service → k8s-as-server (backend)"
echo "✓ Vets Service → k8s-as-server (backend)"
echo "✓ Visits Service → k8s-as-server (backend)"
echo "✓ Infrastructure services → any worker node"
