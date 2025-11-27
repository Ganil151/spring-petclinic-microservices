# AWS EKS Deployment for Spring Petclinic Microservices

Complete guide for deploying Spring Petclinic Microservices on AWS EKS (Elastic Kubernetes Service) using Terraform.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment Steps](#deployment-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)
- [Additional Resources](#additional-resources)

## 🎯 Overview

This directory contains everything you need to deploy a production-ready EKS cluster for the Spring Petclinic Microservices application.

### What is EKS?

AWS Elastic Kubernetes Service (EKS) is a managed Kubernetes service that:
- ✅ **Eliminates Master Node Management** - AWS manages the control plane
- ✅ **High Availability** - Multi-AZ control plane by default
- ✅ **Auto-Scaling** - Dynamic node scaling based on demand
- ✅ **AWS Integration** - Native integration with ALB, EBS, IAM, CloudWatch
- ✅ **Security** - IAM integration, network policies, and secrets encryption

### Why EKS for Spring Petclinic?

Migrating from self-managed Kubernetes to EKS provides:
1. **No more manual cluster maintenance** - No need to manage master nodes
2. **Better reliability** - Automated backups and disaster recovery
3. **Easier scaling** - Managed node groups with autoscaling
4. **Cost optimization** - Pay only for worker nodes, managed control plane
5. **AWS ecosystem** - Seamless integration with other AWS services

## 🏗️ Architecture

### Cluster Configuration

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS EKS Cluster                          │
│                  (spring-petclinic-eks)                      │
├─────────────────────────────────────────────────────────────┤
│  Control Plane (Managed by AWS)                             │
│  • Kubernetes API Server                                    │
│  • etcd (Multi-AZ)                                          │
│  • Controller Manager                                        │
│  • Scheduler                                                 │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │                                       │
┌───────▼──────────┐                  ┌────────▼─────────┐
│  Node Group 1    │                  │  Node Group 2    │
│  "primary"       │                  │  "secondary"     │
├──────────────────┤                  ├──────────────────┤
│ Instance: t3.large│                 │ Instance: t3.xlarge│
│ Nodes: 1-2       │                  │ Nodes: 1-3       │
│ Disk: 50 GB      │                  │ Disk: 50 GB      │
│                  │                  │                  │
│ • Config Server  │                  │ • API Gateway    │
│ • Discovery Svr  │                  │ • Customers Svc  │
│ • Admin Server   │                  │ • Vets Service   │
│ • Prometheus     │                  │ • Visits Service │
│                  │                  │ • GenAI Service  │
└──────────────────┘                  └──────────────────┘
```

### Node Groups

| Node Group | Instance Type | Min | Desired | Max | Purpose |
|------------|---------------|-----|---------|-----|---------|
| **petclinic-worker-primary** | t3.large (2 vCPU, 8GB RAM) | 1 | 1 | 2 | Infrastructure services |
| **petclinic-worker-secondary** | t3.xlarge (4 vCPU, 16GB RAM) | 1 | 2 | 3 | Business microservices |

### Network Architecture

- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (Multi-AZ)
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24 (Multi-AZ)
- **Security Groups**: Configured with all required ports for K8s and Spring Boot apps

## ✅ Prerequisites

Before deploying the EKS cluster, ensure you have:

### Required Tools

- [x] **AWS CLI** (v2.x) - [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [x] **kubectl** (v1.28+) - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- [x] **Terraform** (v1.5+) - [Install Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [x] **eksctl** (optional) - [Install Guide](https://eksctl.io/installation/)

### AWS Requirements

- [x] **AWS Account** with appropriate permissions (EKS, EC2, VPC, IAM)
- [x] **AWS Credentials** configured (`aws configure`)
- [x] **IAM User ARN** for cluster admin access
- [x] **Key Pair** created in AWS (for SSH access to nodes)

### Verify Installation

```bash
# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x

# Check kubectl
kubectl version --client
# Expected: Client Version: v1.28+

# Check Terraform
terraform version
# Expected: Terraform v1.5+

# Verify AWS credentials
aws sts get-caller-identity
# Should return your AWS account details
```

## 🚀 Quick Start

### 1. Configure Terraform Variables

Edit `terraform/app/terraform.tfvars`:

```hcl
# Enable EKS
enable_eks = true

# EKS Cluster Configuration
eks_cluster_name    = "spring-petclinic-eks"
eks_cluster_version = "1.31"

# Admin IAM ARN (IMPORTANT: Set your IAM user ARN)
admin_iam_arn = "arn:aws:iam::123456789012:user/your-username"
```

> **Important**: Get your IAM ARN with: `aws sts get-caller-identity --query Arn --output text`

### 2. Deploy Infrastructure

```bash
# Navigate to Terraform directory
cd terraform/app

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes 15-20 minutes)
terraform apply
```

### 3. Configure kubectl

```bash
# Update kubeconfig to connect to EKS
aws eks update-kubeconfig --name spring-petclinic-eks --region us-east-1

# Verify connection
kubectl get nodes
```

### 4. Deploy Spring Petclinic

```bash
# Return to project root
cd ../..

# Deploy all microservices
kubectl apply -f kubernetes/deployments/deployment.yaml

# Watch deployment progress
kubectl get pods -w
```

### 5. Access Application

```bash
# Get API Gateway service details
kubectl get svc api-gateway

# Access via NodePort
http://<NODE-IP>:30080
```

## ⚙️ Configuration

### Terraform Configuration Files

| File | Purpose |
|------|---------|
| `terraform/app/main.tf` | Main Terraform configuration with EKS module |
| `terraform/app/terraform.tfvars` | Variable values for deployment |
| `terraform/app/variable.tf` | Variable definitions |
| `terraform/MODULES/eks/` | EKS cluster module |

### Key Configuration Options

#### EKS Cluster Settings

```hcl
# terraform/app/terraform.tfvars

# Enable/Disable EKS
enable_eks = true  # Set to false to destroy cluster

# Cluster Configuration
eks_cluster_name    = "spring-petclinic-eks"
eks_cluster_version = "1.31"  # Kubernetes version

# Admin User (REQUIRED)
admin_iam_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USERNAME"
```

#### Node Group Configuration

```hcl
eks_node_groups = {
  "petclinic-worker-primary" = {
    desired_size   = 1
    max_size       = 2
    min_size       = 1
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"  # or "SPOT" for cost savings
    disk_size      = 50
    labels = {
      role        = "primary"
      environment = "dev"
      application = "spring-petclinic"
    }
  }
  "petclinic-worker-secondary" = {
    desired_size   = 2
    max_size       = 3
    min_size       = 1
    instance_types = ["t3.xlarge"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    labels = {
      role        = "secondary"
      environment = "dev"
      application = "spring-petclinic"
    }
  }
}
```

### Customization Options

**Scaling Node Groups:**
```bash
# Via Terraform - update terraform.tfvars then apply
desired_size = 3

# Via AWS Console - Auto Scaling Groups
# Or use eksctl:
eksctl scale nodegroup --cluster spring-petclinic-eks \
  --name petclinic-worker-primary --nodes 3
```

**Using Spot Instances (50-70% cost savings):**
```hcl
capacity_type = "SPOT"
```

**Changing Instance Types:**
```hcl
instance_types = ["t3.medium"]  # Smaller
instance_types = ["t3.2xlarge"] # Larger
```

## 📦 Deployment Steps

### Step-by-Step Deployment

#### 1. Pre-Deployment Checklist

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check Terraform is initialized
cd terraform/app
terraform init

# Validate configuration
terraform validate
```

#### 2. Review Terraform Plan

```bash
terraform plan

# Look for:
# - module.eks_cluster[0] resources
# - Node groups configuration
# - VPC and security groups
```

#### 3. Create EKS Cluster

```bash
# Apply Terraform configuration
terraform apply

# Type 'yes' when prompted
# ⏱️ This takes 15-20 minutes
```

**Expected Output:**
```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:
eks_cluster_endpoint = "https://XXXXXX.gr7.us-east-1.eks.amazonaws.com"
eks_cluster_name = "spring-petclinic-eks"
eks_configure_kubectl = "aws eks update-kubeconfig --name spring-petclinic-eks --region us-east-1"
```

#### 4. Configure kubectl Access

```bash
# Update kubeconfig (use command from output)
aws eks update-kubeconfig --name spring-petclinic-eks --region us-east-1

# Verify nodes are ready
kubectl get nodes

# Expected:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xx.ec2.internal   Ready    <none>   5m    v1.31.x
# ip-10-0-2-xx.ec2.internal   Ready    <none>   5m    v1.31.x
```

#### 5. Deploy Spring Petclinic

```bash
# Navigate to project root
cd ../../

# Deploy all services
kubectl apply -f kubernetes/deployments/deployment.yaml

# Monitor deployment
kubectl get pods -w
```

#### 6. Verify Deployment

```bash
# Check all pods are running (wait 2-3 minutes)
kubectl get pods

# Check services
kubectl get svc

# Test health endpoints
kubectl exec -it deployment/api-gateway -- curl http://config-server:8888/actuator/health
```

## ✅ Verification

### Health Check Script

Run the comprehensive health check:

```bash
cd EKS
./eks-health-check.sh
```

This script checks:
- Cluster connectivity
- Node status
- Pod health
- Service availability
- Spring Petclinic services
- Resource usage

### Manual Verification

```bash
# 1. Check cluster info
kubectl cluster-info

# 2. Verify all nodes are ready
kubectl get nodes

# 3. Check all pods are running
kubectl get pods
# All should show STATUS: Running

# 4. Check services
kubectl get svc
# Verify all services have ClusterIP

# 5. Test service discovery (Eureka)
kubectl port-forward svc/discovery-server 8761:8761
# Open browser: http://localhost:8761
# Should see all services registered

# 6. Access API Gateway
kubectl get svc api-gateway
# Use NodePort or set up LoadBalancer
```

### Accessing Services

**Option 1: NodePort (Default)**
```bash
# Get node IP
kubectl get nodes -o wide

# Access API Gateway
http://<NODE-IP>:30080
```

**Option 2: Port Forwarding (Development)**
```bash
# Forward API Gateway port
kubectl port-forward svc/api-gateway 8080:8080

# Access locally
http://localhost:8080
```

**Option 3: LoadBalancer (Production)**

Update `kubernetes/deployments/deployment.yaml`:
```yaml
# Change api-gateway service type
spec:
  type: LoadBalancer  # Instead of NodePort
```

Then:
```bash
kubectl apply -f kubernetes/deployments/deployment.yaml
kubectl get svc api-gateway
# Wait for EXTERNAL-IP (AWS Load Balancer DNS)
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. kubectl Cannot Connect

**Error**: `Unable to connect to the server: dial tcp: lookup...`

**Solution**:
```bash
# Run the fix script
cd scripts
./fix-eks-cluster.sh

# Or manually update kubeconfig
aws eks update-kubeconfig --name spring-petclinic-eks --region us-east-1
```

#### 2. Pods Stuck in Pending

**Error**: Pods show `STATUS: Pending`

**Diagnosis**:
```bash
kubectl describe pod <pod-name>
# Look for events like:
# - Insufficient CPU/memory
# - No nodes available
```

**Solutions**:
```bash
# Check node resources
kubectl top nodes

# Scale up node group
terraform apply  # After updating desired_size in terraform.tfvars

# Or use AWS Console/eksctl
eksctl scale nodegroup --cluster spring-petclinic-eks \
  --name petclinic-worker-secondary --nodes 3
```

#### 3. Pods in CrashLoopBackOff

**Diagnosis**:
```bash
# Check pod logs
kubectl logs <pod-name>

# Check previous container logs
kubectl logs <pod-name> --previous

# Describe pod for events
kubectl describe pod <pod-name>
```

**Common Causes**:
- Insufficient memory (increase limits in deployment.yaml)
- Missing dependencies (check service startup order)
- Configuration errors (verify config-server is running)

#### 4. Terraform Apply Fails

**Error**: `Error creating EKS cluster`

**Solutions**:
```bash
# Check AWS permissions
aws sts get-caller-identity

# Verify IAM permissions for EKS, EC2, VPC

# Check Terraform state
terraform state list | grep eks

# If needed, destroy and recreate
terraform destroy -target=module.eks_cluster
terraform apply
```

#### 5. Cannot Access Admin IAM ARN

**Error**: `Error: Invalid IAM ARN`

**Solution**:
```bash
# Get your IAM ARN
aws sts get-caller-identity --query Arn --output text

# Update terraform.tfvars
admin_iam_arn = "<output-from-above>"

# Re-apply
terraform apply
```

### Useful Debugging Commands

```bash
# View cluster logs
aws eks describe-cluster --name spring-petclinic-eks

# Check node group status
aws eks describe-nodegroup --cluster-name spring-petclinic-eks \
  --nodegroup-name petclinic-worker-primary

# View kubectl context
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# View all resources
kubectl get all -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -A
```

## 💰 Cost Estimation

### Monthly Cost Breakdown

| Component | Specification | Monthly Cost (est.) |
|-----------|--------------|-------------------|
| **EKS Control Plane** | Managed by AWS | $73 |
| **Primary Node Group** | 1x t3.large | $61 |
| **Secondary Node Group** | 2x t3.xlarge | $244 |
| **EBS Volumes** | 150 GB gp3 storage | $15 |
| **Data Transfer** | Minimal inter-AZ | $10 |
| **Load Balancer** | Network LB (optional) | $16 |
| **CloudWatch Logs** | Basic logging | $5 |
| **Total** | | **~$424/month** |

### Cost Optimization Tips

1. **Use Spot Instances** (50-70% savings)
   ```hcl
   capacity_type = "SPOT"
   ```

2. **Enable Cluster Autoscaler**
   - Scales down during low usage
   - Can save 30-40% during off-hours

3. **Use Smaller Instance Types**
   ```hcl
   instance_types = ["t3.medium"]  # ~$30/month per node
   ```

4. **Schedule Non-Prod Shutdowns**
   - Stop cluster nights/weekends
   - Use Lambda or scheduled scaling

5. **Use Reserved Instances** (for production)
   - 1-year commitment: 30% savings
   - 3-year commitment: 60% savings

### Cost Calculator

AWS Pricing Calculator: https://calculator.aws/

## 📚 Additional Resources

### Documentation Files

| File | Description |
|------|-------------|
| [EKS_MIGRATION_GUIDE.md](EKS_MIGRATION_GUIDE.md) | Step-by-step migration from self-managed K8s |
| [EKS_COMMAND_REFERENCE.md](EKS_COMMAND_REFERENCE.md) | Common kubectl and eksctl commands |
| [EKS_QUICK_REFERENCE.md](EKS_QUICK_REFERENCE.md) | Quick command cheatsheet |
| [eks-health-check.sh](eks-health-check.sh) | Comprehensive cluster health check script |
| [check-eks-network.sh](check-eks-network.sh) | Network connectivity verification |

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/fix-eks-cluster.sh` | Diagnose and fix EKS connectivity issues |
| `EKS/eks-health-check.sh` | Complete cluster health verification |

### External Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [eksctl Documentation](https://eksctl.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Spring Petclinic on Kubernetes](https://github.com/spring-petclinic/spring-petclinic-microservices)

## 🤝 Support

### Getting Help

1. **Check existing documentation** in the `EKS/` directory
2. **Run health check** script to diagnose issues
3. **View AWS CloudWatch** logs for cluster events
4. **Check Kubernetes events**: `kubectl get events`

### Common Next Steps

After successful deployment:

1. **Set up CI/CD** - Configure Jenkins/GitHub Actions for automated deployments
2. **Enable Monitoring** - Install Prometheus/Grafana dashboards
3. **Configure Backups** - Set up Velero for cluster backups
4. **Implement Security** - Network policies, pod security policies
5. **Cost Optimization** - Enable autoscaling, use spot instances

---

**🎉 You're all set!** Your Spring Petclinic Microservices application is now running on a production-ready EKS cluster.

## 📚 Additional Resources

### Documentation Files

| File | Description |
|------|-------------|
| [EKS_MIGRATION_GUIDE.md](EKS_MIGRATION_GUIDE.md) | Step-by-step migration from self-managed K8s |
| [EKS_COMMAND_REFERENCE.md](EKS_COMMAND_REFERENCE.md) | Common kubectl and eksctl commands |
| [EKS_QUICK_REFERENCE.md](EKS_QUICK_REFERENCE.md) | Quick command cheatsheet |
| [eks-health-check.sh](eks-health-check.sh) | Comprehensive cluster health check script |
| [check-eks-network.sh](check-eks-network.sh) | Network connectivity verification |

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/fix-eks-cluster.sh` | Diagnose and fix EKS connectivity issues |
| `EKS/eks-health-check.sh` | Complete cluster health verification |

### External Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [eksctl Documentation](https://eksctl.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Spring Petclinic on Kubernetes](https://github.com/spring-petclinic/spring-petclinic-microservices)


## Manually Fixing Config Server

# 1. Check current pod status
bash ```
kubectl get pods -l app=config-server
```
# 2. Delete all config-server pods to force fresh start
bash ```
kubectl delete pods -l app=config-server
```
# 3. Scale down to 1 replica temporarily
bash ```
kubectl scale deployment config-server --replicas=1
```

# 4. Watch the pod startup
bash ```
kubectl get pods -l app=config-server -w
```

# 5. Once running, check logs
bash ```  
kubectl logs -l app=config-server --tail=50
```

# 6. If still failing, check events
bash ```
kubectl describe pod -l app=config-server | grep -A 10 Events
```

# 7. If logs show git errors, verify the deployment has correct URI
bash ```
kubectl get deployment config-server -o yaml | grep -A 5 "env:"
```

# 8. Git URI should be correct
bash ```
kubectl set env deployment/config-server SPRING_CLOUD_CONFIG_SERVER_GIT_URI=https://github.com/Ganil151/spring-petclinic-microservices-config \
SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL=main
```

# 9. Restart the deployment
bash ```
kubectl rollout restart deployment config-server
```

# 10. If pods are still stuck
```bash
# Check node resources
kubectl top nodes

# Scale to 1 replica
kubectl scale deployment config-server --replicas=1
``` 

# 11. Nuclear option - delete and recreate
```bash
kubectl delete deployment config-server
kubectl apply -f kubernetes/deployments/deployment.yaml
```


