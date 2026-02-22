# Terraform & Terragrunt Deployment Guide

## 📁 Current Infrastructure Structure

```
terraform/
├── live/
│   ├── common.yaml
│   ├── dev/
│   │   ├── alb/              # Application Load Balancer + Security Groups
│   │   │   └── terragrunt.hcl
│   │   ├── bastion/          # Security Groups configuration
│   │   │   └── terragrunt.hcl
│   │   ├── env.yaml          # Environment-specific variables
│   │   ├── key-pair/         # EC2 SSH Key Pair (RSA 4096)
│   │   │   └── terragrunt.hcl
│   │   ├── k8s-cluster/      # Kubernetes EKS Cluster
│   │   │   └── terragrunt.hcl
│   │   ├── rds/              # RDS Database (Aurora/MySQL)
│   │   │   └── terragrunt.hcl
│   │   └── vpc/              # VPC, Subnets, IGW, NAT, Routes
│   │       └── terragrunt.hcl
│   ├── prod/
│   │   ├── alb/
│   │   │   └── terragrunt.hcl
│   │   ├── bastion/
│   │   │   └── terragrunt.hcl
│   │   ├── env.yaml
│   │   ├── key-pair/
│   │   │   └── terragrunt.hcl
│   │   ├── k8s-cluster/
│   │   │   └── terragrunt.hcl
│   │   ├── rds/
│   │   │   └── terragrunt.hcl
│   │   └── vpc/
│   │       └── terragrunt.hcl
│   └── staging/
│       ├── alb/
│       │   └── terragrunt.hcl
│       ├── bastion/
│       │   └── terragrunt.hcl
│       ├── env.yaml
│       ├── key-pair/
│       │   └── terragrunt.hcl
│       ├── k8s-cluster/
│       │   └── terragrunt.hcl
│       ├── rds/
│       │   └── terragrunt.hcl
│       └── vpc/
│           └── terragrunt.hcl
├── modules/
│   ├── compute/
│   │   ├── bastion/          # Bastion Host EC2
│   │   └── k8s-node/         # Kubernetes Worker Nodes
│   ├── database/
│   │   └── rds/              # RDS Database Module
│   ├── networking/
│   │   ├── alb/              # ALB + Security Group (all ports)
│   │   └── vpc/              # VPC with public/private subnets
│   └── security/
│       ├── iam/              # Security Groups for all services
│       └── key-pair/         # SSH Key Pair Module (RSA/ED25519)
├── backend.tf
├── providers.tf
├── terragrunt.hcl            # Root Terragrunt config (provider + backend)
└── versions.tf
```

---

## 🚀 Quick Start Deployment

### Prerequisites

```bash
# Verify tools are installed
terraform --version      # >= 1.10.0
terragrunt --version     # Latest
aws --version            # AWS CLI v2
```

### Step 1: Configure AWS Credentials

```bash
# Option A: AWS CLI Configuration
aws configure

# Option B: AWS SSO
aws sso login --profile <your-profile>
export AWS_PROFILE=<your-profile>

# Verify credentials
aws sts get-caller-identity
```

### Step 2: Create S3 Backend Buckets

**Dev/Staging** use random suffixes (privacy), **Production** uses account ID (audit trail).

```bash
#!/bin/bash
REGION="us-east-1"

# Dev bucket with random suffix
DEV_BUCKET="petclinic-state-dev-a7f3c2"  # Change 'a7f3c2' to your random string
aws s3 mb s3://${DEV_BUCKET} --region ${REGION}
aws s3api put-bucket-versioning --bucket ${DEV_BUCKET} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${DEV_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
aws s3api put-public-access-block --bucket ${DEV_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Staging bucket with random suffix
STAGING_BUCKET="petclinic-state-staging-b9d4e1"  # Change 'b9d4e1' to your random string
aws s3 mb s3://${STAGING_BUCKET} --region ${REGION}
aws s3api put-bucket-versioning --bucket ${STAGING_BUCKET} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${STAGING_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
aws s3api put-public-access-block --bucket ${STAGING_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Production bucket with account ID
PROD_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROD_BUCKET="petclinic-state-${PROD_ACCOUNT_ID}"
aws s3 mb s3://${PROD_BUCKET} --region ${REGION}
aws s3api put-bucket-versioning --bucket ${PROD_BUCKET} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${PROD_BUCKET} \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
aws s3api put-public-access-block --bucket ${PROD_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✓ Dev bucket: ${DEV_BUCKET}"
echo "✓ Staging bucket: ${STAGING_BUCKET}"
echo "✓ Prod bucket: ${PROD_BUCKET}"
```

