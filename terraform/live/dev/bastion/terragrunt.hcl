# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders()
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/security/iam"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id      = dependency.vpc.outputs.vpc_id
  environment = "dev"
  project_name = "spring-petclinic"

  # Admin access from VPC and bastion
  admin_cidr_blocks = ["10.0.0.0/8"]

  # Public access for API Gateway
  public_cidr_blocks = ["0.0.0.0/0"]

  # Database access from private subnets only
  db_cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24"]

  # Enable monitoring components
  enable_grafana    = true
  enable_prometheus = true
  enable_zipkin     = true

  # These will be populated after bastion is deployed
  bastion_security_group_id = null
  alb_security_group_id     = null
}
