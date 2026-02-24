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

# Get current machine's public IP for SSH access
locals {
  # Fetch public IP of machine running Terraform
  my_ip = chomp("${try(data.http.myip.response_body, "")}")
}

# Fetch public IP for SSH access (temporary for dev)
data "http" "myip" {
  url = "https://ifconfig.me/ip"
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id       = try(dependency.vpc.outputs.vpc_id, "vpc-mock")
  vpc_cidr     = try(dependency.vpc.outputs.vpc_cidr, "10.0.0.0/16")
  environment  = "dev"
  project_name = "spring-petclinic"

  # Public access (restricted in prod)
  # For dev: Allow SSH from bastion's public IP and current machine
  public_cidr_blocks = ["0.0.0.0/0"] # TODO: Restrict to specific IPs in production
}
