# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/networking/alb"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
}

# Pull data from the security module (for existing security groups)
dependency "security" {
  config_path = "../bastion"
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id            = dependency.vpc.outputs.vpc_id
  vpc_cidr          = dependency.vpc.outputs.vpc_cidr
  subnet_ids        = dependency.vpc.outputs.public_subnets
  environment       = "dev"
  project_name      = "spring-petclinic"
  alb_name          = "petclinic-dev-alb"
  internal          = false
  target_port       = 8080
  health_check_path = "/actuator/health"

  # Use existing security group from security module
  enable_security_group = false
  security_group_id     = dependency.security.outputs.alb_security_group_id

  # Public access for ALB ports
  allowed_cidr_blocks = ["0.0.0.0/0"]

  # SSH access - restrict to your IP or bastion
  ssh_cidr_blocks = []

  # Don't create key pair (already created in key-pair module)
  create_key_pair   = false
  key_pair_name     = ""
  key_pair_filename = ""
}
