# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/compute/k8s-node"
}

# Pull data from the VPC module deployed in the same dev
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000"
    private_subnets = ["subnet-00000001", "subnet-00000002"]
  }
}

# Load environment variables from the YAML
locals {
  env_vars = yamldecode(file(find_in_parent_folders("env.yaml")))
}

# Pass inputs to the Terraform module
inputs = {
  subnet_ids    = dependency.vpc.outputs.private_subnets
  vpc_id        = dependency.vpc.outputs.vpc_id
  instance_type = local.env_vars.k8s_cluster.worker_node_type
  node_count    = local.env_vars.k8s_cluster.min_size
  project_name  = "spring-petclinic"
}