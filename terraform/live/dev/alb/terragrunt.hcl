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
  mock_outputs = {
    vpc_id         = "vpc-00000000"
    vpc_cidr       = "10.0.0.0/16"
    public_subnets = ["subnet-10000001", "subnet-10000002"]
  }
}

# Pull data from the security module (for existing security groups)
dependency "security" {
  config_path = "../security-groups"
  mock_outputs = {
    web_sg_id = "sg-10000004"
  }
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id            = try(dependency.vpc.outputs.vpc_id, "")
  vpc_cidr          = try(dependency.vpc.outputs.vpc_cidr, "")
  subnet_ids        = try(dependency.vpc.outputs.public_subnets, [])
  environment       = "dev"
  project_name      = "spring-petclinic"
  alb_name          = "petclinic-dev-alb"
  internal          = false
  target_port       = 8080
  health_check_path = "/actuator/health"

  # Use existing security group from security module
  enable_security_group = false
  security_group_id     = try(dependency.security.outputs.web_sg_id, "")

  # Public access for ALB ports
  allowed_cidr_blocks = ["0.0.0.0/0"]

  # SSH access - restrict to your IP or bastion
  ssh_cidr_blocks = []

  # Don't create key pair (already created in key-pair module)
  create_key_pair   = false
  key_pair_name     = ""
  key_pair_filename = ""
}