### Step 3: Create DynamoDB Lock Table

```bash
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## 📋 Deployment Order

### Option A: Deploy All at Once (Recommended)

```bash
cd terraform/live/dev

# Initialize all modules (respects dependencies)
terragrunt run-all init

# Review the complete plan
terragrunt run-all plan

# Apply everything in correct order
terragrunt run-all apply -auto-approve
```

### Option B: Step-by-Step Deployment

```bash
# Navigate to dev environment
cd terraform/live/dev

# ─────────────────────────────────────────────────────────────
# 1. VPC (Network Foundation) - MUST BE FIRST
# ─────────────────────────────────────────────────────────────
cd vpc
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# ─────────────────────────────────────────────────────────────
# 2. Key Pair (SSH Access) - Independent, can run anytime
# ─────────────────────────────────────────────────────────────
cd ../key-pair
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# ─────────────────────────────────────────────────────────────
# 3. Security Groups (depends on VPC outputs)
# ─────────────────────────────────────────────────────────────
cd ../bastion
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# ─────────────────────────────────────────────────────────────
# 4. ALB (depends on VPC + Security Groups)
# ─────────────────────────────────────────────────────────────
cd ../alb
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# ─────────────────────────────────────────────────────────────
# 5. RDS Database (depends on VPC + Security Groups)
# ─────────────────────────────────────────────────────────────
cd ../rds
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# ─────────────────────────────────────────────────────────────
# 6. Kubernetes Cluster (depends on VPC + Security Groups)
# ─────────────────────────────────────────────────────────────
cd ../k8s-cluster
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Deployment Flow Diagram

```
┌──────────────┐
│  1. VPC      │ ──┬──────────────────────────────────────┐
│  (vpc/)      │   │                                      │
│  10.0.0.0/16 │   │                                      │
└──────────────┘   │                                      │
                   │                                      │
┌──────────────┐   │                                      │
│  2. Key Pair │   │                                      │
│  (key-pair/) │   │                                      │
│  spms-dev    │   │                                      │
└──────────────┘   │                                      │
                   ▼                                      │
┌──────────────┐   │                                      │
│  3. Security │◄──┘                                      │
│  Groups      │                                         │
│  (bastion/)  │                                         │
└──────────────┘                                         │
                   │                                      │
                   ▼                                      │
         ┌─────────┴─────────┐                           │
         │                   │                           │
         ▼                   ▼                           │
┌──────────────┐    ┌──────────────┐                    │
│  4. ALB      │    │  5. RDS      │                    │
│  (alb/)      │    │  (rds/)      │                    │
│  Port 80/443 │    │  Port 3306   │                    │
└──────────────┘    └──────────────┘                    │
                   │                                      │
                   ▼                                      │
         ┌──────────────────┐                            │
         │  6. K8s Cluster  │◄───────────────────────────┘
         │  (k8s-cluster/)  │
         │  EKS + Nodes     │
         └──────────────────┘
```

---

## 📋 Deployment Checklist

### Phase 1: Foundation (VPC + Key Pair)

```bash
# 1. Deploy VPC (Network Foundation)
cd terraform/live/dev/vpc
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# 2. Create SSH Key Pair
cd ../key-pair
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Verify key pair
aws ec2 describe-key-pairs --key-names spms-dev
ls -la spms-dev.pem  # Should have 0600 permissions
```

### Phase 2: Security Groups

```bash
# Deploy Security Groups (depends on VPC)
cd ../bastion
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Phase 3: Compute & Database

```bash
# Deploy RDS Database
cd ../rds
terragrunt init
terragrunt plan
terragrunt apply -auto-approve

# Deploy Kubernetes Cluster
cd ../k8s-cluster
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

### Phase 4: Load Balancer

```bash
# Deploy ALB (depends on VPC + Security Groups)
cd ../alb
terragrunt init
terragrunt plan
terragrunt apply -auto-approve
```

---

## 🔄 Deploy All at Once

```bash
# From the dev directory
cd terraform/live/dev

# Initialize all modules
terragrunt run-all init

# Review the complete plan
terragrunt run-all plan

# Apply everything (respecting dependencies)
terragrunt run-all apply -auto-approve
```

---

## 🔧 Configuration Reference

### Root Terragrunt Configuration

```hcl
# terraform/terragrunt.hcl

# Generate AWS provider
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "spring-petclinic"
      Environment = "${path_relative_to_include()}"
      ManageBy    = "Gsmash-DevTeam"
      Owner       = "gsmash"
    }
  }
}
EOF
}

# S3 Backend Configuration
remote_state {
  backend = "s3"
  generate = {
    path = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "petclinic-state-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
```

