# AWS EKS Migration Guide
## Complete Step-by-Step Instructions

---

## 📋 Overview

This guide will help you migrate from self-managed Kubernetes to **AWS EKS (Elastic Kubernetes Service)**, a fully managed Kubernetes service that eliminates cluster management overhead.

### Why EKS?
- ✅ **Managed Control Plane**: AWS manages the master nodes
- ✅ **High Availability**: Multi-AZ control plane by default
- ✅ **Auto-scaling**: Easy node group scaling
- ✅ **AWS Integration**: Native integration with ALB, EBS, IAM
- ✅ **No Master Node Issues**: No more manual cluster maintenance

---

## 🎯 Prerequisites

Before starting, ensure you have:
- ✅ AWS CLI installed and configured
- ✅ AWS account with appropriate permissions
- ✅ Your current Kubernetes manifests (already in `kubernetes/deployments/`)
- ✅ Terraform state backed up

---

## 📦 Phase 1: Install Required Tools

### Step 1.1: Install AWS CLI (if not already installed)

**On Windows (PowerShell):**
```powershell
# Download and install AWS CLI
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

**Verify installation:**
```bash
aws --version
# Expected: aws-cli/2.x.x
```

### Step 1.2: Configure AWS CLI

```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format: json
```

### Step 1.3: Install eksctl (EKS CLI tool)

**On Windows (using Chocolatey):**
```powershell
choco install eksctl
```

**Or download directly:**
```powershell
# Download eksctl
curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Windows_amd64.zip"
# Extract and add to PATH
```

**Verify installation:**
```bash
eksctl version
# Expected: 0.x.x
```

### Step 1.4: Update kubectl

```bash
# Check current version
kubectl version --client

# Install latest (if needed)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/windows/amd64/kubectl.exe"
```

---

## 🗑️ Phase 2: Clean Up Self-Managed Kubernetes

### Step 2.1: Backup Current Configurations

```bash
# Save current pod list
kubectl get pods -A > backup-pods.txt

# Save current services
kubectl get svc -A > backup-services.txt

# Your manifests are already in kubernetes/deployments/ - no backup needed
```

### Step 2.2: Terminate K8s Instances via AWS Console

**Option A: Via AWS Console (Recommended)**
1. Go to AWS EC2 Console
2. Select instances:
   - `K8s-Master-Server`
   - `K8s-Worker-Server`
3. Actions → Instance State → Terminate

**Option B: Via Terraform**
```bash
cd terraform/app

# Comment out or remove K8s instances from main.tf
# Then apply:
terraform apply
```

### Step 2.3: Update Terraform Configuration

Edit `terraform/app/main.tf` - comment out or remove:
```hcl
# Comment out these modules:
# module "k8s_master_instance" { ... }
# module "K8s_worker_instance" { ... }
```

---

## 🚀 Phase 3: Create EKS Cluster

### Step 3.1: Create EKS Cluster Configuration

Create `eks-cluster-config.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: petclinic-eks-cluster
  region: us-east-1
  version: "1.28"

# VPC Configuration (use your existing VPC)
vpc:
  id: "vpc-xxxxx"  # Your VPC ID from terraform output
  subnets:
    public:
      us-east-1a: { id: subnet-xxxxx }  # Your public subnet IDs
      us-east-1b: { id: subnet-xxxxx }

# Managed Node Groups
managedNodeGroups:
  - name: petclinic-nodes
    instanceType: t3.large
    desiredCapacity: 2
    minSize: 1
    maxSize: 3
    volumeSize: 30
    ssh:
      allow: true
      publicKeyName: master_keys  # Your existing key pair
    labels:
      role: worker
    tags:
      Environment: dev
      Project: spring-petclinic

# Enable CloudWatch logging
cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]
```

### Step 3.2: Create the EKS Cluster

```bash
# Create cluster (takes 15-20 minutes)
eksctl create cluster -f eks-cluster-config.yaml

# Monitor progress
# You'll see output showing cluster creation progress
```

**Expected Output:**
```
[ℹ]  eksctl version 0.x.x
[ℹ]  using region us-east-1
[ℹ]  setting availability zones to [us-east-1a us-east-1b]
[ℹ]  creating EKS cluster "petclinic-eks-cluster"
...
[✔]  EKS cluster "petclinic-eks-cluster" in "us-east-1" region is ready
```

### Step 3.3: Verify Cluster Access

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks-cluster

# Verify connection
kubectl get nodes

# Expected output:
# NAME                             STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xxx.ec2.internal      Ready    <none>   5m    v1.28.x
# ip-10-0-2-xxx.ec2.internal      Ready    <none>   5m    v1.28.x
```

### Step 3.4: Verify Cluster Components

```bash
# Check system pods
kubectl get pods -n kube-system

# All pods should be Running
# You should see:
# - coredns
# - aws-node (VPC CNI)
# - kube-proxy
```

---

## 📦 Phase 4: Deploy Applications to EKS

### Step 4.1: Create Namespace (Optional)

```bash
# Create a namespace for your app
kubectl create namespace petclinic

# Or use default namespace (current setup)
```

### Step 4.2: Deploy Secrets (if needed)

```bash
# If you have secrets for genai-service
kubectl apply -f kubernetes/deployments/secrets.yaml
```

### Step 4.3: Deploy All Services

```bash
cd spring-petclinic-microservices

# Deploy all services at once
kubectl apply -f kubernetes/deployments/

# Watch deployment progress
kubectl get pods -w
```

### Step 4.4: Verify Deployments

