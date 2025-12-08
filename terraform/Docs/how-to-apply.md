# Spring Petclinic Microservices - Complete Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup with Terraform](#infrastructure-setup-with-terraform)
3. [Server Configuration](#server-configuration)
4. [Kubernetes Cluster Setup](#kubernetes-cluster-setup)
5. [Jenkins Configuration](#jenkins-configuration)
6. [Application Deployment](#application-deployment)
7. [Monitoring Setup](#monitoring-setup)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts & Access
- [x] AWS Account with appropriate permissions
- [x] GitHub Account
- [x] Docker Hub Account
- [x] SSH Key Pair for EC2 instances

### Local Tools Installation
- [x] Terraform >= 1.0
- [x] AWS CLI v2
- [x] Git
- [x] SSH Client

### Configure AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

---

## 1. Infrastructure Setup with Terraform

### 1.1 Clone the Repository
```bash
git clone https://github.com/<your-username>/spring-petclinic-microservices.git
cd spring-petclinic-microservices
```

### 1.2 Configure Terraform Variables
Edit `terraform/app/terraform.tfvars`:
```hcl
# Network Configuration
aws-region          = "us-east-1"
vpc-cidr-block      = "10.7.0.0/16"
subnet-cidr-block   = "10.7.0.0/24"

# EC2 Configuration
instance-type       = "t2.medium"
key-name            = "your-key-pair-name"  # Change this to your SSH key
instance-ami        = "ami-01816d07b1128cd2d"  # Amazon Linux 2023

# Server Configuration
master-server-name     = "Master-Server"
worker-server-name     = "Worker-Server"
mysql-server-name      = "Mysql-Server"
monitoring-server-name = "Monitor-Server"

# Kubernetes Configuration
k8s-master-server-name    = "K8s-Master-Server"
k8s-agent-1-server-name   = "K8s-Worker-Server"
k8s-agent-2-server-name   = "K8s-Agent-2-Server"
```

### 1.3 Initialize Terraform
```bash
cd terraform/app
terraform init
```

### 1.4 Review Infrastructure Plan
```bash
terraform plan
```

Review the output to ensure all resources will be created correctly:
- ✓ 7 EC2 Instances
- ✓ VPC and Subnet
- ✓ Security Groups with appropriate rules
- ✓ Internet Gateway and Route Tables

### 1.5 Apply Terraform Configuration
```bash
terraform apply

# Review the plan
# Type 'yes' to confirm
```

**Wait Time:** Approximately 10-15 minutes for all servers to initialize

### 1.6 Verify Infrastructure
```bash
# List all created instances
terraform show

# Get instance IPs
terraform output

# Or use AWS CLI
aws ec2 describe-instances --filters "Name=tag:Name,Values=*Server*" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,State.Name]' \
  --output table
```

---

## 2. Server Configuration

### 2.1 Wait for User Data Scripts to Complete

All servers run initialization scripts automatically via user_data. Monitor progress:

```bash
# SSH into each server and check cloud-init status
ssh -i ~/.ssh/your-key.pem ec2-user@<server-ip>

# Check cloud-init status
sudo cloud-init status

# View initialization logs
sudo tail -f /var/log/cloud-init-output.log

# Check if services are running (example for master server)
sudo systemctl status jenkins  # On Master Server
sudo systemctl status docker   # On Worker Server
sudo systemctl status mysqld   # On MySQL Server
```

**Expected Initialization Times:**
- Master Server (Jenkins): ~5-8 minutes
- Worker Server: ~4-6 minutes
- MySQL Server: ~3-5 minutes
- Monitoring Server: ~6-10 minutes
- K8s Master: ~8-12 minutes
- K8s Agents: ~5-7 minutes each

### 2.2 Master Server (Jenkins) Verification

```bash
# SSH to Master Server
ssh -i ~/.ssh/your-key.pem ec2-user@<master-server-ip>

# Verify Jenkins is running
sudo systemctl status jenkins

# Get Jenkins initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Get Jenkins SSH public key (for GitHub deploy keys)
sudo cat /var/lib/jenkins/.ssh/id_rsa.pub
```

**Jenkins URL:** `http://<master-server-ip>:8080`

### 2.3 MySQL Server Verification

```bash
# SSH to MySQL Server
ssh -i ~/.ssh/your-key.pem ec2-user@<mysql-server-ip>

# Verify MySQL is running
sudo systemctl status mysqld

# MySQL root password (from script output)
# Default: Mysql$9999!

# Test MySQL connection
mysql -u root -p'Mysql$9999!'
```

### 2.4 Monitoring Server Verification

```bash
# SSH to Monitoring Server
ssh -i ~/.ssh/your-key.pem ec2-user@<monitoring-server-ip>

# Verify Prometheus
sudo systemctl status prometheus

# Verify Grafana
sudo systemctl status grafana-server
```

**Access URLs:**
- Prometheus: `http://<monitoring-server-ip>:9090`
- Grafana: `http://<monitoring-server-ip>:3000` (admin/admin)

---

## 3. Kubernetes Cluster Setup

### 3.1 K8s Master Node Setup

```bash
# SSH to K8s Master
ssh -i ~/.ssh/your-key.pem ec2-user@<k8s-master-ip>

# Wait for initialization to complete (check cloud-init logs)
sudo tail -f /var/log/cloud-init-output.log

# Verify cluster is initialized
kubectl get nodes

# Get join command for worker nodes
sudo cat /root/k8s_join_command.sh
```

### 3.2 Join Worker Nodes to Cluster

#### Agent 1 (Primary Worker)
```bash
# SSH to Agent 1
ssh -i ~/.ssh/your-key.pem ec2-user@<k8s-agent-1-ip>

# Get join command from master
JOIN_COMMAND=$(ssh ec2-user@<k8s-master-ip> 'sudo kubeadm token create --print-join-command')

# Execute join command
sudo $JOIN_COMMAND

# Wait for join to complete (~2-3 minutes)
```

#### Agent 2 (Secondary Worker)
```bash
# SSH to Agent 2
ssh -i ~/.ssh/your-key.pem ec2-user@<k8s-agent-2-ip>

# Get join command from master
JOIN_COMMAND=$(ssh ec2-user@<k8s-master-ip> 'sudo kubeadm token create --print-join-command')

# Execute join command
sudo $JOIN_COMMAND

# Wait for join to complete (~2-3 minutes)
```

### 3.3 Apply Node Labels (On Master Node)

```bash
# SSH to K8s Master
ssh -i ~/.ssh/your-key.pem ec2-user@<k8s-master-ip>

# Label Agent 1 (Primary Worker)
kubectl label node K8s-Worker-Server node-role.kubernetes.io/worker=worker
kubectl label node K8s-Worker-Server node.kubernetes.io/role=K8s-primary-agent

# Label Agent 2 (Secondary Worker)
kubectl label node K8s-Agent-2-Server node-role.kubernetes.io/worker=worker
kubectl label node K8s-Agent-2-Server node.kubernetes.io/role=K8s-secondary-agent

# Verify labels
kubectl get nodes --show-labels
```

Expected output:
```
NAME                   STATUS   ROLES           AGE   VERSION
K8s-Master-Server      Ready    control-plane   10m   v1.31.0
K8s-Worker-Server      Ready    worker          8m    v1.31.0
K8s-Agent-2-Server     Ready    worker          8m    v1.31.0
```

### 3.4 Verify Calico CNI Installation

```bash
# Check Calico pods
kubectl get pods -n calico-system

# All pods should be in Running state
# Wait 2-3 minutes if some are still initializing
```

---

## 4. Jenkins Configuration

### 4.1 Access Jenkins Dashboard

1. Open browser: `http://<master-server-ip>:8080`
2. Enter initial admin password (from step 2.2)
3. Install suggested plugins
4. Create admin user
5. Configure Jenkins URL

### 4.2 Install Required Plugins

Navigate to: **Manage Jenkins → Plugins → Available Plugins**

Install the following plugins:
- [x] Docker
- [x] Docker Commons
- [x] Docker Pipeline
- [x] Docker API
- [x] docker-build-step
- [x] Kubernetes
- [x] Kubernetes CLI
- [x] Kubernetes Client API
- [x] Kubernetes Credentials
- [x] Config File Provider
- [x] Pipeline Stage View
- [x] Prometheus Metrics
- [x] Git Parameter

### 4.3 Configure Credentials

Navigate to: **Manage Jenkins → Credentials → System → Global credentials**

#### Add Docker Hub Credentials
- **Kind:** Username with password
- **ID:** `dockerhub-creds`
- **Username:** Your Docker Hub username
- **Password:** Your Docker Hub password/token

#### Add GitHub Credentials (if private repo)
- **Kind:** Username with password
- **ID:** `github-creds`
- **Username:** Your GitHub username
- **Password:** Your GitHub Personal Access Token

#### Add Kubernetes Credentials

On K8s Master, copy the kubeconfig:
```bash
# On K8s Master
cat ~/.kube/config
```

In Jenkins:
- **Kind:** Secret file
- **ID:** `k8s-kubeconfig`
- **File:** Upload or paste kubeconfig content

### 4.4 Configure Tools

Navigate to: **Manage Jenkins → Tools**

#### Maven Configuration
- **Name:** Maven-3.9
- **Install automatically:** ✓
- **Version:** 3.9.x

#### JDK Configuration
- **Name:** Java-21
- **JAVA_HOME:** `/usr/lib/jvm/java-21-amazon-corretto`

### 4.5 Add Jenkins SSH Key to GitHub

```bash
# On Master Server, get Jenkins public key
sudo cat /var/lib/jenkins/.ssh/id_rsa.pub
```

1. Go to GitHub → Your Repository → Settings → Deploy keys
2. Click "Add deploy key"
3. Paste the public key
4. Enable "Allow write access" if needed
5. Save

---

## 5. Application Deployment

### 5.1 Prepare Kubernetes Namespaces

```bash
# On K8s Master
kubectl create namespace spring-petclinic
kubectl create namespace monitoring
```

### 5.2 Deploy MySQL Database

```bash
# Create MySQL secret
kubectl create secret generic mysql-secret \
  --from-literal=mysql-root-password='Mysql$9999!' \
  --from-literal=mysql-password='petclinic' \
  -n spring-petclinic

# Deploy MySQL
kubectl apply -f kubernetes/mysql-deployment.yaml -n spring-petclinic

# Verify MySQL is running
kubectl get pods -n spring-petclinic
```

### 5.3 Deploy Config Server (First)

The Config Server must be deployed first as other services depend on it.

```bash
# Deploy Config Server
kubectl apply -f kubernetes/config-server-deployment.yaml -n spring-petclinic

# Wait for Config Server to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/config-server -n spring-petclinic

# Verify it's running
kubectl get pods -n spring-petclinic -l app=config-server
```

### 5.4 Deploy Discovery Server (Second)

```bash
# Deploy Discovery Server
kubectl apply -f kubernetes/discovery-server-deployment.yaml -n spring-petclinic

# Wait for Discovery Server to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/discovery-server -n spring-petclinic
```

### 5.5 Deploy Microservices

Deploy in this order:

```bash
# 1. Customers Service
kubectl apply -f kubernetes/customers-service-deployment.yaml -n spring-petclinic

# 2. Vets Service
kubectl apply -f kubernetes/vets-service-deployment.yaml -n spring-petclinic

# 3. Visits Service
kubectl apply -f kubernetes/visits-service-deployment.yaml -n spring-petclinic

# 4. API Gateway
kubectl apply -f kubernetes/api-gateway-deployment.yaml -n spring-petclinic

# 5. Admin Server
kubectl apply -f kubernetes/admin-server-deployment.yaml -n spring-petclinic

# Wait for all deployments
kubectl wait --for=condition=available --timeout=600s \
  --all deployments -n spring-petclinic
```

### 5.6 Verify All Services

```bash
# Check all pods
kubectl get pods -n spring-petclinic

# Check all services
kubectl get svc -n spring-petclinic

# Check pod logs if any issues
kubectl logs -f <pod-name> -n spring-petclinic
```

### 5.7 Deploy Ingress Controller

```bash
# Deploy NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/ingress-nginx-controller -n ingress-nginx

# Get NodePort for access
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### 5.8 Deploy Application Ingress

```bash
# Deploy ingress rules
kubectl apply -f kubernetes/ingress.yaml -n spring-petclinic

# Verify ingress
kubectl get ingress -n spring-petclinic
```

### 5.9 Access the Application

Get the NodePort from ingress controller:
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

Access the application:
- **URL:** `http://<k8s-master-ip>:<nodeport>`
- Or configure DNS/LoadBalancer pointing to the K8s cluster

---

## 6. Jenkins Pipeline Configuration

### 6.1 Create Jenkins Pipeline Job

1. **Jenkins Dashboard** → **New Item**
2. **Name:** `petclinic-microservices-pipeline`
3. **Type:** Pipeline
4. Click **OK**

### 6.2 Configure Pipeline

#### General Settings
- [x] **GitHub project:** `https://github.com/<your-username>/spring-petclinic-microservices`

#### Build Triggers
- [x] **GitHub hook trigger for GITScm polling**
- [x] **Poll SCM:** `H/5 * * * *` (every 5 minutes as backup)

#### Pipeline Definition
- **Definition:** Pipeline script from SCM
- **SCM:** Git
- **Repository URL:** `https://github.com/<your-username>/spring-petclinic-microservices.git`
- **Credentials:** Select your GitHub credentials
- **Branch:** `*/master` or `*/main`
- **Script Path:** `Jenkinsfile`

### 6.3 Jenkinsfile Overview

The Jenkinsfile should include these stages:

1. **Git Checkout:** Clone the repository
2. **Build:** Compile with Maven
3. **Test:** Run unit tests
4. **Docker Build:** Build Docker images
5. **Docker Push:** Push to Docker Hub
6. **Deploy to K8s:** Apply Kubernetes manifests
7. **Verify Deployment:** Check pod status

### 6.4 Configure GitHub Webhook

1. Go to GitHub Repository → **Settings** → **Webhooks**
2. Click **Add webhook**
3. **Payload URL:** `http://<master-server-ip>:8080/github-webhook/`
4. **Content type:** `application/json`
5. **Events:** Just the push event
6. **Active:** ✓
7. Save

### 6.5 Run First Build

1. Go to Jenkins job
2. Click **Build Now**
3. Monitor the build progress in **Console Output**

---

## 7. Monitoring Setup

### 7.1 Configure Prometheus

```bash
# SSH to Monitoring Server
ssh -i ~/.ssh/your-key.pem ec2-user@<monitoring-server-ip>

# Edit Prometheus config
sudo vi /etc/prometheus/prometheus.yml
```

Add these scrape configs:

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<monitoring-server-ip>:9100']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['<master-server-ip>:8080']

  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
        api_server: 'https://<k8s-master-ip>:6443'
        tls_config:
          insecure_skip_verify: true
```

Reload Prometheus:
```bash
curl -X POST http://localhost:9090/-/reload
```

### 7.2 Configure Grafana Dashboards

1. **Access Grafana:** `http://<monitoring-server-ip>:3000`
2. **Login:** admin/admin (change password)

#### Add Prometheus Data Source
1. **Configuration** → **Data Sources** → **Add data source**
2. Select **Prometheus**
3. **URL:** `http://localhost:9090`
4. Click **Save & Test**

#### Import Dashboards

**Node Exporter Dashboard:**
1. **Dashboards** → **Import**
2. **Dashboard ID:** `1860`
3. **Load** → Select **Prometheus** data source
4. **Import**

**Jenkins Dashboard:**
1. **Dashboards** → **Import**
2. **Dashboard ID:** `9964`
3. **Load** → Select **Prometheus** data source
4. **Import**

**Kubernetes Cluster Dashboard:**
1. **Dashboards** → **Import**
2. **Dashboard ID:** `3119`
3. **Load** → Select **Prometheus** data source
4. **Import**

---

## 8. Troubleshooting

### 8.1 Infrastructure Issues

#### Terraform Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform configuration
terraform validate

# Check specific error in logs
terraform apply 2>&1 | tee terraform-error.log
```

#### EC2 Instances Not Accessible
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id>

# Verify SSH key permissions
chmod 400 ~/.ssh/your-key.pem
```

### 8.2 Kubernetes Issues

#### Nodes Not Ready
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet logs
sudo journalctl -u kubelet -f

# Restart kubelet
sudo systemctl restart kubelet
```

#### Pods CrashLooping
```bash
# Check pod logs
kubectl logs <pod-name> -n spring-petclinic

# Describe pod for events
kubectl describe pod <pod-name> -n spring-petclinic

# Check resource limits
kubectl top pods -n spring-petclinic
```

#### Config Server Connection Issues
```bash
# Verify Config Server is running
kubectl get pods -n spring-petclinic -l app=config-server

# Check Config Server logs
kubectl logs -f deployment/config-server -n spring-petclinic

# Test Config Server endpoint
kubectl exec -it <any-pod> -n spring-petclinic -- curl http://config-server:8888/health
```

### 8.3 Jenkins Issues

#### Build Failures
```bash
# Check Jenkins logs
sudo journalctl -u jenkins -f

# On Jenkins server, check disk space
df -h

# Check Maven installation
mvn --version

# Verify Docker access
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

#### Kubernetes Deployment from Jenkins Fails
```bash
# Verify kubeconfig is accessible
# In Jenkins pipeline
kubectl get nodes

# Check Jenkins has correct credentials
# Verify network connectivity from Jenkins to K8s API
telnet <k8s-master-ip> 6443
```

### 8.4 MySQL Issues

#### Connection Refused
```bash
# Check MySQL service
sudo systemctl status mysqld

# Verify MySQL is listening
sudo netstat -tlnp | grep 3306

# Check MySQL logs
sudo tail -f /var/log/mysqld.log

# Test connection
mysql -u root -p'Mysql$9999!' -h localhost
```

#### Permission Denied
```bash
# Reset MySQL password if needed
sudo systemctl stop mysqld
sudo mysqld_safe --skip-grant-tables &
mysql -u root
```

### 8.5 Network Issues

#### Pods Can't Communicate
```bash
# Check Calico pods
kubectl get pods -n calico-system

# Verify network policies
kubectl get networkpolicies -A

# Test pod-to-pod communication
kubectl run test-pod --image=busybox -it --rm -- sh
# Inside pod
nslookup config-server
wget -O- http://config-server:8888/health
```

### 8.6 Common Error Solutions

| Error | Solution |
|-------|----------|
| Port already in use | `sudo lsof -i :<port>` then kill process |
| Permission denied (Docker) | `sudo usermod -aG docker $USER` then logout/login |
| No space left on device | Clean up: `docker system prune -a` |
| Connection refused to K8s API | Check firewall: `sudo iptables -L` |
| Pod pending forever | Check node resources: `kubectl describe node` |

---

## 9. Cleanup

### 9.1 Destroy Kubernetes Resources
```bash
# Delete all resources in namespace
kubectl delete namespace spring-petclinic --cascade=true

# Delete ingress controller
kubectl delete namespace ingress-nginx
```

### 9.2 Destroy Infrastructure
```bash
# Navigate to Terraform directory
cd terraform/app

# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type 'yes' to confirm
```

**Warning:** This will permanently delete all EC2 instances, VPC, and associated resources!

---

## 10. Best Practices

### Security
- [x] Change all default passwords immediately
- [x] Use IAM roles instead of access keys where possible
- [x] Enable MFA for AWS root account
- [x] Regularly rotate credentials
- [x] Use secrets management (AWS Secrets Manager or Kubernetes Secrets)
- [x] Enable SSL/TLS for all public endpoints

### Cost Optimization
- [x] Stop instances when not in use
- [x] Use appropriate instance types
- [x] Monitor AWS costs with AWS Cost Explorer
- [x] Clean up unused resources regularly
- [x] Consider spot instances for non-production

### Monitoring
- [x] Set up alerts in Prometheus/Grafana
- [x] Monitor disk space on all servers
- [x] Track application metrics
- [x] Set up log aggregation (ELK or CloudWatch)

### Backup
- [x] Regular backups of MySQL database
- [x] Backup Jenkins configuration
- [x] Version control all configuration files
- [x] Document infrastructure changes

---

## 11. Quick Reference

### Important URLs
| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Jenkins | `http://<master-ip>:8080` | See `/var/lib/jenkins/secrets/initialAdminPassword` |
| Prometheus | `http://<monitoring-ip>:9090` | None |
| Grafana | `http://<monitoring-ip>:3000` | admin / admin |
| Application | `http://<k8s-ip>:<nodeport>` | None |

### SSH Commands
```bash
# Master Server
ssh -i ~/.ssh/your-key.pem ec2-user@<master-ip>

# K8s Master
ssh -i ~/.ssh/your-key.pem ec2-user@<k8s-master-ip>

# Monitoring Server
ssh -i ~/.ssh/your-key.pem ec2-user@<monitoring-ip>
```

### Useful Kubectl Commands
```bash
# Get all resources
kubectl get all -A

# Check cluster health
kubectl cluster-info
kubectl get componentstatuses

# View logs
kubectl logs -f <pod-name> -n <namespace>

# Execute into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Port forward
kubectl port-forward <pod-name> 8080:8080 -n <namespace>
```

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review application logs
3. Check GitHub Issues
4. Contact the development team

---

**Last Updated:** 2025-11-29
**Version:** 1.0