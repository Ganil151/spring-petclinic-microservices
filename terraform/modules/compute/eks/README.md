# EKS Module

This module provisions a production-ready AWS EKS cluster with managed node groups, OIDC for IRSA, and standard addons.

## Features
- EKS Cluster (Control Plane) v1.31.
- Managed Node Groups (MNG) for worker nodes.
- IAM Roles for Service Accounts (IRSA) via OIDC Provider.
- Multi-AZ support (distributes nodes across provided subnets).
- Standard Addons: VPC CNI, CoreDNS, Kube-Proxy, and EBS CSI Driver.
- Private and Public endpoint access enabled.

## Usage

```hcl
module "eks" {
  source = "../../modules/compute/eks"

  project_name    = "petclinic"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  cluster_version = "1.31"
  
  node_group_instance_types = ["t3.medium"]
  node_group_desired_size   = 2
  node_group_max_size       = 3
  node_group_min_size       = 1
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for tagging | `string` | n/a | yes |
| environment | Environment name for tagging | `string` | n/a | yes |
| vpc_id | VPC ID for EKS cluster | `string` | n/a | yes |
| subnet_ids | List of subnet IDs | `list(string)` | n/a | yes |
| cluster_version | EKS version | `string` | `1.31` | no |
| node_group_instance_types | Instance types for nodes | `list(string)` | `["t3.medium"]` | no |
| node_group_desired_size | Desired nodes | `number` | `2` | no |
| node_group_max_size | Max nodes | `number` | `3` | no |
| node_group_min_size | Min nodes | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | EKS Cluster Name |
| cluster_endpoint | EKS API Server Endpoint |
| cluster_certificate_authority_data | CA Data for kubectl config |
| node_group_id | ID of the node group |
| node_role_arn | IAM Role ARN for nodes |
| oidc_provider_arn | ARN of the OIDC provider |
| oidc_provider_url | URL of the OIDC provider |
