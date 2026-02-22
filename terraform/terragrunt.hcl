# Generate an AWS provider block
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
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
  path = "versions"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> "
    }
  }
}
}

# Configure Terragrunt to automatically store state in S3
remote_state {
  backend = "s3"
  generate = { 
    path = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "petclinic-state-${get_aws_account_id()}"
    key = ${path_relative_to_include()}/terraform.tfstate
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-lock-table"
  }
}


