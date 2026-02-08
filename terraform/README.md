# Spring PetClinic Microservices - Terraform Infrastructure

## Overview
This directory contains Terraform configurations for deploying Spring PetClinic Microservices to AWS.

## Structure
```
terraform/
├── environments/       # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/           # Reusable Terraform modules
│   ├── networking/    # VPC, subnets, NAT gateways
│   ├── eks/          # EKS cluster and node groups
│   ├── rds/          # MySQL database
│   ├── ecr/          # Container registry
│   ├── secrets/      # Secrets Manager
│   ├── alb/          # Application Load Balancer
│   └── monitoring/   # CloudWatch alarms
├── shared/           # Shared configurations
└── scripts/          # Helper scripts
```

## Prerequisites
- Terraform >= 1.6.0
- AWS CLI configured
- kubectl installed

## Quick Start

### 1. Initialize Environment
```bash
cd terraform
./scripts/init.sh dev
```

### 2. Configure Variables
Edit `environments/dev/terraform.tfvars` with your values.

### 3. Plan Deployment
```bash
./scripts/plan.sh dev
```

### 4. Apply Changes
```bash
./scripts/apply.sh dev
```

## Modules

### Networking
Creates VPC with public/private subnets across 3 AZs, NAT gateways, and route tables.

### EKS
Provisions managed Kubernetes cluster with auto-scaling node groups.

### RDS
Deploys Multi-AZ MySQL database for microservices.

### ECR
Creates container registries for all microservices.

### Secrets
Manages database credentials and API keys in AWS Secrets Manager.

### ALB
Configures Application Load Balancer with SSL/TLS.

### Monitoring
Sets up CloudWatch alarms and SNS notifications.

## Environments

### Dev
- Smaller instance sizes
- Single NAT gateway
- Reduced redundancy

### Staging
- Production-like configuration
- Multi-AZ deployment
- Full monitoring

### Prod
- High availability
- Multi-AZ everything
- Enhanced monitoring
- Automated backups

## Outputs
After deployment, retrieve outputs:
```bash
cd environments/dev
terraform output
```

## Cleanup
```bash
cd environments/dev
terraform destroy
```

## Best Practices
- Always run `plan` before `apply`
- Use workspaces for isolation
- Store state remotely in S3
- Enable state locking with DynamoDB
- Tag all resources
- Use modules for reusability
