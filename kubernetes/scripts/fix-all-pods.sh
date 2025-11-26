#!/bin/bash

echo "=========================================="
echo "Kubernetes Pods Complete Fix Script"
echo "=========================================="
echo ""
date
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as correct user
echo "=== Checking kubectl configuration ==="
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ kubectl is not configured properly${NC}"
    echo ""
    echo "If you ran this with 'sudo', try running without sudo:"
    echo "  bash $0"
    echo ""
    echo "If kubectl is not configured for your user, run:"
    echo "  mkdir -p ~/.kube"
    echo "  sudo cp /etc/kubernetes/admin.conf ~/.kube/config"
    echo "  sudo chown \$(id -u):\$(id -g) ~/.kube/config"
    exit 1
fi

echo -e "${GREEN}✓ kubectl is configured${NC}"
echo ""

# Set the kubernetes directory path
KUBE_DIR="$HOME/spring-petclinic-microservices/kubernetes/deployments"

if [ ! -d "$KUBE_DIR" ]; then
    echo -e "${RED}✗ Kubernetes deployments directory not found at: $KUBE_DIR${NC}"
    echo "Please update KUBE_DIR variable in this script"
    exit 1
fi

echo -e "${GREEN}✓ Found kubernetes deployments directory${NC}"
echo ""

# Step 1: Check current status
echo "=========================================="
echo "STEP 1: Current Cluster Status"
echo "=========================================="
echo ""

echo "--- Current Pods ---"
kubectl get pods
echo ""

echo "--- Current Services ---"
kubectl get services
echo ""

echo "--- Current Deployments ---"
kubectl get deployments
echo ""

# Step 2: Apply all YAML files to ensure services exist
echo "=========================================="
echo "STEP 2: Applying All Deployment Files"
echo "=========================================="
echo ""

echo "Applying YAML files from: $KUBE_DIR"
kubectl apply -f "$KUBE_DIR/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully applied all deployment files${NC}"
else
    echo -e "${RED}✗ Failed to apply deployment files${NC}"
    exit 1
fi
echo ""

# Step 3: Verify services were created
echo "=========================================="
echo "STEP 3: Verifying Services"
echo "=========================================="
echo ""

REQUIRED_SERVICES=(
    "config-server"
    "discovery-server"
    "admin-server"
    "api-gateway"
    "customers-service"
    "visits-service"
    "vets-service"
)

MISSING_SERVICES=0

for service in "${REQUIRED_SERVICES[@]}"; do
    if kubectl get service $service &>/dev/null; then
        echo -e "${GREEN}✓${NC} $service service exists"
    else
        echo -e "${RED}✗${NC} $service service is MISSING"
        MISSING_SERVICES=$((MISSING_SERVICES + 1))
    fi
done

echo ""

if [ $MISSING_SERVICES -gt 0 ]; then
    echo -e "${YELLOW}⚠ Warning: $MISSING_SERVICES service(s) are missing${NC}"
    echo "Attempting to create missing services manually..."
    echo ""
    
    # Create missing services manually
    for service in "${REQUIRED_SERVICES[@]}"; do
        if ! kubectl get service $service &>/dev/null; then
            echo "Creating $service service..."
            
            # Determine port based on service name
            case $service in
                "config-server")
                    kubectl expose deployment $service --port=8888 --target-port=8888 --name=$service 2>/dev/null
                    ;;
                "discovery-server")
                    kubectl expose deployment $service --port=8761 --target-port=8761 --name=$service 2>/dev/null
                    ;;
                "admin-server")
                    kubectl expose deployment $service --port=9090 --target-port=9090 --name=$service 2>/dev/null
                    ;;
                "api-gateway")
                    kubectl expose deployment $service --port=8080 --target-port=8080 --name=$service 2>/dev/null
                    ;;
                *)
                    kubectl expose deployment $service --port=8080 --target-port=8080 --name=$service 2>/dev/null
                    ;;
            esac
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Created $service service${NC}"
            else
                echo -e "${RED}✗ Failed to create $service service${NC}"
            fi
        fi
    done
    echo ""
