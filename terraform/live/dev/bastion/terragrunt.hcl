# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders()
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/compute/bastion"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
}

# Pull data from the security module
dependency "security" {
  config_path = "../bastion"
}

# Pull data from the key-pair module
dependency "keypair" {
  config_path = "../key-pair"
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id             = dependency.vpc.outputs.vpc_id
  vpc_cidr           = dependency.vpc.outputs.vpc_cidr
  subnet_ids         = dependency.vpc.outputs.public_subnets
  security_group_ids = [
    dependency.security.outputs.bastion_security_group_id,
    dependency.security.outputs.k8s_nodes_security_group_id
  ]
  environment        = "dev"
  project_name       = "spring-petclinic"
  key_pair_name      = "spms-dev"

  # Instance Types
  bastion_instance_type    = "t3.micro"
  jenkins_instance_type    = "t3.medium"
  sonarqube_instance_type  = "t3.medium"
  worker_node_type         = "t3.large"
  worker_node_count        = 2

  # Storage
  root_volume_size    = 20
  enable_monitoring   = true

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
