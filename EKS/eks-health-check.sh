#!/bin/bash
# EKS & Kubernetes Health Check and Diagnostic Script
# Run this to verify EKS cluster and kubectl setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header "EKS & Kubernetes Health Check"
echo ""

# 1. Check kubectl installation
print_info "1. Checking kubectl installation..."
if command -v kubectl &>/dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)
    print_success "kubectl is installed: $KUBECTL_VERSION"
else
    print_error "kubectl is NOT installed"
    exit 1
fi
echo ""

# 2. Check AWS CLI
print_info "2. Checking AWS CLI installation..."
if command -v aws &>/dev/null; then
    AWS_VERSION=$(aws --version)
    print_success "AWS CLI is installed: $AWS_VERSION"
else
    print_warning "AWS CLI is NOT installed"
fi
echo ""

# 3. Check eksctl
print_info "3. Checking eksctl installation..."
if command -v eksctl &>/dev/null; then
    EKSCTL_VERSION=$(eksctl version)
    print_success "eksctl is installed: $EKSCTL_VERSION"
else
    print_warning "eksctl is NOT installed"
fi
echo ""

# 4. Check cluster connection
print_info "4. Checking cluster connection..."
if kubectl cluster-info &>/dev/null; then
    print_success "Connected to Kubernetes cluster"
    kubectl cluster-info | head -2
else
    print_error "NOT connected to any cluster"
    print_info "Configure with: aws eks update-kubeconfig --name <cluster-name> --region <region>"
    exit 1
fi
echo ""

# 5. Get current context
print_info "5. Checking current context..."
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
if [ "$CURRENT_CONTEXT" != "none" ]; then
    print_success "Current context: $CURRENT_CONTEXT"
else
    print_warning "No context set"
fi
echo ""

# 6. Check nodes
print_info "6. Checking cluster nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODE_COUNT" -gt 0 ]; then
    print_success "Found $NODE_COUNT nodes"
    kubectl get nodes
else
    print_warning "No nodes found in cluster"
fi
echo ""

# 7. Check node health
if [ "$NODE_COUNT" -gt 0 ]; then
    print_info "7. Checking node health..."
    NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)
    if [ "$NOT_READY" -eq 0 ]; then
        print_success "All nodes are Ready"
    else
        print_warning "$NOT_READY nodes are NOT Ready"
        kubectl get nodes | grep -v " Ready "
    fi
    echo ""
fi

# 8. Check namespaces
print_info "8. Checking namespaces..."
kubectl get namespaces
echo ""

# 9. Check pods in all namespaces
print_info "9. Checking pods across all namespaces..."
TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep Running | wc -l)
print_info "Total pods: $TOTAL_PODS, Running: $RUNNING_PODS"
echo ""

# 10. Check for non-running pods
print_info "10. Checking for problematic pods..."
PROBLEM_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l)
if [ "$PROBLEM_PODS" -gt 0 ]; then
    print_warning "Found $PROBLEM_PODS pods not in Running state"
    kubectl get pods -A | grep -v Running | grep -v Completed | grep -v NAMESPACE
else
    print_success "All pods are running or completed"
fi
echo ""

# 11. Check system pods
print_info "11. Checking system pods (kube-system)..."
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
SYSTEM_RUNNING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep Running | wc -l)
if [ "$SYSTEM_PODS" -eq "$SYSTEM_RUNNING" ]; then
    print_success "All $SYSTEM_PODS system pods are running"
else
    print_warning "Some system pods are not running"
    kubectl get pods -n kube-system | grep -v Running
fi
echo ""

# 12. Check deployments
print_info "12. Checking deployments..."
DEPLOYMENTS=$(kubectl get deployments -A --no-headers 2>/dev/null | wc -l)
if [ "$DEPLOYMENTS" -gt 0 ]; then
    print_success "Found $DEPLOYMENTS deployments"
    kubectl get deployments -A
else
    print_info "No deployments found"
fi
echo ""

# 13. Check services
print_info "13. Checking services..."
SERVICES=$(kubectl get services -A --no-headers 2>/dev/null | wc -l)
if [ "$SERVICES" -gt 0 ]; then
    print_success "Found $SERVICES services"
    kubectl get services -A
else
    print_info "No services found"
fi
echo ""

# 14. Check for LoadBalancer services
print_info "14. Checking LoadBalancer services..."
LB_SERVICES=$(kubectl get services -A --no-headers 2>/dev/null | grep LoadBalancer | wc -l)
if [ "$LB_SERVICES" -gt 0 ]; then
    print_success "Found $LB_SERVICES LoadBalancer services"
    kubectl get services -A | grep LoadBalancer
else
    print_info "No LoadBalancer services found"
fi
echo ""

# 15. Check resource usage
if [ "$NODE_COUNT" -gt 0 ]; then
    print_info "15. Checking resource usage..."
    if kubectl top nodes &>/dev/null; then
        kubectl top nodes
    else
        print_warning "Metrics server not available. Install with: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    fi
    echo ""
fi

# 16. Check pod resource usage
if [ "$TOTAL_PODS" -gt 0 ]; then
    print_info "16. Checking pod resource usage..."
    if kubectl top pods -A &>/dev/null; then
        kubectl top pods -A | head -10
    else
        print_warning "Metrics server not available"
    fi
    echo ""
fi

