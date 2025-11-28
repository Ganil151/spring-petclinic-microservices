#!/bin/bash

# Script to show pod distribution across worker nodes
# Run this on the master node

echo "=== Pod Distribution Across Worker Nodes ==="
echo ""

echo "📍 Pods on k8s-ap-server (Frontend Node):"
echo "==========================================="
kubectl get pods -o wide --field-selector spec.nodeName=k8s-ap-server --no-headers 2>/dev/null | wc -l | xargs echo "Total pods:"
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName --field-selector spec.nodeName=k8s-ap-server
echo ""

echo "📍 Pods on k8s-as-server (Backend Node):"
echo "========================================="
kubectl get pods -o wide --field-selector spec.nodeName=k8s-as-server --no-headers 2>/dev/null | wc -l | xargs echo "Total pods:"
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName --field-selector spec.nodeName=k8s-as-server
echo ""

echo "📍 Pods on k8s-master-server (Control Plane):"
echo "=============================================="
kubectl get pods -o wide --field-selector spec.nodeName=k8s-master-server --no-headers 2>/dev/null | wc -l | xargs echo "Total pods:"
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName --field-selector spec.nodeName=k8s-master-server
echo ""

echo "=== Summary by Service ==="
echo ""
for service in api-gateway admin-server customers-service vets-service visits-service config-server discovery-server; do
    echo "Service: $service"
    kubectl get pods -l app=$service -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName --no-headers 2>/dev/null || echo "  No pods found"
    echo ""
done

echo "=== Node Distribution Summary ==="
echo ""
kubectl get pods -o wide --no-headers | awk '{print $7}' | sort | uniq -c | awk '{print $2": "$1" pods"}'
echo ""

echo "=== All Pods Overview ==="
kubectl get pods -o wide
