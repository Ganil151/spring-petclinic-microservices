#!/bin/bash

# check-worker-nodes.sh
# Comprehensive health check for Kubernetes worker nodes

echo "=== Kubernetes Worker Node Health Check ==="
echo ""

# 1. Check Node Status
echo "Step 1: Node Status and Roles"
echo "==============================="
kubectl get nodes -o wide
echo ""

# 2. Check Node Resources
echo "Step 2: Node Resource Usage"
echo "==============================="
kubectl top nodes 2>/dev/null || echo "⚠️  Metrics Server not installed. Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
echo ""

# 3. Check Pod Distribution
echo "Step 3: Pod Distribution Across Nodes"
echo "==============================="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "Node: $node"
    kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$node | grep -v "NAMESPACE" | wc -l | xargs echo "  Pod count:"
    echo ""
done

# 4. Check Pods on Each Worker Node
echo "Step 4: Pods Running on Worker Nodes"
echo "==============================="
kubectl get pods -o wide | grep -E "k8s-kp-server|k8s-ks-server" || echo "No pods on worker nodes"
echo ""

# 5. Check for Failed/Unhealthy Pods
echo "Step 5: Unhealthy Pods"
echo "==============================="
kubectl get pods --all-namespaces | grep -vE "Running|Completed" || echo "✓ All pods are healthy"
echo ""

# 6. Check Critical System Pods
echo "Step 6: System Pods (Calico, kube-proxy, etc.)"
echo "==============================="
kubectl get pods -n kube-system -o wide
echo ""
kubectl get pods -n calico-system -o wide 2>/dev/null || echo "Calico pods in kube-system namespace"
echo ""

# 7. Check Service Endpoints
echo "Step 7: Service Endpoints"
echo "==============================="
kubectl get endpoints | grep -E "config-server|discovery-server|api-gateway"
echo ""

# 8. Test Pod-to-Pod Communication
echo "Step 8: Pod-to-Pod Network Test"
echo "==============================="
CONFIG_POD=$(kubectl get pods -l app=config-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CONFIG_POD" ]; then
    echo "Testing from $CONFIG_POD to discovery-server..."
    kubectl exec $CONFIG_POD -- wget -q -O- http://discovery-server:8761/actuator/health 2>&1 | head -5 || echo "⚠️  Connection test failed"
else
    echo "⚠️  Config server pod not found"
fi
echo ""

# 9. Check DNS Resolution
echo "Step 9: DNS Resolution Test"
echo "==============================="
kubectl run dns-test --image=busybox --rm -it --restart=Never --command -- nslookup kubernetes.default 2>&1 | head -10 || echo "DNS test pod may still be running"
echo ""

# 10. Summary
echo "Step 10: Health Summary"
echo "==============================="
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
TOTAL_PODS=$(kubectl get pods --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods --no-headers | grep "Running" | wc -l)
READY_PODS=$(kubectl get pods --no-headers | grep "1/1" | wc -l)

echo "Nodes:      $READY_NODES / $TOTAL_NODES Ready"
echo "Pods:       $RUNNING_PODS / $TOTAL_PODS Running"
echo "Ready Pods: $READY_PODS / $TOTAL_PODS"
echo ""

if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$READY_PODS" -gt 0 ]; then
    echo "✓ Cluster appears healthy!"
else
    echo "⚠️  Some issues detected. Check details above."
fi

echo ""
echo "=== End of Health Check ==="
