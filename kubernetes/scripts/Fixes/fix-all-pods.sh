#!/bin/bash
set -e

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

# --- Prerequisite Check ---
echo "=== Checking kubectl configuration ==="
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ kubectl is not configured properly${NC}"
    echo ""
    echo "If kubectl is not configured for your user, run:"
    echo "  mkdir -p ~/.kube"
    echo "  sudo cp /etc/kubernetes/admin.conf ~/.kube/config"
    echo "  sudo chown \$(id -u):\$(id -g) ~/.kube/config"
    exit 1
fi

echo -e "${GREEN}✓ kubectl is configured${NC}"
echo ""

# --- Configuration (FIXED PATH) ---
# Assuming deployment YAML files are located in a subdirectory, 
# e.g., 'kubernetes-manifests' within the user's home directory.
# Adjust this path based on where your YAML files actually reside.
KUBE_DIR="$HOME/kubernetes-manifests"

if [ ! -d "$KUBE_DIR" ]; then
    echo -e "${RED}✗ Kubernetes deployments directory not found at: $KUBE_DIR${NC}"
    echo "Please update KUBE_DIR variable in this script to point to the directory containing your YAML files (e.g., /home/ec2-user/k8s-manifests)"
    exit 1
fi

echo -e "${GREEN}✓ Found kubernetes deployments directory at: $KUBE_DIR${NC}"
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
# The trailing '/' is not needed when applying a directory
kubectl apply -f "$KUBE_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully applied all deployment files${NC}"
else
    echo -e "${RED}✗ Failed to apply deployment files${NC}"
    exit 1
fi
echo ""

# Step 3: Verify services were created (and recreate missing ones via expose)
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
    echo "Attempting to create missing services manually using 'kubectl expose'..."
    echo "(This assumes a Deployment object with the same name exists)"
    echo ""
    
    for service in "${REQUIRED_SERVICES[@]}"; do
        if ! kubectl get service $service &>/dev/null; then
            echo "Creating $service service..."
            
            # Determine port based on service name
            case $service in
                "config-server")
                    # --type=ClusterIP is default, added for clarity
                    kubectl expose deployment $service --port=8888 --target-port=8888 --name=$service --type=ClusterIP
                    ;;
                "discovery-server")
                    kubectl expose deployment $service --port=8761 --target-port=8761 --name=$service --type=ClusterIP
                    ;;
                "admin-server")
                    kubectl expose deployment $service --port=9090 --target-port=9090 --name=$service --type=ClusterIP
                    ;;
                "api-gateway")
                    kubectl expose deployment $service --port=8080 --target-port=8080 --name=$service --type=ClusterIP
                    ;;
                *)
                    kubectl expose deployment $service --port=8080 --target-port=8080 --name=$service --type=ClusterIP
                    ;;
            esac
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Created $service service${NC}"
            else
                echo -e "${RED}✗ Failed to create $service service (Deployment not found?)${NC}"
            fi
        fi
    done
    echo ""
else
    echo -e "${GREEN}✓ All required services exist${NC}"
fi

# Step 4: Check DNS resolution
echo "=========================================="
echo "STEP 4: Testing Cluster DNS Resolution"
echo "=========================================="
echo ""

echo "Testing if config-server is resolvable (using busybox nslookup)..."
# Use a timeout (e.g., 10s) to prevent the command from hanging indefinitely if the cluster DNS is broken
# Using the '--timeout' parameter for the kubectl run command
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never --command -- sh -c 'timeout 10 nslookup config-server' 2>/dev/null || echo "DNS test completed or timed out"
echo ""


# Step 5: Restart failing pods
echo "=========================================="
echo "STEP 5: Restarting Failing Pods"
echo "=========================================="
echo ""

echo "Getting list of CrashLoopBackOff, Error, and Terminating pods..."
# Filter for non-healthy states
FAILING_PODS=$(kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[?(@.status.phase != "Running" && @.status.reason != "Completed")].metadata.name}')

if [ -z "$FAILING_PODS" ]; then
    echo -e "${GREEN}✓ No currently failing or stuck pods found${NC}"
else
    echo "Failing pods: $FAILING_PODS"
    echo ""
    echo "Deleting failing pods to force recreation by the Deployment controller..."
    
    # We delete one by one to ensure the Deployment controller has time to react
    for pod in $FAILING_PODS; do
        echo "Deleting pod: $pod"
        # --grace-period=0 and --force deletes immediately
        kubectl delete pod $pod --grace-period=0 --force 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Deleted failing pods - they will be recreated automatically${NC}"
fi

echo ""

# Step 6: Wait and monitor
echo "=========================================="
echo "STEP 6: Monitoring Pod Recovery"
echo "=========================================="
echo ""

echo "Waiting 30 seconds for new pods to start scheduling..."
sleep 30

echo ""
echo "--- Current Pod Status (After forced restart) ---"
kubectl get pods -o wide

echo ""
echo "--- Checking for pods still in CrashLoopBackOff/Error ---"
STILL_FAILING=$(kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{.items[?(@.status.phase != "Running" && @.status.reason != "Completed")].metadata.name}')

if [ -z "$STILL_FAILING" ]; then
    echo -e "${GREEN}✓ All pods are running or starting up${NC}"
else
    echo -e "${YELLOW}⚠ Some pods are still failing: $STILL_FAILING${NC}"
    echo ""
    echo "Checking logs for first failing pod..."
    FIRST_FAILING=$(echo $STILL_FAILING | awk '{print $1}')
    echo ""
    echo "--- Logs for $FIRST_FAILING (Last 30 lines) ---"
    # Try current logs, then previous logs
    kubectl logs $FIRST_FAILING --tail=30 2>/dev/null || kubectl logs $FIRST_FAILING --previous --tail=30 2>/dev/null || echo "Could not retrieve logs for $FIRST_FAILING"
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
# Count pods in various phases more accurately
TOTAL_PODS=$(kubectl get pods --no-headers | wc -l)
RUNNING_READY_PODS=$(kubectl get pods --no-headers | grep "Running" | grep "1/1" | wc -l)
PENDING_OR_CREATING_PODS=$(kubectl get pods --no-headers | grep -E "Pending|ContainerCreating" | wc -l)
FAILING_PODS=$(kubectl get pods --no-headers | grep -E "CrashLoopBackOff|Error" | wc -l)

echo "Total Pods: $TOTAL_PODS"
echo -e "${GREEN}Running (Ready): $RUNNING_READY_PODS${NC}"
echo -e "${YELLOW}Starting/Pending: $PENDING_OR_CREATING_PODS${NC}"
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
    echo "1. Wait 2-5 minutes for pods to fully start."
    echo "2. Monitor pods: \`${YELLOW}kubectl get pods -w${NC}\`"
    echo "3. Check specific logs: \`${YELLOW}kubectl logs <pod-name>${NC}\`"
    echo "4. If issues persist, check:"
    echo "   - Node resources: \`${YELLOW}kubectl describe nodes${NC}\`"
    echo "   - Pod events: \`${YELLOW}kubectl describe pod <pod-name>${NC}\`"
    echo "   - Configuration for connectivity issues (e.g., config server reachability)."
else
    echo -e "${GREEN}✓ All pods are healthy or starting up successfully!${NC}"
    echo ""
    echo "Your Spring Petclinic microservices are ready!"
    echo ""
    echo "Access the application (get the CLUSTER-IP or NodePort for api-gateway):"
    echo "  ${YELLOW}kubectl get service api-gateway${NC}"
fi