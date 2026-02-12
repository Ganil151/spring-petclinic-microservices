# Production Environment Infrastructure
# This file composes the infrastructure modules for production

module "vpc" {
  source = "../../modules/networking/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.data_availability_zone
}

module "sg" {
  source = "../../modules/networking/sg"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
}

# Production should include all necessary modules:
# - EKS cluster with proper node groups
# - Multi-AZ RDS with read replicas
# - EC2 instances with proper sizing
# - ALB with SSL/TLS
# - ECR for container images
# - WAF for additional security
# - CloudWatch monitoring and alerting
