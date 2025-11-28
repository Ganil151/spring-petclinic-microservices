#!/bin/bash

#############################################
# Kubernetes Master Complete Fix Script
# Combines kubectl config, Calico install, and fixes NotReady nodes
#############################################

set -e

echo "=========================================="
echo "Kubernetes Master Complete Fix"
echo "=========================================="
echo ""
date
echo ""

CURRENT_USER=$(whoami)
echo "Running as: $CURRENT_USER"
echo ""

#############################################
# Step 1: Configure kubectl
#############################################

echo "=========================================="
echo "Step 1: Configuring kubectl"
echo "=========================================="
echo ""

if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "✗ ERROR: /etc/kubernetes/admin.conf not found"
    echo ""
    echo "Kubernetes is not installed yet. Please wait for installation to complete."
    echo "Check status: sudo systemctl status kubelet"
    exit 1
fi

echo "✓ Found /etc/kubernetes/admin.conf"
echo ""

# Create .kube directory
mkdir -p ~/.kube

# Copy admin.conf
echo "Copying kubectl config..."
sudo cp /etc/kubernetes/admin.conf ~/.kube/config

# Fix ownership
echo "Setting ownership for $CURRENT_USER..."
sudo chown $(id -u):$(id -g) ~/.kube/config

# Fix permissions
chmod 600 ~/.kube/config

echo "✓ kubectl config created"
echo ""

# Add kubectl completion if not already present
if ! grep -q "kubectl completion bash" ~/.bashrc 2>/dev/null; then
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'complete -F __start_kubectl k' >> ~/.bashrc
    echo "✓ Added kubectl completion to ~/.bashrc"
    echo ""
fi

# Test kubectl
echo "Testing kubectl..."
if kubectl version --short 2>/dev/null || kubectl version 2>/dev/null; then
    echo "✓ kubectl is working!"
else
    echo "✗ kubectl test failed"
    exit 1
fi

echo ""

#############################################
# Step 2: Check Current Cluster Status
#############################################

echo "=========================================="
echo "Step 2: Checking Current Cluster Status"
echo "=========================================="
echo ""

echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "System Pods:"
kubectl get pods -n kube-system

echo ""

#############################################
# Step 3: Install/Verify Calico CNI
#############################################

echo "=========================================="
echo "Step 3: Installing/Verifying Calico CNI"
echo "=========================================="
echo ""

# Check if Calico is already installed
CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)
TIGERA_OPERATOR=$(kubectl get pods -n tigera-operator --no-headers 2>/dev/null | wc -l)

echo "Calico pods found: $CALICO_PODS"
echo "Tigera operator pods found: $TIGERA_OPERATOR"
echo ""

if [ "$CALICO_PODS" -eq 0 ] && [ "$TIGERA_OPERATOR" -eq 0 ]; then
    echo "⚠ Calico is NOT installed - installing now..."
    echo ""
    
    # Install Calico operator
    echo "Installing Tigera operator..."
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    
    echo ""
    echo "Waiting 10 seconds for operator to initialize..."
    sleep 10
    
    echo ""
    echo "Installing Calico custom resources..."
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
    kubectl get pods -n kube-system -l k8s-app=calico-node
    echo ""
    
    # Check if they're running
    RUNNING_CALICO=$(kubectl get pods -n kube-system -l k8s-app=calico-node --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    if [ "$RUNNING_CALICO" -eq "$CALICO_PODS" ]; then
        echo "✓ All Calico pods are running"
    else
        echo "⚠ Some Calico pods are not running yet ($RUNNING_CALICO/$CALICO_PODS)"
    fi
fi

echo ""

#############################################
# Step 4: Wait for Calico to Deploy
#############################################

echo "=========================================="
echo "Step 4: Waiting for Calico to Deploy"
echo "=========================================="
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

echo "=========================================="
echo "Step 5: Waiting for Nodes to be Ready"
echo "=========================================="
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
kubectl get nodes -o wide
echo ""

#############################################
# Step 6: Verify CoreDNS
#############################################

echo "=========================================="
echo "Step 6: Verifying CoreDNS"
echo "=========================================="
echo ""

COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)
COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$COREDNS_PODS" -gt 0 ]; then
    echo "CoreDNS pods: $COREDNS_RUNNING/$COREDNS_PODS running"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    
    if [ "$COREDNS_RUNNING" -eq "$COREDNS_PODS" ]; then
        echo ""
        echo "✓ CoreDNS is fully running"
    else
        echo ""
        echo "⚠ CoreDNS pods are not all running yet"
        echo "They should start once Calico is fully operational"
    fi
