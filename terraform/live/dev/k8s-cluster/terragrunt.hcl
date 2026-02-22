# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders()
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/compute/k8s-node"
}

# Pull data from the VPC module deployed in the same dev
dependency "vpc" {
  config_path = "../vpc"
}

# Load environment var