#!/bin/bash
# Diagnose pod startup issues

echo "=== Pod Status ==="
kubectl get pods -o wide

echo -e "\n=== Config Server Pod Details ==="
kubectl describe pod -l app=config-server

echo -e "\n=== Config Server Logs ==="
kubectl logs -l app=config-server --tail=50

echo -e "\n=== Node Resources ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

echo -e "\n=== Events ==="
kubectl get events --sort-by='.lastTimestamp' | tail -20
