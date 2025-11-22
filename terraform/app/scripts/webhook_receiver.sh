#!/bin/bash

#############################################
# Docker Hub Webhook Receiver Setup Script
# Purpose: Sets up a dedicated webhook server
#          to receive Docker Hub notifications
#          and update Kubernetes deployments
#############################################

set -e  # Exit on any error

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Webhook Receiver Setup..."

#############################################
# 1. System Updates and Dependencies
#############################################
log "Updating system packages..."
sudo yum update -y

log "Installing Python3 and pip..."
sudo yum install -y python3 python3-pip git

log "Installing kubectl..."
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Verify kubectl installation
kubectl version --client || log "kubectl installed (cluster not yet configured)"

#############################################
# 2. Install Python Dependencies
#############################################
log "Installing Python dependencies..."
sudo pip3 install flask requests

#############################################
# 3. Create Webhook Application Directory
#############################################
log "Creating webhook application directory..."
sudo mkdir -p /opt/webhook-receiver
sudo mkdir -p /var/log/webhook-receiver

#############################################
# 4. Create Python Webhook Receiver Application
#############################################
log "Creating webhook receiver application..."

sudo tee /opt/webhook-receiver/webhook_server.py > /dev/null <<'EOF'
#!/usr/bin/env python3
"""
Docker Hub Webhook Receiver
Receives webhook notifications from Docker Hub and updates Kubernetes deployments
"""

from flask import Flask, request, jsonify
import subprocess
import json
import logging
from datetime import datetime
import os
import hmac
import hashlib

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webhook-receiver/webhook.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Webhook secret for validation (optional, set via environment variable)
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', '')

# Mapping of Docker Hub repositories to Kubernetes deployments
REPO_TO_DEPLOYMENT = {
    'ganil151/api-gateway': 'api-gateway',
    'ganil151/customers-service': 'customers-service',
    'ganil151/vets-service': 'vets-service',
    'ganil151/visits-service': 'visits-service',
    'ganil151/admin-server': 'admin-server',
    'ganil151/config-server': 'config-server',
    'ganil151/discovery-server': 'discovery-server',
}

def validate_signature(payload, signature):
    """Validate Docker Hub webhook signature (if secret is configured)"""
    if not WEBHOOK_SECRET:
        logger.warning("No webhook secret configured - skipping signature validation")
        return True
    
    expected_signature = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected_signature)

def update_deployment(deployment_name, image_name, tag):
    """Update Kubernetes deployment with new image"""
    try:
        # Construct the full image name
        full_image = f"{image_name}:{tag}"
        
        logger.info(f"Updating deployment '{deployment_name}' with image '{full_image}'")
        
        # Update the deployment
        cmd = [
            'kubectl', 'set', 'image',
            f'deployment/{deployment_name}',
            f'{deployment_name}={full_image}',
            '-n', 'default'
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            logger.error(f"Failed to update deployment: {result.stderr}")
            return False, result.stderr
        
        logger.info(f"Deployment update command executed: {result.stdout}")
        
        # Wait for rollout to complete
        logger.info(f"Waiting for rollout of '{deployment_name}' to complete...")
        rollout_cmd = [
            'kubectl', 'rollout', 'status',
            f'deployment/{deployment_name}',
            '-n', 'default',
            '--timeout=5m'
        ]
        
        rollout_result = subprocess.run(
            rollout_cmd,
            capture_output=True,
            text=True,
            timeout=320
        )
        
        if rollout_result.returncode != 0:
            logger.error(f"Rollout failed: {rollout_result.stderr}")
            return False, rollout_result.stderr
        
        logger.info(f"Rollout completed successfully: {rollout_result.stdout}")
        return True, "Deployment updated successfully"
        
    except subprocess.TimeoutExpired:
        error_msg = "Deployment update timed out"
        logger.error(error_msg)
        return False, error_msg
    except Exception as e:
        error_msg = f"Error updating deployment: {str(e)}"
        logger.error(error_msg)
        return False, error_msg

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'webhook-receiver'
    }), 200

