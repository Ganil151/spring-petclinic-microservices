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
    key            = "${local.env}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

# Helper locals for environment-specific configuration
locals {
  # Extract environment from path (e.g., "live/dev/vpc" -> "dev")
  env = basename(path_relative_to_include())
  
  # Fixed random suffix for dev/staging (set once, never change)
  # Use different suffix for each environment to avoid state collisions
  random_suffix = local.env == "dev" ? "a7f3c2" : local.env == "staging" ? "b9d4e1" : "default"
}


