# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders()
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/networking/vpc"
}

# Load environment variables from the YAML
locals {
  env_vars = yamldecode(file(find_in_parent_folders("env.yaml")))
}

# Pass inputs to the Terraform module
inputs = {
  vpc_cidr     = local.env_vars.vpc_cidr
  environment  = local.env_vars.env
  project_name = "spring-petclinic"

  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
}