else
    echo -e "${GREEN}✓ All required services exist${NC}"
fi

# Step 4: Check DNS resolution
echo "=========================================="
echo "STEP 4: Testing DNS Resolution"
echo "=========================================="
echo ""

echo "Testing if config-server is resolvable..."
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup config-server 2>/dev/null || echo "DNS test completed"
echo ""

# Step 5: Restart failing pods
echo "=========================================="
echo "STEP 5: Restarting Failing Pods"
echo "=========================================="
echo ""

echo "Getting list of CrashLoopBackOff pods..."
FAILING_PODS=$(kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[*].metadata.name}')

if [ -z "$FAILING_PODS" ]; then
    echo -e "${GREEN}✓ No failing pods found${NC}"
else
    echo "Failing pods: $FAILING_PODS"
    echo ""
    echo "Deleting failing pods to force restart..."
    
    for pod in $FAILING_PODS; do
        echo "Deleting pod: $pod"
        kubectl delete pod $pod --grace-period=0 --force 2>/dev/null
    done
    
    echo -e "${GREEN}✓ Deleted failing pods - they will be recreated automatically${NC}"
fi

echo ""

# Step 6: Wait and monitor
echo "=========================================="
echo "STEP 6: Monitoring Pod Recovery"
echo "=========================================="
echo ""

echo "Waiting 30 seconds for pods to restart..."
sleep 30

echo ""
echo "--- Current Pod Status ---"
kubectl get pods -o wide

echo ""
echo "--- Checking for pods still in CrashLoopBackOff ---"
STILL_FAILING=$(kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[*].metadata.name}')

if [ -z "$STILL_FAILING" ]; then
    echo -e "${GREEN}✓ All pods are running or starting up${NC}"
else
    echo -e "${YELLOW}⚠ Some pods are still failing: $STILL_FAILING${NC}"
    echo ""
    echo "Checking logs for first failing pod..."
    FIRST_FAILING=$(echo $STILL_FAILING | awk '{print $1}')
    echo ""
    echo "--- Logs for $FIRST_FAILING ---"
    kubectl logs $FIRST_FAILING --tail=30 2>/dev/null || kubectl logs $FIRST_FAILING --previous --tail=30 2>/dev/null
fi

echo ""

# Step 7: Final summary
echo "=========================================="
echo "FINAL SUMMARY"
echo "=========================================="
echo ""

echo "--- All Services ---"
kubectl get services

echo ""
echo "--- All Pods ---"
kubectl get pods

echo ""
echo "--- Pod Status Summary ---"
TOTAL_PODS=$(kubectl get pods --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods --no-headers | grep "Running" | grep "1/1" | wc -l)
PENDING_PODS=$(kubectl get pods --no-headers | grep -E "Pending|ContainerCreating" | wc -l)
FAILING_PODS=$(kubectl get pods --no-headers | grep -E "CrashLoopBackOff|Error" | wc -l)

echo "Total Pods: $TOTAL_PODS"
echo -e "${GREEN}Running (Ready): $RUNNING_PODS${NC}"
echo -e "${YELLOW}Starting: $PENDING_PODS${NC}"
echo -e "${RED}Failing: $FAILING_PODS${NC}"

echo ""
echo "=========================================="
echo "Fix Script Complete!"
echo "=========================================="
echo ""

if [ $FAILING_PODS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some pods are still failing${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Wait 2-5 minutes for pods to fully start"
    echo "2. Monitor pods: kubectl get pods -w"
    echo "3. Check logs: kubectl logs <pod-name>"
    echo "4. If issues persist, check:"
    echo "   - Node resources: kubectl describe nodes"
    echo "   - Pod events: kubectl describe pod <pod-name>"
    echo "   - Service endpoints: kubectl get endpoints"
else
    echo -e "${GREEN}✓ All pods are healthy!${NC}"
    echo ""
    echo "Your Spring Petclinic microservices are ready!"
    echo ""
    echo "Access the application:"
    echo "  kubectl get service api-gateway"
fi

echo ""
