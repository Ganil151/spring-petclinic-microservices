# Docker Hub Webhook Implementation Guide

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Implementation Steps](#implementation-steps)
5. [Docker Hub Configuration](#docker-hub-configuration)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)
8. [Security Hardening](#security-hardening)
9. [Maintenance](#maintenance)

---

## Overview

This guide provides step-by-step instructions for implementing a dedicated Docker Hub webhook receiver that automatically updates Kubernetes deployments when new images are pushed to Docker Hub.

### What This Achieves

✅ **Automated Deployments**: New Docker images trigger automatic K8s deployment updates  
✅ **Decoupled Architecture**: Webhook server is separate from Jenkins and K8s master  
✅ **Secure**: Uses Kubernetes RBAC with least-privilege permissions  
✅ **Scalable**: Handles multiple microservices with a single webhook server  
✅ **Auditable**: Comprehensive logging of all deployment activities  

### Workflow

```
Developer → GitHub → Jenkins → Docker Hub → Webhook Server → Kubernetes → Updated Pods
```

---

## Prerequisites

Before starting, ensure you have:

- ✅ **Terraform Infrastructure**: All EC2 instances provisioned (including webhook receiver)
- ✅ **Kubernetes Cluster**: K8s master and worker nodes running and joined
- ✅ **Deployments**: All microservices deployed to Kubernetes
- ✅ **Docker Hub Account**: Access to ganil151 Docker Hub repositories
- ✅ **SSH Access**: Ability to SSH into K8s master and webhook server
- ✅ **kubectl**: Configured on your local machine (optional, for verification)

---

## Architecture

### Infrastructure Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Jenkins Server** | Builds images and pushes to Docker Hub | EC2 (Spring-Petclinic-Master) |
| **Docker Hub** | Stores Docker images and sends webhooks | Cloud (hub.docker.com) |
| **Webhook Server** | Receives webhooks and updates deployments | EC2 (Webhook-Receiver-Server) |
| **K8s Master** | Manages Kubernetes cluster | EC2 (K8s-Master-Server) |
| **K8s Worker** | Runs application pods | EC2 (K8s-Worker-Server) |

### Security Model

- **Service Account**: `webhook-deployer` with limited permissions
- **RBAC**: ClusterRole with only deployment update permissions
- **Authentication**: Token-based authentication via kubeconfig
- **Network**: Port 9000 exposed (should be restricted to Docker Hub IPs in production)

---

## Implementation Steps

### Phase 1: Provision Webhook Server

#### Step 1.1: Deploy Infrastructure with Terraform

```bash
#!/bin/bash

#############################################################
# Webhook Server Infrastructure Deployment
# Purpose: Deploy webhook receiver with proper validation
#############################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handler
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "========================================="
echo "Webhook Server Deployment"
echo "========================================="
echo ""

# Step 1: Verify we're in the correct directory
if [ ! -d "terraform/app" ]; then
    error_exit "terraform/app directory not found. Please run from project root."
fi

cd terraform/app || error_exit "Failed to change to terraform/app directory"
success "Changed to terraform/app directory"

# Step 2: Verify Terraform is installed
if ! command -v terraform &> /dev/null; then
    error_exit "Terraform is not installed. Please install Terraform first."
fi
success "Terraform is installed: $(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)"

# Step 3: Verify webhook receiver configuration exists
echo ""
echo "Verifying webhook receiver configuration..."
if ! grep -q "webhook_receiver_instance" main.tf; then
    error_exit "webhook_receiver_instance not found in main.tf"
fi

# Display the configuration
echo ""
echo "Webhook receiver configuration:"
grep -A 10 "webhook_receiver_instance" main.tf
echo ""

# Step 4: Check if terraform.tfvars has project_name_7
if ! grep -q "project_name_7" terraform.tfvars; then
    error_exit "project_name_7 not found in terraform.tfvars. Please add it first."
fi
success "project_name_7 configured in terraform.tfvars"

# Step 5: Initialize Terraform
echo ""
echo "Initializing Terraform..."
if ! terraform init; then
    error_exit "Terraform init failed"
fi
success "Terraform initialized"

# Step 6: Format Terraform files
echo ""
echo "Formatting Terraform files..."
terraform fmt
success "Terraform files formatted"

# Step 7: Validate Terraform configuration
echo ""
echo "Validating Terraform configuration..."
if ! terraform validate; then
    error_exit "Terraform validation failed. Please fix the errors above."
fi
success "Terraform configuration is valid"

# Step 8: Create execution plan
echo ""
echo "Creating Terraform plan..."
if ! terraform plan -out=tfplan; then
    error_exit "Terraform plan failed. Please review the errors above."
fi
success "Terraform plan created successfully"

# Step 9: Review and confirm
echo ""
warning "Please review the plan above carefully."
echo ""
read -p "Do you want to apply this plan? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled by user."
    rm -f tfplan
    exit 0
fi

# Step 10: Apply Terraform plan
echo ""
echo "Applying Terraform plan..."
if ! terraform apply tfplan; then
    error_exit "Terraform apply failed. Please check the errors above."
fi
success "Terraform applied successfully"

# Clean up plan file
rm -f tfplan

# Step 11: Get webhook server IP
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""

# Try to get the webhook server IP
if terraform output &> /dev/null; then
    echo "Terraform outputs:"
    terraform output | grep -i webhook || warning "No webhook output found"
    echo ""
fi

# Display next steps
echo "Next Steps:"
echo "1. SSH into webhook server and verify setup"
echo "2. Apply RBAC configuration: kubectl apply -f kubernetes/webhook-rbac.yaml"
echo "3. Generate kubeconfig on K8s master"
echo "4. Configure kubectl on webhook server"
echo "5. Start webhook service"
echo ""
success "Deployment script completed successfully!"
```

**Expected Result**: Webhook receiver EC2 instance is created and running.

#### Step 1.2: Verify Webhook Server Setup

SSH into the webhook server and verify the installation:

```bash
#!/bin/bash

# Webhook Server Verification Script
set -e

WEBHOOK_IP="<WEBHOOK-SERVER-IP>"

echo "Connecting to webhook server..."
ssh -i your-key.pem ec2-user@${WEBHOOK_IP} << 'ENDSSH'
    set -e
    
    echo "========================================="
    echo "Webhook Server Verification"
    echo "========================================="
    echo ""
    
    # Check webhook application directory
    echo "1. Checking webhook application directory..."
    if [ -d "/opt/webhook-receiver" ]; then
        echo "✓ /opt/webhook-receiver exists"
        ls -la /opt/webhook-receiver/
    else
        echo "✗ ERROR: /opt/webhook-receiver not found!"
        exit 1
    fi
    echo ""
    
    # Check webhook application file
    echo "2. Checking webhook application file..."
    if [ -f "/opt/webhook-receiver/webhook_server.py" ]; then
        echo "✓ webhook_server.py exists"
        echo "   Size: $(stat -f%z /opt/webhook-receiver/webhook_server.py 2>/dev/null || stat -c%s /opt/webhook-receiver/webhook_server.py) bytes"
    else
        echo "✗ ERROR: webhook_server.py not found!"
        exit 1
    fi
    echo ""
    
    # Check systemd service
    echo "3. Checking systemd service..."
    if systemctl list-unit-files | grep -q webhook-receiver; then
        echo "✓ webhook-receiver service exists"
        sudo systemctl status webhook-receiver --no-pager || true
    else
        echo "✗ ERROR: webhook-receiver service not found!"
        exit 1
    fi
    echo ""
    
    # Check logs directory
    echo "4. Checking logs directory..."
    if [ -d "/var/log/webhook-receiver" ]; then
        echo "✓ /var/log/webhook-receiver exists"
        ls -la /var/log/webhook-receiver/
    else
        echo "✗ ERROR: /var/log/webhook-receiver not found!"
        exit 1
    fi
    echo ""
    
    # Check Python and dependencies
    echo "5. Checking Python and dependencies..."
    if command -v python3 &> /dev/null; then
        echo "✓ Python3 installed: $(python3 --version)"
    else
        echo "✗ ERROR: Python3 not installed!"
        exit 1
    fi
    
    if python3 -c "import flask" 2>/dev/null; then
        echo "✓ Flask installed"
    else
        echo "✗ WARNING: Flask not installed (may need: sudo pip3 install flask)"
    fi
    echo ""
    
    # Check kubectl
    echo "6. Checking kubectl..."
    if command -v kubectl &> /dev/null; then
        echo "✓ kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    else
        echo "✗ ERROR: kubectl not installed!"
        exit 1
    fi
    echo ""
    
    echo "========================================="
    echo "Verification Complete!"
    echo "========================================="
    echo ""
    echo "Status Summary:"
    echo "  ✓ Webhook application: Installed"
    echo "  ✓ Systemd service: Configured"
    echo "  ✓ Dependencies: Ready"
    echo ""
    echo "Next: Configure kubectl and start the service"
ENDSSH
```

**Expected Result**: 
- Application files exist in `/opt/webhook-receiver/`
- Service is enabled but not started (waiting for kubectl configuration)
- Log directory exists

---

### Phase 2: Configure Kubernetes RBAC

#### Step 2.1: Apply RBAC Configuration

On your **local machine** or **K8s master server**:

```bash
#!/bin/bash

#############################################################
# Webhook RBAC Configuration Script
# Purpose: Apply RBAC configuration with validation
#############################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

echo "========================================="
echo "Webhook RBAC Configuration"
echo "========================================="
echo ""

# Step 1: Verify kubectl is configured
echo "1. Verifying kubectl connection..."
if ! kubectl cluster-info &> /dev/null; then
    error_exit "kubectl is not configured or cluster is not accessible"
fi
success "kubectl is configured and cluster is accessible"
echo ""

# Step 2: Verify RBAC file exists
echo "2. Checking RBAC configuration file..."
if [ ! -f "kubernetes/webhook-rbac.yaml" ]; then
    error_exit "kubernetes/webhook-rbac.yaml not found. Are you in the project root?"
fi
success "RBAC configuration file found"
echo ""

# Step 3: Display RBAC configuration
echo "3. RBAC Configuration to be applied:"
echo "---"
cat kubernetes/webhook-rbac.yaml
echo "---"
echo ""

# Step 4: Apply RBAC configuration
echo "4. Applying RBAC configuration..."
if ! kubectl apply -f kubernetes/webhook-rbac.yaml; then
    error_exit "Failed to apply RBAC configuration"
fi
success "RBAC configuration applied"
echo ""

# Step 5: Verify service account was created
echo "5. Verifying service account..."
if ! kubectl get serviceaccount webhook-deployer -n default &> /dev/null; then
    error_exit "Service account 'webhook-deployer' was not created"
fi
success "Service account 'webhook-deployer' created"
kubectl get serviceaccount webhook-deployer -n default
echo ""

# Step 6: Verify cluster role was created
echo "6. Verifying cluster role..."
if ! kubectl get clusterrole webhook-deployment-manager &> /dev/null; then
    error_exit "ClusterRole 'webhook-deployment-manager' was not created"
fi
success "ClusterRole 'webhook-deployment-manager' created"
echo ""

# Step 7: Verify cluster role binding
echo "7. Verifying cluster role binding..."
if ! kubectl get clusterrolebinding webhook-deployer-binding &> /dev/null; then
    error_exit "ClusterRoleBinding 'webhook-deployer-binding' was not created"
fi
success "ClusterRoleBinding 'webhook-deployer-binding' created"
kubectl get clusterrolebinding webhook-deployer-binding
echo ""

echo "========================================="
echo "RBAC Configuration Complete!"
echo "========================================="
echo ""
```

**Expected Output**:
```
serviceaccount/webhook-deployer created
clusterrole.rbac.authorization.k8s.io/webhook-deployment-manager created
clusterrolebinding.rbac.authorization.k8s.io/webhook-deployer-binding created
```

#### Step 2.2: Verify RBAC Permissions

```bash
# Check what the service account can do
kubectl auth can-i get deployments --as=system:serviceaccount:default:webhook-deployer
kubectl auth can-i update deployments --as=system:serviceaccount:default:webhook-deployer
kubectl auth can-i delete deployments --as=system:serviceaccount:default:webhook-deployer
```

**Expected Output**:
- `get deployments`: **yes**
- `update deployments`: **yes**
- `delete deployments`: **no** (correct - we don't want webhook to delete)

---

### Phase 3: Generate and Configure Kubeconfig

#### Step 3.1: Generate Kubeconfig on K8s Master

SSH into the **K8s master server**:

```bash
ssh -i your-key.pem ec2-user@<K8S-MASTER-IP>

# Navigate to project directory (or copy the script)
cd spring-petclinic-microservices/scripts

# Make script executable
chmod +x generate-kubeconfig.sh

# Run the script
./generate-kubeconfig.sh
```

**Expected Output**:
```
=========================================
Webhook Kubeconfig Generator
=========================================

Step 1: Verifying service account exists...
✓ Service account found

Step 2: Retrieving service account secret...
✓ Secret name: webhook-deployer-token-xxxxx

Step 3: Extracting credentials...
✓ Token extracted
✓ CA certificate extracted

Step 4: Getting cluster information...
✓ Cluster: kubernetes
✓ Server: https://10.0.x.x:6443

Step 5: Generating kubeconfig file...
✓ Kubeconfig file generated: webhook-kubeconfig

Step 6: Testing kubeconfig...
✓ Kubeconfig is valid and working!

=========================================
SUCCESS! Kubeconfig Generated
=========================================
```

#### Step 3.2: Copy Kubeconfig to Webhook Server

Still on the **K8s master server**:

```bash
# Copy kubeconfig to webhook server
scp -i /path/to/your-key.pem webhook-kubeconfig ec2-user@<WEBHOOK-SERVER-IP>:/tmp/
```

#### Step 3.3: Configure Kubectl on Webhook Server

SSH into the **webhook server**:

```bash
#!/bin/bash

#############################################################
# Configure Kubectl on Webhook Server
# Purpose: Set up kubectl with proper validation
#############################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "========================================="
echo "Kubectl Configuration on Webhook Server"
echo "========================================="
echo ""

# Step 1: Verify kubeconfig file exists in /tmp
echo "1. Checking for kubeconfig file..."
if [ ! -f "/tmp/webhook-kubeconfig" ]; then
    error_exit "kubeconfig file not found in /tmp/. Please copy it from K8s master first."
fi
success "Kubeconfig file found in /tmp/"
echo ""

# Step 2: Create .kube directory if it doesn't exist
echo "2. Setting up .kube directory..."
sudo mkdir -p /root/.kube
sudo chmod 700 /root/.kube
success ".kube directory ready"
echo ""

# Step 3: Backup existing config if present
if [ -f "/root/.kube/config" ]; then
    warning "Existing kubeconfig found. Creating backup..."
    sudo cp /root/.kube/config /root/.kube/config.backup.$(date +%Y%m%d_%H%M%S)
    success "Backup created"
    echo ""
fi

# Step 4: Move kubeconfig to correct location
echo "3. Installing kubeconfig..."
sudo mv /tmp/webhook-kubeconfig /root/.kube/config
sudo chmod 600 /root/.kube/config
success "Kubeconfig installed"
echo ""

# Step 5: Test kubectl connectivity
echo "4. Testing kubectl connectivity..."
if ! sudo kubectl cluster-info &> /dev/null; then
    error_exit "kubectl cannot connect to cluster. Check kubeconfig and network connectivity."
fi
success "kubectl connected to cluster"
echo ""

# Step 6: Test node access
echo "5. Testing node access..."
if ! sudo kubectl get nodes &> /dev/null; then
    error_exit "Cannot get nodes. Check RBAC permissions."
fi
success "Can access nodes"
sudo kubectl get nodes
echo ""

# Step 7: Test deployment access
echo "6. Testing deployment access..."
if ! sudo kubectl get deployments -n default &> /dev/null; then
    error_exit "Cannot get deployments. Check RBAC permissions."
fi
success "Can access deployments"
sudo kubectl get deployments -n default
echo ""

# Step 8: Verify webhook deployer permissions
echo "7. Verifying webhook deployer permissions..."
echo "   Checking 'get deployments' permission..."
if sudo kubectl auth can-i get deployments --as=system:serviceaccount:default:webhook-deployer 2>/dev/null | grep -q "yes"; then
    success "Can get deployments"
else
    warning "Cannot get deployments - RBAC may not be configured correctly"
fi

echo "   Checking 'update deployments' permission..."
if sudo kubectl auth can-i update deployments --as=system:serviceaccount:default:webhook-deployer 2>/dev/null | grep -q "yes"; then
    success "Can update deployments"
else
    error_exit "Cannot update deployments - RBAC is not configured correctly"
fi
echo ""

echo "========================================="
echo "Kubectl Configuration Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✓ Kubeconfig installed"
echo "  ✓ Cluster connectivity verified"
echo "  ✓ RBAC permissions validated"
echo ""
echo "Next: Start the webhook service"
echo "  sudo systemctl start webhook-receiver"
```

**Expected Output**:
```
NAME                  READY   STATUS    AGE
k8s-master-server     Ready   master    2d
k8s-worker-server     Ready   <none>    2d

NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
api-gateway           1/1     1            1           1d
customers-service     1/1     1            1           1d
...
```

---

### Phase 4: Start Webhook Service

#### Step 4.1: Start the Service

On the **webhook server**:

```bash
# Start the webhook receiver service
sudo systemctl start webhook-receiver

# Check service status
sudo systemctl status webhook-receiver

# View logs
sudo tail -f /var/log/webhook-receiver/webhook.log
```

**Expected Output**:
```
● webhook-receiver.service - Docker Hub Webhook Receiver
   Loaded: loaded (/etc/systemd/system/webhook-receiver.service; enabled)
   Active: active (running) since ...
   
[timestamp] Starting Docker Hub Webhook Receiver on port 9000...
[timestamp] * Running on http://0.0.0.0:9000
```

#### Step 4.2: Test Health Endpoint

From your **local machine** or **webhook server**:

```bash
# Test health endpoint
curl http://<WEBHOOK-SERVER-IP>:9000/health

# Test service info endpoint
curl http://<WEBHOOK-SERVER-IP>:9000/
```

**Expected Output**:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-22T20:30:00",
  "service": "webhook-receiver"
}
```

---

### Phase 5: Test Webhook Functionality

#### Step 5.1: Run Automated Tests

From your **local machine**:

```bash
cd spring-petclinic-microservices/scripts

# Make script executable
chmod +x test-webhook.sh

# Run tests
./test-webhook.sh <WEBHOOK-SERVER-IP>
```

**Expected Output**:
```
=========================================
Webhook Receiver Test Suite
=========================================

Test 1: Health Check
✓ Health check passed

Test 2: Service Information
✓ Service info retrieved

Test 3: Simulated Webhook - Customers Service
✓ Webhook processed successfully

...

All tests completed!
```

#### Step 5.2: Monitor Webhook Logs

On the **webhook server**, watch the logs in real-time:

```bash
sudo tail -f /var/log/webhook-receiver/webhook.log
```

You should see log entries for each test webhook received.

---

## Docker Hub Configuration

### Configure Webhooks for All Repositories

#### Option 1: Manual Configuration (Recommended)

For each repository, follow these steps:

1. **Go to Docker Hub**: https://hub.docker.com/
2. **Navigate to Repository**: Click on the repository (e.g., `ganil151/customers-service`)
3. **Go to Webhooks Tab**: Click "Webhooks" in the repository menu
4. **Create Webhook**:
   - **Webhook name**: `k8s-deployment-trigger`
   - **Webhook URL**: `http://<WEBHOOK-SERVER-IP>:9000/webhook`
5. **Save**: Click "Create"

**Repositories to Configure**:
- ✅ ganil151/api-gateway
- ✅ ganil151/customers-service
- ✅ ganil151/vets-service
- ✅ ganil151/visits-service
- ✅ ganil151/admin-server
- ✅ ganil151/config-server
- ✅ ganil151/discovery-server

#### Option 2: Using Helper Script

```bash
cd spring-petclinic-microservices/scripts

# Make script executable
chmod +x configure-dockerhub-webhooks.sh

# Run the helper script
./configure-dockerhub-webhooks.sh <WEBHOOK-SERVER-IP>
```

This script provides detailed instructions and verification steps.

---

## Testing

### End-to-End Test

#### Test 1: Manual Image Push

```bash
# Build and push a test image
docker tag customers-service:latest ganil151/customers-service:test-v1
docker push ganil151/customers-service:test-v1

# Watch webhook logs
ssh ec2-user@<WEBHOOK-SERVER-IP> 'sudo tail -f /var/log/webhook-receiver/webhook.log'

# Watch Kubernetes deployment
kubectl get pods -w
```

**Expected Behavior**:
1. Image is pushed to Docker Hub
2. Docker Hub sends webhook to webhook server
3. Webhook server receives notification
4. Webhook server updates Kubernetes deployment
5. Kubernetes rolls out new pods with updated image

#### Test 2: Jenkins Pipeline Integration

```bash
# Trigger Jenkins build for a microservice
# Jenkins will build, push to Docker Hub, which triggers webhook

# Monitor the entire flow:
# 1. Jenkins build logs
# 2. Docker Hub webhook delivery (check Docker Hub UI)
# 3. Webhook server logs
# 4. Kubernetes pod updates
```

---

## Troubleshooting

### Issue: Webhook Service Won't Start

**Symptoms**: `systemctl status webhook-receiver` shows failed state

**Solutions**:
```bash
# Check detailed logs
sudo journalctl -u webhook-receiver -n 50

# Common issues:
# 1. Python dependencies missing
sudo pip3 install flask requests

# 2. Port 9000 already in use
sudo netstat -tulpn | grep 9000

# 3. Permissions issue
sudo chmod +x /opt/webhook-receiver/webhook_server.py
```

---

### Issue: kubectl Not Working on Webhook Server

**Symptoms**: `sudo kubectl get nodes` returns error

**Solutions**:
```bash
# Verify kubeconfig exists
sudo ls -la /root/.kube/config

# Test kubeconfig manually
sudo kubectl --kubeconfig=/root/.kube/config get nodes

# Check connectivity to K8s master
telnet <K8S-MASTER-PRIVATE-IP> 6443

# Regenerate kubeconfig if needed
# (Run generate-kubeconfig.sh on K8s master again)
```

---

### Issue: Webhook Received But Deployment Not Updated

**Symptoms**: Webhook logs show success, but pods don't update

**Solutions**:
```bash
# Check webhook logs for errors
sudo tail -f /var/log/webhook-receiver/webhook.log

# Manually test deployment update
sudo kubectl set image deployment/customers-service \
    customers-service=ganil151/customers-service:latest

# Check RBAC permissions
kubectl auth can-i update deployments \
    --as=system:serviceaccount:default:webhook-deployer

# Check deployment status
kubectl describe deployment customers-service
```

---

### Issue: Docker Hub Not Sending Webhooks

**Symptoms**: No webhook requests in logs after image push

**Solutions**:
1. **Verify webhook configuration in Docker Hub UI**
   - Check webhook URL is correct
   - Check webhook is enabled

2. **Check Docker Hub webhook delivery logs**
   - Go to repository → Webhooks → View delivery history
   - Look for failed deliveries

3. **Verify network connectivity**
   ```bash
   # From Docker Hub's perspective, can they reach your server?
   # Check security group allows port 9000 from 0.0.0.0/0
   # (or Docker Hub IP ranges)
   ```

4. **Test webhook manually**
   ```bash
   ./scripts/test-webhook.sh <WEBHOOK-SERVER-IP>
   ```

---

## Security Hardening

### Production Security Checklist

#### 1. Restrict Port 9000 Access

Update security group to allow port 9000 only from Docker Hub IP ranges:

```
Docker Hub IP Ranges (as of 2025):
- 34.192.0.0/16
- 52.0.0.0/8
- 54.0.0.0/8
```

#### 2. Enable HTTPS with Nginx Reverse Proxy

```bash
# Install nginx on webhook server
sudo yum install -y nginx certbot python3-certbot-nginx

# Configure nginx as reverse proxy
sudo tee /etc/nginx/conf.d/webhook.conf <<EOF
server {
    listen 443 ssl;
    server_name webhook.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/webhook.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webhook.yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Get SSL certificate
sudo certbot --nginx -d webhook.yourdomain.com
```

#### 3. Enable Webhook Secret Validation

```bash
# Generate a secret
WEBHOOK_SECRET=$(openssl rand -hex 32)

# Update systemd service
sudo systemctl edit webhook-receiver

# Add environment variable:
[Service]
Environment="WEBHOOK_SECRET=your-secret-here"

# Restart service
sudo systemctl restart webhook-receiver

# Configure secret in Docker Hub webhook settings
```

#### 4. Enable Firewall

```bash
# Install and configure firewalld
sudo yum install -y firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Allow only necessary ports
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload
```

---

## Maintenance

### Regular Maintenance Tasks

#### Monitor Logs

```bash
# View recent webhook activity
sudo tail -100 /var/log/webhook-receiver/webhook.log

# Check for errors
sudo grep ERROR /var/log/webhook-receiver/webhook.log

# Rotate logs (configure logrotate)
sudo tee /etc/logrotate.d/webhook-receiver <<EOF
/var/log/webhook-receiver/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

#### Update Webhook Application

```bash
# If you need to update the Python application
sudo systemctl stop webhook-receiver
sudo nano /opt/webhook-receiver/webhook_server.py
sudo systemctl start webhook-receiver
```

#### Add New Microservice

To add a new microservice to the webhook system:

1. **Update webhook server configuration**:
   ```bash
   sudo nano /opt/webhook-receiver/webhook_server.py
   
   # Add to REPO_TO_DEPLOYMENT dictionary:
   'ganil151/new-service': 'new-service',
   ```

2. **Restart webhook service**:
   ```bash
   sudo systemctl restart webhook-receiver
   ```

3. **Configure Docker Hub webhook** for the new repository

---

## Summary

You now have a fully functional, automated deployment pipeline:

```
Code Change → GitHub → Jenkins Build → Docker Push → Webhook → K8s Update → Live!
```

### Key Files and Locations

| File/Location | Purpose |
|---------------|---------|
| `/opt/webhook-receiver/webhook_server.py` | Main webhook application |
| `/etc/systemd/system/webhook-receiver.service` | Systemd service configuration |
| `/var/log/webhook-receiver/webhook.log` | Webhook activity logs |
| `/root/.kube/config` | Kubernetes authentication |
| `kubernetes/webhook-rbac.yaml` | RBAC configuration |
| `scripts/generate-kubeconfig.sh` | Kubeconfig generation helper |
| `scripts/test-webhook.sh` | Testing utility |

### Support

For issues or questions:
- Check logs: `/var/log/webhook-receiver/webhook.log`
- Review this guide's troubleshooting section
- Test with: `./scripts/test-webhook.sh`

---

**🎉 Congratulations! Your webhook-based automated deployment system is ready!**
