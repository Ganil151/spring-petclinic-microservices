# EKS Integration Guide

## Overview

The EKS module is now fully integrated into your Terraform infrastructure. You can deploy either:
- **Self-managed K8s** (current setup with EC2 instances)
- **AWS EKS** (managed Kubernetes service)
- **Both** (for migration/testing)

## Quick Start

### Deploy EKS Cluster

```bash
cd terraform/app

# 1. Enable EKS in terraform.tfvars
# Change: enable_eks = false
# To:     enable_eks = true

# 2. Initialize and apply
terraform init
terraform apply

# 3. Configure kubectl (after ~20 min)
aws eks update-kubeconfig --region us-east-1 --name spring-petclinic-eks

# 4. Verify
kubectl get nodes

# 5. Deploy Spring Petclinic
kubectl apply -f ../../kubernetes/deployments/
```

## Configuration

### terraform/app/terraform.tfvars

```hcl
# EKS Configuration
enable_eks            = true              # Set to true to deploy EKS
eks_cluster_name      = "spring-petclinic-eks"
eks_cluster_version   = "1.28"
eks_node_group_name   = "petclinic-nodes"
eks_desired_size      = 2                 # Number of worker nodes
eks_max_size          = 3                 # Max nodes for auto-scaling
eks_min_size          = 1                 # Min nodes for auto-scaling
eks_instance_types    = ["t3.xlarge"]     # Instance type for workers
eks_disk_size         = 50                # Disk size in GB
```

## Module Structure

```
terraform/
├── MODULES/
│   └── eks/
│       ├── main.tf       # EKS cluster and node group resources
│       ├── variables.tf  # Input variables
│       └── outputs.tf    # Cluster information outputs
└── app/
    ├── main.tf          # Includes EKS module (conditional)
    ├── variable.tf      # EKS variables added
    └── terraform.tfvars # EKS configuration values
```

## Features

### ✅ What's Included

- **EKS Cluster**: Managed Kubernetes control plane
- **Managed Node Group**: Auto-scaling worker nodes
- **IAM Roles**: Automatically configured for cluster and nodes
- **VPC Integration**: Uses existing VPC and subnets
- **Conditional Deployment**: Enable/disable with single variable
- **Outputs**: Cluster endpoint, kubectl config command

### 🔧 What's Configured

- **Cluster Version**: 1.28 (configurable)
- **Node Auto-scaling**: 1-3 nodes (configurable)
- **Instance Type**: t3.xlarge (configurable)
- **Disk Size**: 50GB per node (configurable)
- **Networking**: Public endpoint enabled
- **Logging**: All control plane logs enabled

## Deployment Scenarios

### Scenario 1: Fresh EKS Deployment

```bash
# Set enable_eks = true in terraform.tfvars
terraform apply

# Wait ~20 minutes
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name spring-petclinic-eks

# Deploy apps
kubectl apply -f ../../kubernetes/deployments/
```

### Scenario 2: Migrate from Self-Managed K8s

```bash
# 1. Keep current K8s running (enable_eks = false)

# 2. Enable EKS
# Set enable_eks = true in terraform.tfvars
terraform apply

# 3. Deploy to EKS
aws eks update-kubeconfig --region us-east-1 --name spring-petclinic-eks
kubectl apply -f ../../kubernetes/deployments/

# 4. Test EKS deployment

# 5. Switch traffic to EKS

# 6. Destroy old K8s (optional)
# Remove K8s instances from main.tf or set enable_k8s = false
```

### Scenario 3: Run Both (Testing)

```bash
# Both self-managed K8s and EKS can run simultaneously
# Useful for:
# - Testing EKS before migration
# - Comparing performance
# - Blue-green deployment
```

## Outputs

After deployment, Terraform provides:

```bash
terraform output eks_cluster_endpoint
# Output: https://xxxxx.gr7.us-east-1.eks.amazonaws.com

terraform output eks_configure_kubectl
# Output: aws eks update-kubeconfig --region us-east-1 --name spring-petclinic-eks

terraform output eks_node_group_status
# Output: ACTIVE
```

## Cost Comparison

### Self-Managed K8s (Current)
- Master (t3.large): $60.74/month
- Worker (t3.xlarge): $121.47/month
- **Total: $182.21/month**

### EKS
- Control Plane: $73.00/month
- 2× Workers (t3.xlarge): $242.94/month
- **Total: $315.94/month**

**Difference: +$133.73/month**

**Benefits for extra cost:**
- Managed control plane (no maintenance)
- Auto-scaling
- Automatic updates
- 99.95% SLA
- AWS integrations

## Troubleshooting

### Issue: Terraform can't find EKS module

```bash
cd terraform/app
terraform init
```

### Issue: kubectl can't connect

```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region us-east-1 --name spring-petclinic-eks

# Verify
kubectl get nodes
```

### Issue: Nodes not joining

```bash
# Check node group status
terraform output eks_node_group_status

# Check AWS console
# EKS → Clusters → spring-petclinic-eks → Compute
```

## Next Steps

1. **Enable EKS**: Set `enable_eks = true` in terraform.tfvars
2. **Deploy**: Run `terraform apply`
3. **Configure kubectl**: Use output command
4. **Deploy apps**: Apply Kubernetes manifests
5. **Test**: Verify all pods running
6. **Monitor**: Check CloudWatch metrics

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [EKS Workshop](https://www.eksworkshop.com/)
- [Terraform EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
