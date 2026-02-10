# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the root configuration for all environments.
# ---------------------------------------------------------------------------------------------------------------------

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "petclinic-terraform-state-17a538b3"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    # dynamodb_table = "terraform-lock-table" # Enable this if you have a DynamoDB table for locking
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.Environment
      Project     = "spring-petclinic"
      ManageBy    = "Terraform"
    }
  }
}
EOF
}

# Generate versions block
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF
}

# Generate common variables
generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into"
}

variable "Environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod, staging)"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform state"
  default     = "petclinic-terraform-state-17a538b3"
}

variable "spms_vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "spms_subnet_cidr" {
  type        = string
  description = "The CIDR block for the subnet"
}
EOF
}
