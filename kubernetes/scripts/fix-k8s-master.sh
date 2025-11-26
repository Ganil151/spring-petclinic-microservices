#!/bin/bash

#############################################
# Kubernetes Master Auto-Fix Script
# Automatically fixes common issues
#############################################

set -e

echo "=========================================="
echo "Kubernetes Master Auto-Fix"
echo "=========================================="
echo ""
date
echo ""

CURRENT_USER=$(whoami)
echo "Running as: $CURRENT_USER"
echo ""

#############################################
# Fix 1: Configure kubectl
#############################################

echo "=========================================="
echo "Fix 1: Configuring kubectl"
echo "=========================================="
echo ""

if [ ! -f ~/.kube/config ]; then
    echo "Setting up kubectl config..."
    mkdir -p ~/.kube
    sudo cp /etc/kubernetes/admin.conf ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config
    echo "✓ kubectl configured"
else
    echo "✓ kubectl config already exists"
fi

# Add completion
if ! grep -q "kubectl completion bash" ~/.bashrc 2>/dev/null; then
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'complete -F __start_kubectl k' >> ~/.bashrc
    echo "✓ Added kubectl completion"
fi

echo ""

# Test kubectl
echo "Testing kubectl..."
if kubectl version --short 2>/dev/null || kubectl version 2>/dev/null; then
    echo "✓ kubectl is working"
else
    echo "✗ kubectl still not working"
    echo "Check API server: sudo systemctl status kube-apiserver"
    exit 1
fi

echo ""

#############################################
# Fix 2: Install Calico CNI
#############################################

echo "=========================================="
echo "Fix 2: Installing Calico CNI"
echo "=========================================="
echo ""

# Check if Calico is already installed
CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)

if [ "$CALICO_PODS" -gt 0 ]; then
    echo "✓ Calico is already installed"
    kubectl get pods -n kube-system -l k8s-app=calico-node
else
    echo "Installing Calico CNI..."
    echo ""
    
    # Install Tigera operator
    echo "Step 1: Installing Tigera operator..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    
    echo ""
    echo "Step 2: Installing Calico custom resources..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    
    echo ""
    echo "✓ Calico installation initiated"
    echo ""
    echo "Waiting 60 seconds for Calico to start..."
    sleep 60
    
    echo ""
    echo "Calico pod status:"
    kubectl get pods -n kube-system -l k8s-app=calico-node
fi

echo ""

#############################################
# Fix 3: Wait for Nodes to be Ready
#############################################

echo "=========================================="
echo "Fix 3: Waiting for Nodes to be Ready"
echo "=========================================="
echo ""

echo "Checking node status..."
kubectl get nodes

echo ""
echo "Waiting for nodes to become Ready (max 3 minutes)..."

for i in {1..36}; do
    NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || true)
    
    if [ "$NOT_READY" -eq 0 ]; then
        echo ""
        echo "✓ All nodes are Ready!"
        kubectl get nodes
        break
    fi
    
    echo "Attempt $i/36: $NOT_READY node(s) still NotReady, waiting..."
    sleep 5
done

echo ""

#############################################
# Fix 4: Wait for System Pods
#############################################

echo "=========================================="
echo "Fix 4: Waiting for System Pods"
echo "=========================================="
echo ""

echo "Checking system pod status..."
kubectl get pods -n kube-system

echo ""
echo "Waiting for all system pods to be Running (max 3 minutes)..."

for i in {1..36}; do
    PENDING=$(kubectl get pods -n kube-system --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    FAILED=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -cE "Error|CrashLoopBackOff|ImagePullBackOff" || true)
    
    if [ "$PENDING" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
        echo ""
        echo "✓ All system pods are Running!"
        kubectl get pods -n kube-system
        break
    fi
    
    echo "Attempt $i/36: $PENDING pending, $FAILED failed, waiting..."
    sleep 5
done

echo ""

#############################################
# Fix 5: Verify CoreDNS
#############################################

echo "=========================================="
echo "Fix 5: Verifying CoreDNS"
echo "=========================================="
echo ""

COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$COREDNS_RUNNING" -ge 2 ]; then
    echo "✓ CoreDNS is running"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
else
    echo "⚠ CoreDNS may not be fully ready yet"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
fi

echo ""

#############################################
# Final Verification
#############################################

echo "=========================================="
echo "Final Verification"
echo "=========================================="
echo ""

echo "Cluster Status:"
kubectl get nodes
echo ""

echo "System Pods:"
kubectl get pods -n kube-system
echo ""

# Count issues
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || true)
PENDING=$(kubectl get pods -n kube-system --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
FAILED=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -cE "Error|CrashLoopBackOff" || true)

TOTAL_ISSUES=$((NOT_READY + PENDING + FAILED))

echo "=========================================="
echo "Fix Summary"
echo "=========================================="
echo ""

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo "✓ ALL ISSUES FIXED!"
    echo ""
    echo "Cluster is ready for deployments!"
    echo ""
    echo "Next steps:"
    echo "  1. Run diagnostic to confirm:"
    echo "     bash ~/spring-petclinic-microservices/kubernetes/scripts/diagnose-k8s-master.sh"
    echo ""
    echo "  2. Deploy applications:"
    echo "     kubectl apply -f ~/spring-petclinic-microservices/kubernetes/deployments/"
    echo ""
    echo "  3. Monitor deployment:"
    echo "     kubectl get pods -w"
    echo ""
else
    echo "⚠ Some issues may still exist:"
    echo "  NotReady nodes: $NOT_READY"
    echo "  Pending pods: $PENDING"
    echo "  Failed pods: $FAILED"
    echo ""
    echo "What to do:"
    echo "  1. Wait 2-3 more minutes for pods to stabilize"
    echo "  2. Run this script again: bash $0"
    echo "  3. Check logs: kubectl logs -n kube-system <pod-name>"
    echo "  4. Run diagnostic: bash ~/spring-petclinic-microservices/kubernetes/scripts/diagnose-k8s-master.sh"
fi

echo ""
echo "=========================================="
