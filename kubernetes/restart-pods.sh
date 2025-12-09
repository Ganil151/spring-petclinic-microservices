#!/bin/bash
# Restart pods in correct order

echo "Deleting failed pods..."
kubectl delete pod -l app=config-server --force --grace-period=0 2>/dev/null
kubectl delete pod -l app=discovery-server --force --grace-period=0 2>/dev/null
kubectl delete pod -l app=customers-service --force --grace-period=0 2>/dev/null
kubectl delete pod -l app=vets-service --force --grace-period=0 2>/dev/null
kubectl delete pod -l app=visits-service --force --grace-period=0 2>/dev/null
kubectl delete pod -l app=api-gateway --force --grace-period=0 2>/dev/null
kubectl delete pod -l app=admin-server --force --grace-period=0 2>/dev/null

echo "Waiting for pods to restart..."
sleep 10

echo "Checking pod status..."
kubectl get pods -o wide
