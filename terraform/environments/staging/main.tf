# Staging Environment Infrastructure
# This file composes the infrastructure modules for staging

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
  ingress_rules       = var.ingress_rules
}

# Add additional modules as needed:
# - EKS cluster
# - RDS database
# - EC2 instances (Jenkins, SonarQube)
# - ALB
# - ECR
# - WAF
