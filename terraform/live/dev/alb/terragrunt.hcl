# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders()
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/networking/alb"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.public_subnets
  environment = "dev"
  project_name = "spring-petclinic"
  alb_name   = "petclinic-dev-alb"
  internal   = false
  target_port = 8080
  health_check_path = "/actuator/health"

  # ALB will create its own security group
  enable_security_group = true
  security_group_id     = null

  # Public access for ALB ports
  allowed_cidr_blocks = ["0.0.0.0/0"]

  # SSH access - restrict to your IP or bastion
  ssh_cidr_blocks = []

  # Create key pair for SSH access
  create_key_pair   = true
  key_pair_name     = "spms-dev"
  key_pair_filename = "${path_relative_to_include()}/spms-dev.pem"
}
