# Docker Hub Webhook Setup Guide

This guide explains how to set up Docker Hub webhooks to automatically update your Kubernetes deployments when new Docker images are pushed.

## Overview

**What happens:**
1. You push code to GitHub
2. Jenkins builds the project and creates a Docker image
3. Jenkins pushes the Docker image to Docker Hub
4. Docker Hub sends a webhook notification to your server
5. Webhook receiver updates the Kubernetes deployment automatically
6. New pods are created with the updated image

## Prerequisites

- Kubernetes cluster running (Master + Worker nodes)
- `kubectl` configured on the master node
- Docker Hub account with your images
- Public IP address or domain name for your webhook receiver

---

## Step 1: Set Up the Webhook Receiver on Kubernetes Master

### 1.1 Copy the webhook receiver script to the master node

```bash
# From your local machine
scp -i terraform/app/master_keys.pem \
    kubernetes/scripts/webhook-receiver.py \
    ec2-user@<MASTER-IP>:~/
```

### 1.2 SSH to the master node

```bash
ssh -i terraform/app/master_keys.pem ec2-user@<MASTER-IP>
```

### 1.3 Move the script to /root and set permissions

```bash
sudo mv webhook-receiver.py /root/
sudo chmod +x /root/webhook-receiver.py
```

### 1.4 Create the systemd service

```bash
# Copy the service file
sudo cp docker-webhook.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable docker-webhook

# Start the service
sudo systemctl start docker-webhook

# Check status
sudo systemctl status docker-webhook
```

### 1.5 Verify the webhook receiver is running

```bash
# Check if it's listening on port 9000
sudo netstat -tlnp | grep 9000

# Check logs
sudo journalctl -u docker-webhook -f
```

---

## Step 2: Configure Firewall/Security Group

### 2.1 Open port 9000 on the master node

**On the master node (if using firewalld):**
```bash
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload
```

**On AWS Security Group:**
1. Go to EC2 Console → Security Groups
2. Find the security group for your master node
3. Add inbound rule:
   - Type: Custom TCP
   - Port: 9000
   - Source: 0.0.0.0/0 (or restrict to Docker Hub IPs for better security)

---

## Step 3: Configure Docker Hub Webhooks

### 3.1 Get your master node's public IP

```bash
# On master node
curl ifconfig.me
```

### 3.2 Add webhook to Docker Hub

For **each Docker image repository**:

1. Go to [Docker Hub](https://hub.docker.com/)
2. Navigate to your repository (e.g., `ganil151/customers-service`)
3. Click on **"Webhooks"** tab
4. Click **"Create Webhook"**
5. Fill in:
   - **Webhook name**: `k8s-auto-deploy`
   - **Webhook URL**: `http://<MASTER-PUBLIC-IP>:9000`
6. Click **"Create"**

Repeat for all microservices:
- `ganil151/customers-service`
- `ganil151/vets-service`
- `ganil151/visits-service`
- `ganil151/api-gateway`
- `ganil151/discovery-server`
- `ganil151/config-server`
- `ganil151/admin-server`
- etc.

---

## Step 4: Test the Webhook

### 4.1 Manual test with curl

```bash
# Test the webhook receiver
curl -X POST http://<MASTER-IP>:9000 \
  -H "Content-Type: application/json" \
  -d '{
    "repository": {
      "repo_name": "ganil151/customers-service"
    },
    "push_data": {
      "tag": "latest"
    }
  }'
```

### 4.2 Check logs

```bash
# On master node
sudo journalctl -u docker-webhook -f
```

### 4.3 Verify deployment updated

```bash
kubectl get pods
kubectl describe deployment customers-service
```

---

## Step 5: Integrate with Jenkins

Update your Jenkinsfile to push images to Docker Hub after building:

```groovy
stage('Build and Push Docker Images') {
    steps {
        script {
            docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                sh '''
                    docker build -t ganil151/customers-service:${BUILD_NUMBER} ./spring-petclinic-customers-service
                    docker push ganil151/customers-service:${BUILD_NUMBER}
                    docker push ganil151/customers-service:latest
                '''
            }
        }
    }
}
```

When Jenkins pushes the image, Docker Hub will automatically trigger the webhook!

---

## Troubleshooting

### Webhook receiver not receiving requests

**Check if service is running:**
```bash
sudo systemctl status docker-webhook
```

**Check if port is open:**
```bash
sudo netstat -tlnp | grep 9000
```

**Check firewall:**
```bash
sudo firewall-cmd --list-all
```

**Check AWS Security Group** - Ensure port 9000 is open

### Deployment not updating

**Check kubectl access:**
```bash
sudo kubectl get nodes
```

**Check logs for errors:**
```bash
sudo journalctl -u docker-webhook -n 50
```

**Manually test deployment update:**
```bash
kubectl set image deployment/customers-service customers-service=ganil151/customers-service:latest
```

### Docker Hub webhook shows errors

- Verify the webhook URL is correct
- Check that the master node's public IP hasn't changed
- Ensure port 9000 is accessible from the internet

---

## Security Considerations

### 1. Use HTTPS (Recommended for Production)

Set up nginx as a reverse proxy with SSL:

```bash
sudo yum install -y nginx certbot
# Configure nginx to proxy port 443 to 9000
# Use Let's Encrypt for free SSL certificate
```

### 2. Add Webhook Secret Validation

Modify the webhook receiver to validate a secret token from Docker Hub.

### 3. Restrict IP Access

In AWS Security Group, restrict port 9000 to Docker Hub's IP ranges only.

---

## Monitoring

### View real-time logs

```bash
sudo journalctl -u docker-webhook -f
```

### View deployment rollout status

```bash
kubectl rollout status deployment/<service-name>
```

### Check webhook history on Docker Hub

Go to your repository → Webhooks → Click on webhook name → View delivery history

---

## Summary

✅ Webhook receiver installed and running as a systemd service  
✅ Port 9000 open in firewall and security group  
✅ Docker Hub webhooks configured for all repositories  
✅ Automatic deployment updates on image push  

Now whenever you push a new Docker image to Docker Hub, your Kubernetes deployment will automatically update! 🚀
