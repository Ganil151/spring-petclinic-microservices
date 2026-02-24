# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/security/iam"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000"
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["subnet-00000001", "subnet-00000002"]
    public_subnets  = ["subnet-10000001", "subnet-10000002"]
  }
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id       = try(dependency.vpc.outputs.vpc_id, "vpc-mock")
  vpc_cidr     = try(dependency.vpc.outputs.vpc_cidr, "10.0.0.0/16")
  environment  = "dev"
  project_name = "spring-petclinic"

  # Public access (restricted in prod)
  public_cidr_blocks = ["0.0.0.0/0"]
}
