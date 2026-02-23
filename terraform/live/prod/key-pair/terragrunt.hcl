# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/security/key-pair"
}

# Pass inputs to the Terraform module
inputs = {
  key_pair_name = "spms-dev"
  environment   = "dev"
  project_name  = "spring-petclinic"

  # Key algorithm: RSA (default) or ED25519
  # RSA 4096: Maximum compatibility, widely supported
  # ED25519: Faster, smaller keys, modern SSH
  key_algorithm = "RSA"

  # RSA bits (only used if key_algorithm = "RSA")
  rsa_bits = 4096

  public_key           = null # Generate new key pair
  private_key_filename = "${get_terragrunt_dir()}/spms-dev.pem"

  # Store in SSM Parameter Store for secure access
  store_in_ssm       = true
  ssm_parameter_name = "/spring-petclinic/dev/key-pair/spms-dev"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "SSH Access"
  }
}