```bash
# Check all pods
kubectl get pods

# Check services
kubectl get svc

# Check deployments
kubectl get deployments
```

**Expected Output (after 2-3 minutes):**
```
NAME                    READY   STATUS    RESTARTS   AGE
admin-server-xxx        1/1     Running   0          2m
api-gateway-xxx         1/1     Running   0          2m
config-server-xxx       1/1     Running   0          2m
customers-service-xxx   1/1     Running   0          2m
discovery-server-xxx    1/1     Running   0          2m
...
```

### Step 4.5: Troubleshoot if Pods Don't Start

```bash
# Check pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>

# Check resource usage
kubectl top nodes
kubectl top pods
```

---

## 🔗 Phase 5: Expose Services (Load Balancer)

### Step 5.1: Install AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Install controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 5.2: Expose API Gateway with LoadBalancer

Update `kubernetes/deployments/api-gateway.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
spec:
  type: LoadBalancer  # Change from ClusterIP
  selector:
    app: api-gateway
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

Apply:
```bash
kubectl apply -f kubernetes/deployments/api-gateway.yaml

# Get the load balancer URL
kubectl get svc api-gateway
# Note the EXTERNAL-IP (AWS Load Balancer DNS)
```

---

## 🔐 Phase 6: Configure Webhook Server for EKS

### Step 6.1: Create RBAC for Webhook

```bash
# Apply webhook RBAC
kubectl apply -f kubernetes/webhook-rbac.yaml
```

### Step 6.2: Generate Kubeconfig for Webhook Server

```bash
# Run on your local machine
cd scripts
./generate-kubeconfig.sh

# Copy to webhook server
scp -i your-key.pem webhook-kubeconfig ec2-user@<WEBHOOK-IP>:/tmp/
```

### Step 6.3: Configure Webhook Server

SSH into webhook server:
```bash
ssh -i your-key.pem ec2-user@<WEBHOOK-IP>

# Install kubeconfig
sudo mv /tmp/webhook-kubeconfig /root/.kube/config
sudo chmod 600 /root/.kube/config

# Test connection
sudo kubectl get nodes

# Start webhook service
sudo systemctl start webhook-receiver
sudo systemctl status webhook-receiver
```

---

## ✅ Phase 7: Verification & Testing

### Step 7.1: Verify All Services

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get svc

# Test config server
kubectl exec -it <any-pod> -- curl http://config-server:8888/actuator/health

# Test discovery server
kubectl exec -it <any-pod> -- curl http://discovery-server:8761/actuator/health
```

### Step 7.2: Access Application

```bash
# Get API Gateway URL
kubectl get svc api-gateway

# Access in browser:
http://<LOAD-BALANCER-DNS>
```

### Step 7.3: Test Webhook

```bash
# From local machine
./scripts/test-webhook.sh <WEBHOOK-SERVER-IP>
```

---

## 🎛️ Phase 8: Optional Enhancements

### Enable Cluster Autoscaler

```bash
eksctl create iamserviceaccount \
  --cluster=petclinic-eks-cluster \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::aws:policy/AutoScalingFullAccess \
  --approve
```

### Enable Container Insights (Monitoring)

```bash
aws eks update-cluster-config \
  --region us-east-1 \
  --name petclinic-eks-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl top nodes
```

---

## 🔧 Troubleshooting

### Issue: Pods Stuck in Pending

```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name>

# Solution: Scale node group
eksctl scale nodegroup --cluster=petclinic-eks-cluster --name=petclinic-nodes --nodes=3
```

### Issue: Can't Access Load Balancer

```bash
# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=*petclinic*"

# Ensure port 80/443 is open
```

### Issue: Webhook Can't Connect to EKS

```bash
# Ensure webhook server security group allows outbound to EKS API
# EKS API endpoint is in the VPC, so ensure routing is correct
```

---

## 💰 Cost Optimization

### EKS Pricing
- **Control Plane**: $0.10/hour (~$73/month)
- **Worker Nodes**: EC2 pricing (t3.large ~$0.0832/hour each)
- **Total Estimate**: ~$200/month for 2 t3.large nodes

### Cost Saving Tips
1. Use Spot Instances for worker nodes (50-70% savings)
2. Enable cluster autoscaler to scale down during low usage
3. Use smaller instance types (t3.medium) if sufficient

---

## 📚 Quick Reference Commands

```bash
# Cluster Management
eksctl get cluster
eksctl delete cluster --name petclinic-eks-cluster

# Node Management
eksctl get nodegroup --cluster petclinic-eks-cluster
eksctl scale nodegroup --cluster=petclinic-eks-cluster --name=petclinic-nodes --nodes=3

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks-cluster

# View cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Logs
kubectl logs -f <pod-name>
kubectl logs <pod-name> --previous  # Previous container logs
```

---

## 🎉 Summary

You've successfully migrated to AWS EKS! Your infrastructure is now:
- ✅ Fully managed Kubernetes control plane
- ✅ Auto-scaling worker nodes
- ✅ Integrated with AWS services
- ✅ High availability by default
- ✅ No more manual cluster maintenance

**Next Steps:**
1. Configure CI/CD pipeline to deploy to EKS
2. Set up monitoring and alerting
3. Configure backup and disaster recovery
4. Implement cost optimization strategies

---

**Need Help?**
- AWS EKS Documentation: https://docs.aws.amazon.com/eks/
- eksctl Documentation: https://eksctl.io/
- Kubernetes Documentation: https://kubernetes.io/docs/
