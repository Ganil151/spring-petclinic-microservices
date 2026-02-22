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

# Pull data from the security module
dependency "security" {
  config_path = "../bastion"
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id            = dependency.vpc.outputs.vpc_id
  subnet_ids        = dependency.vpc.outputs.public_subnets
  security_group_id = dependency.security.outputs.alb_security_group_id
  environment       = "dev"
  project_name      = "spring-petclinic"
  alb_name          = "petclinic-dev-alb"
  internal          = false
  target_port       = 8080
  health_check_path = "/actuator/health"
}
