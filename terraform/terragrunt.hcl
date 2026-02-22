# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project = "spring-petclinic"
      Environment = "${path_relative_to_include()}"
      ManageBy = "Gsmash-DevTeam"
      Owner = "gsmash"
    }
  }
}
EOF
}

# Also generate a versions file to pin the AWS provider version
generate "version" {
  path      = "versions"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF
}

# Configure Terragrunt to automatically store state in S3
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    # Dev/Staging: Random suffix for privacy and simplicity
    # Production: Account ID for audit trail and multi-account support
    bucket         = local.env == "prod" ? "petclinic-state-${get_aws_account_id()}" : "petclinic-state-${local.env}-${local.random_suffix}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

# Helper locals for environment-specific configuration
locals {
  env = path_relative_to_include()
  
  # Generate a consistent random suffix for dev/staging
  # Replace with your own random 6-character string: e.g., "a7f3c2", "x9k2m4", etc.
  # This should be set once and never changed
  random_suffix = "a7f3c2"
}


