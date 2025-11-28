#!/bin/bash

# Script to install and configure ArgoCD for Spring Petclinic Microservices
# Run this on your Kubernetes master node

set -e

echo "=== Installing ArgoCD on Kubernetes Cluster ==="
echo ""

# Step 1: Create ArgoCD namespace
echo "Step 1: Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespace created"
echo ""

# Step 2: Install ArgoCD
echo "Step 2: Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "✓ ArgoCD installed"
echo ""

# Step 3: Wait for ArgoCD to be ready
echo "Step 3: Waiting for ArgoCD pods to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=600s
echo "✓ ArgoCD is ready"
echo ""

# Step 4: Expose ArgoCD server via NodePort
echo "Step 4: Exposing ArgoCD server via NodePort (port 30443)..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "nodePort": 30443, "name": "https", "targetPort": 8080}]}}'
echo "✓ ArgoCD server exposed on port 30443"
echo ""

# Step 5: Get initial admin password
echo "Step 5: Retrieving initial admin password..."
echo ""
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "================================================"
echo "ArgoCD Installation Complete!"
echo "================================================"
echo ""
echo "Access ArgoCD UI at:"
echo "  https://<your-node-ip>:30443"
echo ""
echo "Login Credentials:"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "================================================"
echo ""

# Step 6: Get node IP addresses
echo "Your Kubernetes Nodes:"
kubectl get nodes -o wide | awk '{print $1"\t"$6}'
echo ""

# Step 7: Verification
echo "Step 6: Verifying ArgoCD components..."
echo ""
kubectl get all -n argocd
echo ""

echo "=== Next Steps ==="
echo ""
echo "1. Access ArgoCD UI: https://<node-ip>:30443"
echo "2. Login with credentials above"
echo "3. Change admin password (recommended)"
echo "4. Create ArgoCD application for Spring Petclinic"
echo ""
echo "To create the application, run:"
echo "  kubectl apply -f kubernetes/argocd/argocd-application.yaml"
echo ""
echo "For detailed instructions, see:"
echo "  kubernetes/argocd/ARGOCD_SETUP_GUIDE.md"