# 17. Check for pending pods
print_info "17. Checking for pending pods..."
PENDING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep Pending | wc -l)
if [ "$PENDING_PODS" -gt 0 ]; then
    print_warning "Found $PENDING_PODS pending pods"
    kubectl get pods -A | grep Pending
else
    print_success "No pending pods"
fi
echo ""

# 18. Check for CrashLoopBackOff pods
print_info "18. Checking for CrashLoopBackOff pods..."
CRASH_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep CrashLoopBackOff | wc -l)
if [ "$CRASH_PODS" -gt 0 ]; then
    print_error "Found $CRASH_PODS pods in CrashLoopBackOff"
    kubectl get pods -A | grep CrashLoopBackOff
else
    print_success "No pods in CrashLoopBackOff"
fi
echo ""

# 19. Check events
print_info "19. Checking recent cluster events..."
WARNING_EVENTS=$(kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null | grep Warning | wc -l)
if [ "$WARNING_EVENTS" -gt 0 ]; then
    print_warning "Found $WARNING_EVENTS warning events"
    kubectl get events -A --sort-by='.lastTimestamp' | grep Warning | tail -5
else
    print_success "No warning events"
fi
echo ""

# 20. Check ConfigMaps
print_info "20. Checking ConfigMaps..."
CONFIGMAPS=$(kubectl get configmaps -A --no-headers 2>/dev/null | wc -l)
print_info "Found $CONFIGMAPS ConfigMaps"
echo ""

# 21. Check Secrets
print_info "21. Checking Secrets..."
SECRETS=$(kubectl get secrets -A --no-headers 2>/dev/null | wc -l)
print_info "Found $SECRETS Secrets"
echo ""

# 22. Check Persistent Volumes
print_info "22. Checking Persistent Volumes..."
PVS=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
if [ "$PVS" -gt 0 ]; then
    print_success "Found $PVS Persistent Volumes"
    kubectl get pv
else
    print_info "No Persistent Volumes found"
fi
echo ""

# 23. Check Persistent Volume Claims
print_info "23. Checking Persistent Volume Claims..."
PVCS=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
if [ "$PVCS" -gt 0 ]; then
    print_success "Found $PVCS Persistent Volume Claims"
    kubectl get pvc -A
else
    print_info "No Persistent Volume Claims found"
fi
echo ""

# 24. Check Ingress
print_info "24. Checking Ingress resources..."
INGRESSES=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
if [ "$INGRESSES" -gt 0 ]; then
    print_success "Found $INGRESSES Ingress resources"
    kubectl get ingress -A
else
    print_info "No Ingress resources found"
fi
echo ""

# 25. Check for Spring Petclinic services
print_info "25. Checking for Spring Petclinic services..."
PETCLINIC_SERVICES=("config-server" "discovery-server" "customers-service" "visits-service" "vets-service" "api-gateway")

for service in "${PETCLINIC_SERVICES[@]}"; do
    if kubectl get deployment "$service" &>/dev/null; then
        REPLICAS=$(kubectl get deployment "$service" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
        DESIRED=$(kubectl get deployment "$service" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        if [ "$REPLICAS" = "$DESIRED" ] && [ "$REPLICAS" != "0" ]; then
            print_success "$service: $REPLICAS/$DESIRED replicas available"
        else
            print_warning "$service: $REPLICAS/$DESIRED replicas available"
        fi
    else
        print_info "$service: not deployed"
    fi
done
echo ""

# 26. Check AWS EKS cluster (if eksctl available)
if command -v eksctl &>/dev/null && command -v aws &>/dev/null; then
    print_info "26. Checking AWS EKS cluster info..."
    CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | awk -F'/' '{print $2}' || echo "unknown")
    if [ "$CLUSTER_NAME" != "unknown" ]; then
        print_info "Cluster name: $CLUSTER_NAME"
        
        # Try to get cluster info from AWS
        if aws eks describe-cluster --name "$CLUSTER_NAME" &>/dev/null; then
            CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.status' --output text 2>/dev/null || echo "unknown")
            CLUSTER_VERSION=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.version' --output text 2>/dev/null || echo "unknown")
            print_info "Cluster status: $CLUSTER_STATUS"
            print_info "Cluster version: $CLUSTER_VERSION"
        fi
    fi
    echo ""
fi

# Summary
print_header "Health Check Complete"
echo ""

# Recommendations
print_info "Summary:"
echo "  • Nodes: $NODE_COUNT"
echo "  • Total Pods: $TOTAL_PODS (Running: $RUNNING_PODS)"
echo "  • Deployments: $DEPLOYMENTS"
echo "  • Services: $SERVICES"
echo "  • Pending Pods: $PENDING_PODS"
echo "  • CrashLoopBackOff Pods: $CRASH_PODS"
echo ""

if [ "$CRASH_PODS" -gt 0 ] || [ "$PENDING_PODS" -gt 5 ]; then
    print_warning "Action Required:"
    if [ "$CRASH_PODS" -gt 0 ]; then
        echo "  • Investigate CrashLoopBackOff pods: kubectl logs <pod-name> --previous"
    fi
    if [ "$PENDING_PODS" -gt 5 ]; then
        echo "  • Check pending pods: kubectl describe pod <pod-name>"
    fi
    echo ""
fi

print_info "For more commands, see: EKS_COMMAND_REFERENCE.md"
print_info "To view pod logs: kubectl logs -f <pod-name>"
print_info "To describe resources: kubectl describe <resource-type> <resource-name>"
