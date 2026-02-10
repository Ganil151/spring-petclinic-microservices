# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT ROOT CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = "petclinic-terraform-state-17a538b3"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "spring-petclinic"
      ManageBy    = "Terragrunt"
    }
  }
}
EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF
}

# The root variables are injected into every child's variables.tf
generate "root_variables" {
  path      = "root_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "environment" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "db_name" { type = string }
variable "db_user" { type = string }
variable "db_password" { type = string }
EOF
}

# Point to the shared stack module
terraform {
  source = "../../modules/stack"
}
