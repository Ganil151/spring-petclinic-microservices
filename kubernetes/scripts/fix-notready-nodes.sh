#!/bin/bash

#############################################
# Fix NotReady Nodes - Install Calico CNI
# This is the most common cause of NotReady status
#############################################

set -e

echo "=========================================="
echo "Fixing NotReady Nodes - Installing Calico"
echo "=========================================="
echo ""
date
echo ""

#############################################
# Step 1: Check Current Status
#############################################

echo "=== Current Cluster Status ==="
echo ""

echo "Nodes:"
kubectl get nodes
echo ""

echo "System Pods:"
kubectl get pods -n kube-system
echo ""

#############################################
# Step 2: Check for Calico
#############################################

echo "=== Checking for Calico CNI ==="
echo ""

CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)
TIGERA_OPERATOR=$(kubectl get pods -n tigera-operator --no-headers 2>/dev/null | wc -l)

echo "Calico pods found: $CALICO_PODS"
echo "Tigera operator pods found: $TIGERA_OPERATOR"
echo ""

if [ "$CALICO_PODS" -eq 0 ] && [ "$TIGERA_OPERATOR" -eq 0 ]; then
    echo "⚠ Calico is NOT installed - this is why nodes are NotReady"
    echo ""
    
    #############################################
    # Step 3: Install Calico
    #############################################
    
    echo "=== Installing Calico CNI ==="
    echo ""
    
    echo "Step 1/2: Installing Tigera Operator..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    
    echo ""
    echo "Waiting 10 seconds for operator to initialize..."
    sleep 10
    
    echo ""
    echo "Step 2/2: Installing Calico Custom Resources..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    
    echo ""
    echo "✓ Calico installation initiated"
    
elif [ "$TIGERA_OPERATOR" -gt 0 ] && [ "$CALICO_PODS" -eq 0 ]; then
    echo "⚠ Tigera operator exists but Calico pods not created yet"
    echo "Installing custom resources..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml 2>/dev/null || echo "Custom resources may already exist"
    
else
    echo "✓ Calico components found"
    echo ""
    echo "Calico pod status:"
    kubectl get pods -n kube-system -l k8s-app=calico-node
    echo ""
    
    # Check if they're running
    RUNNING_CALICO=$(kubectl get pods -n kube-system -l k8s-app=calico-node --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    if [ "$RUNNING_CALICO" -lt "$CALICO_PODS" ]; then
        echo "⚠ Some Calico pods are not running yet"
        echo "Checking pod details..."
        kubectl describe pods -n kube-system -l k8s-app=calico-node | grep -A 5 "Events:"
    fi
fi

echo ""

#############################################
# Step 4: Wait for Calico to Deploy
#############################################

echo "=== Waiting for Calico to Deploy ==="
echo ""

echo "This may take 2-3 minutes..."
echo ""

for i in {1..60}; do
    CALICO_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=calico-node --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    CALICO_TOTAL=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)
    
    if [ "$CALICO_TOTAL" -gt 0 ] && [ "$CALICO_RUNNING" -eq "$CALICO_TOTAL" ]; then
        echo ""
        echo "✓ All Calico pods are running!"
        break
    fi
    
    echo "[$i/60] Calico pods: $CALICO_RUNNING/$CALICO_TOTAL running, waiting..."
    sleep 5
done

echo ""
echo "Calico status:"
kubectl get pods -n kube-system -l k8s-app=calico-node
echo ""

#############################################
# Step 5: Wait for Nodes to be Ready
#############################################

echo "=== Waiting for Nodes to be Ready ==="
echo ""

echo "Once Calico is running, nodes should become Ready within 1-2 minutes..."
echo ""

for i in {1..24}; do
    NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || true)
    
    if [ "$NOT_READY" -eq 0 ]; then
        echo ""
        echo "✓ All nodes are Ready!"
        break
    fi
    
    echo "[$i/24] $NOT_READY node(s) still NotReady, waiting..."
    sleep 5
done

echo ""
kubectl get nodes
echo ""

#############################################
# Step 6: Verify CoreDNS
#############################################

echo "=== Checking CoreDNS ==="
echo ""

COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$COREDNS_RUNNING" -ge 2 ]; then
    echo "✓ CoreDNS is running"
else
    echo "⚠ CoreDNS may still be starting"
    echo ""
    kubectl get pods -n kube-system -l k8s-app=kube-dns
fi

echo ""

#############################################
# Final Status
#############################################

echo "=========================================="
echo "Final Status"
echo "=========================================="
echo ""

echo "Nodes:"
kubectl get nodes -o wide
echo ""

echo "All System Pods:"
kubectl get pods -n kube-system -o wide
echo ""

# Check if ready
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || true)

if [ "$NOT_READY" -eq 0 ]; then
    echo "=========================================="
    echo "✓ SUCCESS - All Nodes are Ready!"
    echo "=========================================="
    echo ""
    echo "Your cluster is now healthy and ready for deployments!"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy Spring Petclinic:"
    echo "     kubectl apply -f ~/spring-petclinic-microservices/kubernetes/deployments/"
    echo ""
    echo "  2. Monitor deployment:"
    echo "     kubectl get pods -w"
    echo ""
else
    echo "=========================================="
    echo "⚠ $NOT_READY Node(s) Still NotReady"
    echo "=========================================="
    echo ""
    echo "Troubleshooting:"
    echo ""
    echo "1. Check Calico logs:"
    CALICO_POD=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | head -1 | awk '{print $1}')
    if [ -n "$CALICO_POD" ]; then
        echo "   kubectl logs -n kube-system $CALICO_POD"
    fi
    echo ""
    echo "2. Check node details:"
    echo "   kubectl describe node k8s-master-server"
    echo "   kubectl describe node k8s-worker-server"
    echo ""
    echo "3. Wait a bit longer (Calico can take 3-5 minutes)"
    echo "   Then run this script again: bash $0"
    echo ""
fi

echo "=========================================="