### VPC Module Inputs

```hcl
# terraform/live/dev/vpc/terragrunt.hcl
inputs = {
  vpc_cidr               = "10.0.0.0/16"
  environment            = "dev"
  project_name           = "spring-petclinic"
  availability_zones     = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs   = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway     = true
  single_nat_gateway     = true
}
```

### Key Pair Module Inputs

```hcl
# terraform/live/dev/key-pair/terragrunt.hcl
inputs = {
  key_pair_name        = "spms-dev"
  environment          = "dev"
  project_name         = "spring-petclinic"
  key_algorithm        = "RSA"       # or "ED25519"
  rsa_bits             = 4096
  private_key_filename = "${get_terragrunt_dir()}/spms-dev.pem"
  store_in_ssm         = true
  ssm_parameter_name   = "/spring-petclinic/dev/key-pair/spms-dev"
}
```

---

## 🔒 Security Groups & Ports

| Component | Port | Protocol | Access |
|-----------|------|----------|--------|
| **Public** | | | |
| API Gateway | 8080 | TCP | 0.0.0.0/0 |
| HTTP | 80 | TCP | 0.0.0.0/0 |
| HTTPS | 443 | TCP | 0.0.0.0/0 |
| **Internal (VPC)** | | | |
| Config Server | 8888 | TCP | VPC CIDR |
| Discovery Server | 8761 | TCP | VPC CIDR |
| Customers Service | 8081 | TCP | VPC CIDR |
| Visits Service | 8082 | TCP | VPC CIDR |
| Vets Service | 8083 | TCP | VPC CIDR |
| GenAI Service | 8084 | TCP | VPC CIDR |
| Admin Server | 9090 | TCP | VPC CIDR |
| Prometheus | 9090 | TCP | VPC CIDR |
| Grafana | 3000 | TCP | VPC CIDR |
| Zipkin | 9411 | TCP | VPC CIDR |
| MySQL/RDS | 3306 | TCP | VPC CIDR |
| PostgreSQL | 5432 | TCP | VPC CIDR |
| **Optional** | | | |
| SSH (Bastion) | 22 | TCP | Configurable |

---

## 🛠️ Common Operations

### View Current State

```bash
terragrunt state list
```

### Import Existing Resource

```bash
terragrunt import aws_vpc.main vpc-xxxxxxxxx
```

### Taint Resource (Force Re-create)

```bash
terragrunt taint aws_key_pair.main
terragrunt apply
```

### Destroy Resources

```bash
# Destroy single module
terragrunt destroy

# Destroy all (careful!)
terragrunt run-all destroy
```

### Output Values

```bash
terragrunt outputs                    # All outputs
terragrunt outputs vpc_id            # Specific output
terragrunt outputs -json             # JSON format
```

---

## 📊 Environment Comparison

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Availability Zones** | 2 | 2 | 3 |
| **NAT Gateways** | 1 (shared) | 1 (shared) | 3 (HA) |
| **K8s Worker Nodes** | 2 min | 2 min | 3 min |
| **RDS Multi-AZ** | No | Yes | Yes |
| **Deletion Protection** | Disabled | Disabled | Enabled |

---

## 🐛 Troubleshooting

### Backend Bucket Not Found

```bash
# Create bucket manually or run with bootstrap
terragrunt init --backend-bootstrap
```

### State Lock Error

```bash
# Force unlock (ensure no one else is running)
terragrunt force-unlock LOCK_ID
```

### Module Download Failed

```bash
# Clear Terragrunt cache
rm -rf .terragrunt-cache
terragrunt init
```

### AWS Permission Denied

```bash
# Check current credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:role/YOUR_ROLE \
  --action-names ec2:CreateVpc ec2:CreateSubnet
```

---

## 📈 Next Steps

After infrastructure deployment:

1. **Deploy Spring Petclinic Application**
   ```bash
   kubectl apply -f k8s/manifests/
   ```

2. **Configure ArgoCD for GitOps**
   ```bash
   argocd app create petclinic --repo ...
   ```

3. **Set Up Monitoring**
   ```bash
   helm install prometheus prometheus-community/kube-prometheus-stack
   ```

4. **Configure CI/CD Pipeline**
   - Import Jenkins job configurations
   - Set up webhooks in GitHub
   - Configure SonarQube quality gates

---

## 📞 Support

For issues or questions:
- Check Terraform logs: `TF_LOG=DEBUG terragrunt apply`
- Review Terragrunt docs: https://terragrunt.gruntwork.io
- AWS Provider docs: https://registry.terraform.io/providers/hashicorp/aws
