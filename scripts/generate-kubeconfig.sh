#!/bin/bash

#############################################################
# Kubeconfig Generator for Webhook Receiver
# 
# Purpose: Generate a kubeconfig file for the webhook server
#          to authenticate with the Kubernetes cluster
#
# Usage: Run this script on the Kubernetes MASTER server
#        after applying webhook-rbac.yaml
#############################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Webhook Kubeconfig Generator${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Configuration
SERVICE_ACCOUNT="webhook-deployer"
NAMESPACE="default"
OUTPUT_FILE="webhook-kubeconfig"

# Step 1: Verify service account exists
echo -e "${YELLOW}Step 1: Verifying service account exists...${NC}"
if ! kubectl get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}ERROR: Service account '$SERVICE_ACCOUNT' not found in namespace '$NAMESPACE'${NC}"
    echo -e "${YELLOW}Please apply the RBAC configuration first:${NC}"
    echo "  kubectl apply -f kubernetes/webhook-rbac.yaml"
    exit 1
fi
echo -e "${GREEN}✓ Service account found${NC}"
echo ""

# Step 2: Get the service account secret
echo -e "${YELLOW}Step 2: Retrieving service account secret...${NC}"

# For Kubernetes 1.24+, we may need to create a token manually
SECRET_NAME=$(kubectl get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" -o jsonpath='{.secrets[0].name}' 2>/dev/null)

if [ -z "$SECRET_NAME" ]; then
    echo -e "${YELLOW}No secret found (K8s 1.24+). Creating token manually...${NC}"
    
    # Create a secret for the service account
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_ACCOUNT}-token
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT}
type: kubernetes.io/service-account-token
EOF
    
    # Wait for token to be populated
    echo "Waiting for token to be generated..."
    sleep 3
    SECRET_NAME="${SERVICE_ACCOUNT}-token"
fi

echo -e "${GREEN}✓ Secret name: $SECRET_NAME${NC}"
echo ""

# Step 3: Extract token and CA certificate
echo -e "${YELLOW}Step 3: Extracting credentials...${NC}"

TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.token}' | base64 --decode)
CA_CERT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}ERROR: Failed to extract token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Token extracted${NC}"
echo -e "${GREEN}✓ CA certificate extracted${NC}"
echo ""

# Step 4: Get cluster information
echo -e "${YELLOW}Step 4: Getting cluster information...${NC}"

CLUSTER_NAME=$(kubectl config view -o jsonpath='{.clusters[0].name}')
SERVER_URL=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

# If server URL is localhost or 127.0.0.1, try to get the actual IP
if [[ "$SERVER_URL" == *"127.0.0.1"* ]] || [[ "$SERVER_URL" == *"localhost"* ]]; then
    echo -e "${YELLOW}Warning: Detected localhost in server URL${NC}"
    MASTER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}Using master node IP: $MASTER_IP${NC}"
    SERVER_URL="https://${MASTER_IP}:6443"
fi

echo -e "${GREEN}✓ Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}✓ Server: $SERVER_URL${NC}"
echo ""

# Step 5: Generate kubeconfig file
echo -e "${YELLOW}Step 5: Generating kubeconfig file...${NC}"

cat > "$OUTPUT_FILE" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${SERVER_URL}
contexts:
- name: webhook-context
  context:
    cluster: ${CLUSTER_NAME}
    user: ${SERVICE_ACCOUNT}
    namespace: ${NAMESPACE}
current-context: webhook-context
users:
- name: ${SERVICE_ACCOUNT}
  user:
    token: ${TOKEN}
EOF

echo -e "${GREEN}✓ Kubeconfig file generated: $OUTPUT_FILE${NC}"
echo ""

# Step 6: Test the kubeconfig
echo -e "${YELLOW}Step 6: Testing kubeconfig...${NC}"
if kubectl --kubeconfig="$OUTPUT_FILE" get nodes &>/dev/null; then
    echo -e "${GREEN}✓ Kubeconfig is valid and working!${NC}"
else
    echo -e "${RED}⚠ Warning: Kubeconfig test failed. Please verify manually.${NC}"
fi
echo ""

# Step 7: Display next steps
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}SUCCESS! Kubeconfig Generated${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Copy the kubeconfig file to the webhook server:"
echo -e "   ${GREEN}scp -i your-key.pem $OUTPUT_FILE ec2-user@<WEBHOOK-SERVER-IP>:/tmp/${NC}"
echo ""
echo "2. On the webhook server, move it to the correct location:"
echo -e "   ${GREEN}sudo mv /tmp/$OUTPUT_FILE /root/.kube/config${NC}"
echo -e "   ${GREEN}sudo chmod 600 /root/.kube/config${NC}"
echo ""
echo "3. Test kubectl on the webhook server:"
echo -e "   ${GREEN}sudo kubectl get nodes${NC}"
echo ""
echo "4. Start the webhook service:"
echo -e "   ${GREEN}sudo systemctl start webhook-receiver${NC}"
echo -e "   ${GREEN}sudo systemctl status webhook-receiver${NC}"
echo ""
echo -e "${YELLOW}Server URL for webhook server: ${SERVER_URL}${NC}"
echo ""
echo -e "${GREEN}=========================================${NC}"
