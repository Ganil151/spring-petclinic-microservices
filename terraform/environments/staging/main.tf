# ─────────────────────────────────────────────────────────────────────────────
# Spring PetClinic Microservices - Terraform Configuration (Staging)
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# VPC (Virtual Private Cloud)
# ─────────────────────────────────────────────────────────────────────────────
# Creates a VPC with public and private subnets across multiple AZs.

module "vpc" {
  source = "../../modules/networking/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.data_availability_zone
}

# ─────────────────────────────────────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────────────────────────────────────
# Creates security groups controlling inbound/outbound traffic for the VPC.

module "sg" {
  source = "../../modules/networking/sg"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ingress_rules       = var.ingress_rules
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM (Identity and Access Management)
# ─────────────────────────────────────────────────────────────────────────────
# Creates the EC2 IAM role with AmazonEC2ContainerRegistryPowerUser attached,
# allowing EC2 instances (Jenkins) to authenticate and push/pull ECR images.

module "iam" {
  source = "../../global/iam"

  project_name = var.project_name
  environment  = var.environment
}

# ─────────────────────────────────────────────────────────────────────────────
# ECR (Elastic Container Registry)
# ─────────────────────────────────────────────────────────────────────────────
# Provisions private ECR repositories for all Spring PetClinic microservices.
# Staging uses IMMUTABLE tags to guarantee reproducible deployments — once an
# image tag is pushed it cannot be overwritten (unlike dev where MUTABLE is OK).

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  # Full list of microservice repositories for the Spring PetClinic project
  repository_names = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "admin-server",
    "genai-service"
  ]

  # IMMUTABLE prevents tag overwriting in staging — ensures reproducible deploys
  image_tag_mutability = "IMMUTABLE"

  # Enable CVE scanning on every push (SRE security standard)
  scan_on_push = true

  # IAM role must exist before ECR repos are created so Jenkins can push images
  depends_on = [module.iam]
}

# Add additional modules as needed:
# - EKS cluster
# - RDS database
# - EC2 instances (Jenkins, SonarQube)
# - ALB
# - WAF
