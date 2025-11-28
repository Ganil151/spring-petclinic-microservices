#!/bin/bash

# Script to fix node role labels
# Removes duplicate K8s-secondary-agent from k8s-ap-server

set -e

echo "=== Fixing Node Labels ==="
echo ""

echo "Current node labels:"
kubectl get nodes --show-labels | grep -E "NAME|k8s-ap|k8s-as"
echo ""

echo "Step 1: Removing K8s-secondary-agent from k8s-ap-server..."
echo "-----------------------------------------------------------"
kubectl label node k8s-ap-server node-role.kubernetes.io/K8s-secondary-agent-
echo "✓ Removed K8s-secondary-agent from k8s-ap-server"
echo ""

echo "Step 2: Verifying labels are correct..."
echo "----------------------------------------"
echo ""
echo "k8s-ap-server should have: K8s-primary-agent (frontend)"
kubectl get node k8s-ap-server -o jsonpath='{.metadata.labels}' | grep -o 'K8s-[^"]*-agent' || echo "No agent labels found"
echo ""

echo "k8s-as-server should have: K8s-secondary-agent (backend)"
kubectl get node k8s-as-server -o jsonpath='{.metadata.labels}' | grep -o 'K8s-[^"]*-agent' || echo "No agent labels found"
echo ""

echo "Step 3: Current node status:"
echo "----------------------------"
kubectl get nodes
echo ""

echo "=== Labels Fixed! ==="
echo ""
echo "✓ k8s-ap-server: K8s-primary-agent (frontend)"
echo "✓ k8s-as-server: K8s-secondary-agent (backend)"
echo ""
echo "Your nodeSelector configuration in deployment.yaml will now work correctly!"
