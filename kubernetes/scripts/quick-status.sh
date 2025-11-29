#!/bin/bash

# Quick status check - shows actual pod states including CrashLoopBackOff

echo "=== Quick Cluster Status ==="
echo ""

echo "All Pods:"
kubectl get pods -o wide
echo ""

echo "Pods with Issues:"
kubectl get pods | grep -v "Running.*1/1\|Running.*2/2\|NAME" || echo "None found"
echo ""

echo "Summary:"
echo "--------"
kubectl get pods --no-headers | awk '{print $3}' | sort | uniq -c
echo ""

echo "Deployment Status:"
kubectl get deployments -o wide
