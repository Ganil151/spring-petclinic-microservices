#!/bin/bash

# Script to create ArgoCD application for Spring Petclinic
# Run this after ArgoCD is installed

set -e

echo "=== Creating ArgoCD Application for Spring Petclinic ==="
echo ""

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ ArgoCD is not installed!"
    echo "Run ./install-argocd.sh first"
    exit 1
fi

echo "✓ ArgoCD is installed"
echo ""

# Prompt for Git repository URL
echo "Enter your Git repository URL:"
echo "Example: https://github.com/username/spring-petclinic-microservices"
read -p "Repository URL: " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "❌ Repository URL cannot be empty"
    exit 1
fi

# Prompt for target branch
read -p "Target branch (default: main): " TARGET_BRANCH
TARGET_BRANCH=${TARGET_BRANCH:-main}

# Prompt for manifests path
read -p "Path to Kubernetes manifests (default: kubernetes/deployments): " MANIFESTS_PATH
MANIFESTS_PATH=${MANIFESTS_PATH:-kubernetes/deployments}

# Create application using ArgoCD CLI
echo ""
echo "Creating ArgoCD application..."
echo ""

# Check if argocd CLI is available
if command -v argocd &> /dev/null; then
    echo "Using ArgoCD CLI..."
    
    # Get ArgoCD server address
    ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$ARGOCD_SERVER" ]; then
        # Try NodePort
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        ARGOCD_SERVER="${NODE_IP}:30443"
    fi
    
    echo "ArgoCD Server: $ARGOCD_SERVER"
    echo ""
    echo "Please login to ArgoCD (use admin and the password from installation)"
    argocd login $ARGOCD_SERVER --insecure
    
    # Create application
    argocd app create spring-petclinic \
        --repo $REPO_URL \
        --path $MANIFESTS_PATH \
        --revision $TARGET_BRANCH \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace default \
        --sync-policy automated \
        --auto-prune \
        --self-heal
    
    echo ""
    echo "✓ Application created via CLI"
    
else
    echo "ArgoCD CLI not found, creating via YAML..."
    
    # Create temporary YAML file
    cat > /tmp/petclinic-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: spring-petclinic
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: $TARGET_BRANCH
    path: $MANIFESTS_PATH
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
EOF
    
    kubectl apply -f /tmp/petclinic-app.yaml
    rm /tmp/petclinic-app.yaml
    
    echo "✓ Application created via YAML"
fi

echo ""
echo "=== Application Status ==="
kubectl get application -n argocd spring-petclinic
echo ""

echo "=== Next Steps ==="
echo ""
echo "1. View application in ArgoCD UI:"
echo "   https://<node-ip>:30443/applications/spring-petclinic"
echo ""
echo "2. Monitor sync status:"
echo "   kubectl get application -n argocd spring-petclinic -w"
echo ""
echo "3. Or use ArgoCD CLI:"
echo "   argocd app get spring-petclinic"
echo "   argocd app sync spring-petclinic"
echo ""