else
    echo "⚠ CoreDNS not found"
fi

echo ""

#############################################
# Step 7: Final Status Check
#############################################

echo "=========================================="
echo "Step 7: Final Status Check"
echo "=========================================="
echo ""

echo "All Nodes:"
kubectl get nodes -o wide
echo ""

echo "All System Pods:"
kubectl get pods -n kube-system -o wide
echo ""

#############################################
# Summary
#############################################

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

# Count pods
TOTAL_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -n kube-system --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PENDING_PODS=$(kubectl get pods -n kube-system --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
FAILED_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -cE "Error|CrashLoopBackOff" || true)

echo "System Pods Status:"
echo "  Running: $RUNNING_PODS"
echo "  Pending: $PENDING_PODS"
echo "  Failed: $FAILED_PODS"
echo "  Total: $TOTAL_PODS"
echo ""

# Check overall health
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || true)

echo "Nodes: $READY_NODES/$TOTAL_NODES Ready"
echo ""

if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$RUNNING_PODS" -ge 6 ] && [ "$FAILED_PODS" -eq 0 ]; then
    echo "=========================================="
    echo "✓ SUCCESS - Cluster is Healthy!"
    echo "=========================================="
    echo ""
    echo "Your cluster is now ready for deployments!"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Deploy Spring Petclinic:"
    echo "   kubectl apply -f ~/spring-petclinic-microservices/kubernetes/deployments/"
    echo ""
    echo "2. Monitor deployment:"
    echo "   kubectl get pods -w"
    echo ""
    echo "3. Check services:"
    echo "   kubectl get services"
    echo ""
else
    echo "=========================================="
    echo "⚠ Cluster Needs More Time"
    echo "=========================================="
    echo ""
    
    if [ "$NOT_READY" -gt 0 ]; then
        echo "Issues found:"
        echo "  - $NOT_READY node(s) still NotReady"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check Calico logs:"
        CALICO_POD=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | head -1 | awk '{print $1}')
        if [ -n "$CALICO_POD" ]; then
            echo "     kubectl logs -n kube-system $CALICO_POD"
        fi
        echo ""
        echo "  2. Check node details:"
        echo "     kubectl describe node k8s-master-server"
        echo "     kubectl describe node k8s-worker-server"
        echo ""
        echo "  3. Wait 2-3 more minutes, then run:"
        echo "     bash $0"
    fi
    
    if [ "$PENDING_PODS" -gt 0 ]; then
        echo "  - $PENDING_PODS pod(s) are pending"
        echo "    They will start once nodes are Ready"
    fi
    
    if [ "$FAILED_PODS" -gt 0 ]; then
        echo "  - $FAILED_PODS pod(s) are failing"
        echo "    Check logs: kubectl logs -n kube-system <pod-name>"
    fi
    
    echo ""
fi

echo "=========================================="
echo ""
echo "Useful Commands:"
echo "  kubectl get nodes                    # Check node status"
echo "  kubectl get pods -A                  # Check all pods"
echo "  kubectl get pods -n kube-system -w   # Watch system pods"
echo "  kubectl logs -n kube-system <pod>    # Check pod logs"
echo "  kubectl describe node <node-name>    # Node details"
echo ""
echo "=========================================="