@app.route('/webhook', methods=['POST'])
def webhook():
    """Main webhook endpoint for Docker Hub notifications"""
    try:
        # Log the incoming request
        logger.info("Received webhook request")
        logger.debug(f"Headers: {dict(request.headers)}")
        
        # Get the payload
        payload = request.get_data()
        data = request.get_json()
        
        if not data:
            logger.error("No JSON payload received")
            return jsonify({'error': 'No JSON payload'}), 400
        
        logger.info(f"Webhook payload: {json.dumps(data, indent=2)}")
        
        # Validate signature if secret is configured
        signature = request.headers.get('X-Hub-Signature', '')
        if WEBHOOK_SECRET and not validate_signature(payload, signature):
            logger.error("Invalid webhook signature")
            return jsonify({'error': 'Invalid signature'}), 403
        
        # Extract repository and tag information
        repo_name = data.get('repository', {}).get('repo_name')
        tag = data.get('push_data', {}).get('tag', 'latest')
        
        if not repo_name:
            logger.error("No repository name in payload")
            return jsonify({'error': 'No repository name'}), 400
        
        logger.info(f"Processing webhook for repository: {repo_name}, tag: {tag}")
        
        # Map repository to deployment
        deployment_name = REPO_TO_DEPLOYMENT.get(repo_name)
        
        if not deployment_name:
            logger.warning(f"No deployment mapping found for repository: {repo_name}")
            return jsonify({
                'status': 'ignored',
                'message': f'No deployment configured for {repo_name}'
            }), 200
        
        # Update the deployment
        success, message = update_deployment(deployment_name, repo_name, tag)
        
        if success:
            response = {
                'status': 'success',
                'deployment': deployment_name,
                'image': f'{repo_name}:{tag}',
                'message': message,
                'timestamp': datetime.now().isoformat()
            }
            logger.info(f"Webhook processed successfully: {response}")
            return jsonify(response), 200
        else:
            response = {
                'status': 'failed',
                'deployment': deployment_name,
                'image': f'{repo_name}:{tag}',
                'error': message,
                'timestamp': datetime.now().isoformat()
            }
            logger.error(f"Webhook processing failed: {response}")
            return jsonify(response), 500
            
    except Exception as e:
        error_msg = f"Unexpected error processing webhook: {str(e)}"
        logger.error(error_msg, exc_info=True)
        return jsonify({
            'status': 'error',
            'error': error_msg,
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/', methods=['GET'])
def index():
    """Root endpoint - provides service information"""
    return jsonify({
        'service': 'Docker Hub Webhook Receiver',
        'version': '1.0.0',
        'endpoints': {
            'health': '/health',
            'webhook': '/webhook (POST only)'
        },
        'configured_repositories': list(REPO_TO_DEPLOYMENT.keys())
    }), 200

if __name__ == '__main__':
    logger.info("Starting Docker Hub Webhook Receiver on port 9000...")
    app.run(host='0.0.0.0', port=9000, debug=False)
EOF

# Make the script executable
sudo chmod +x /opt/webhook-receiver/webhook_server.py

#############################################
# 5. Create Systemd Service
#############################################
log "Creating systemd service..."

sudo tee /etc/systemd/system/webhook-receiver.service > /dev/null <<'EOF'
[Unit]
Description=Docker Hub Webhook Receiver
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webhook-receiver
ExecStart=/usr/bin/python3 /opt/webhook-receiver/webhook_server.py
Restart=always
RestartSec=10
StandardOutput=append:/var/log/webhook-receiver/service.log
StandardError=append:/var/log/webhook-receiver/service-error.log

# Environment variables (optional)
# Environment="WEBHOOK_SECRET=your-secret-here"

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

#############################################
# 6. Create Helper Scripts
#############################################
log "Creating helper scripts..."

# Script to configure kubectl with kubeconfig
sudo tee /opt/webhook-receiver/configure-kubectl.sh > /dev/null <<'EOF'
#!/bin/bash
# This script should be run AFTER the Kubernetes cluster is set up
# It configures kubectl to communicate with the K8s master

echo "Kubectl Configuration Helper"
echo "============================="
echo ""
echo "To configure kubectl on this webhook server, you need to:"
echo ""
echo "1. On your Kubernetes MASTER server, create a service account:"
echo "   kubectl apply -f /path/to/webhook-rbac.yaml"
echo ""
echo "2. Generate a kubeconfig file on the master:"
echo "   Run the kubeconfig generation script"
echo ""
echo "3. Copy the kubeconfig to this server:"
echo "   scp -i key.pem webhook-kubeconfig ec2-user@<THIS-SERVER-IP>:/home/ec2-user/.kube/config"
echo ""
echo "4. Test the connection:"
echo "   kubectl get nodes"
echo ""
echo "Current kubectl status:"
kubectl cluster-info || echo "kubectl not yet configured"
EOF

sudo chmod +x /opt/webhook-receiver/configure-kubectl.sh

# Create .kube directory for root user
sudo mkdir -p /root/.kube
sudo chmod 700 /root/.kube

#############################################
# 7. Enable and Start Service
#############################################
log "Enabling webhook-receiver service..."
sudo systemctl daemon-reload
sudo systemctl enable webhook-receiver.service

# Note: We don't start the service yet because kubectl needs to be configured first
log "Service enabled but not started (kubectl needs to be configured first)"

#############################################
# 8. Create README for post-setup
#############################################
sudo tee /opt/webhook-receiver/README.md > /dev/null <<'EOF'
# Webhook Receiver Setup Complete

## Next Steps

### 1. Configure Kubernetes Access

The webhook receiver needs access to your Kubernetes cluster. Follow these steps:

#### On the Kubernetes Master Server:

Create the RBAC configuration:

```bash
kubectl apply -f - <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webhook-deployer
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: webhook-deployer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: webhook-deployer
  namespace: default
YAML
```

Generate kubeconfig:

```bash
# Get the service account token
SECRET=$(kubectl get sa webhook-deployer -n default -o jsonpath="{.secrets[0].name}")
TOKEN=$(kubectl get secret $SECRET -n default -o jsonpath='{.data.token}' | base64 --decode)
kubectl get secret $SECRET -n default -o jsonpath='{.data.ca\.crt}' | base64 --decode > ca.crt
SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

# Create kubeconfig
cat > webhook-kubeconfig <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
- name: k8s-cluster
  cluster:
    certificate-authority-data: $(kubectl get secret $SECRET -n default -o jsonpath='{.data.ca\.crt}')
    server: $SERVER
contexts:
- name: webhook-context
  context:
    cluster: k8s-cluster
    user: webhook-deployer
current-context: webhook-context
users:
- name: webhook-deployer
  user:
    token: $TOKEN
KUBECONFIG
```

Copy to webhook server:

```bash
scp -i your-key.pem webhook-kubeconfig ec2-user@<WEBHOOK-SERVER-IP>:/tmp/
```

#### On This Webhook Server:

```bash
sudo mv /tmp/webhook-kubeconfig /root/.kube/config
sudo chmod 600 /root/.kube/config

# Test connection
sudo kubectl get nodes

# Start the webhook service
sudo systemctl start webhook-receiver
sudo systemctl status webhook-receiver
```

### 2. Configure Docker Hub Webhooks

For each repository (e.g., ganil151/customers-service):

1. Go to Docker Hub → Repository → Webhooks
2. Add webhook URL: `http://<WEBHOOK-SERVER-PUBLIC-IP>:9000/webhook`
3. Name it: `k8s-deployment-trigger`

### 3. Test the Webhook

```bash
# Check service status
sudo systemctl status webhook-receiver

# View logs
sudo tail -f /var/log/webhook-receiver/webhook.log

# Test health endpoint
curl http://localhost:9000/health

# Trigger a test deployment (push to Docker Hub)
```

### 4. Security Hardening (Production)

- Configure security group to allow port 9000 only from Docker Hub IPs
- Set up nginx reverse proxy with SSL/TLS
- Configure webhook secret validation
- Enable firewall rules

## Service Management

```bash
# Start service
sudo systemctl start webhook-receiver

# Stop service
sudo systemctl stop webhook-receiver

# Restart service
sudo systemctl restart webhook-receiver

# View status
sudo systemctl status webhook-receiver

# View logs
sudo journalctl -u webhook-receiver -f
sudo tail -f /var/log/webhook-receiver/webhook.log
```

## Troubleshooting

### Service won't start
```bash
sudo journalctl -u webhook-receiver -n 50
```

### kubectl not working
```bash
sudo kubectl get nodes
# If error, check /root/.kube/config exists and is valid
```

### Deployments not updating
```bash
# Check webhook logs
sudo tail -f /var/log/webhook-receiver/webhook.log

# Manually test deployment update
sudo kubectl set image deployment/customers-service customers-service=ganil151/customers-service:latest
```

## File Locations

- Application: `/opt/webhook-receiver/webhook_server.py`
- Service: `/etc/systemd/system/webhook-receiver.service`
- Logs: `/var/log/webhook-receiver/`
- Kubeconfig: `/root/.kube/config`
EOF

#############################################
# 9. Display Setup Summary
#############################################
log "========================================="
log "Webhook Receiver Setup Complete!"
log "========================================="
log ""
log "Installation Summary:"
log "  - Python3 and Flask installed"
log "  - kubectl installed"
log "  - Webhook application created at /opt/webhook-receiver/"
log "  - Systemd service configured (not started)"
log ""
log "Next Steps:"
log "  1. Configure kubectl with kubeconfig from K8s master"
log "  2. Start the webhook service: sudo systemctl start webhook-receiver"
log "  3. Configure Docker Hub webhooks"
log ""
log "Documentation: /opt/webhook-receiver/README.md"
log "Helper script: /opt/webhook-receiver/configure-kubectl.sh"
log ""
log "========================================="

