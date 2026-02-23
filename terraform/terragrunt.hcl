# =============================================================================
# Terragrunt Root Configuration for Spring Petclinic Microservices
# =============================================================================
# This is the root Terragrunt configuration that generates:
# - AWS Provider configuration
# - Terraform version constraints
# - S3 backend configuration for state management
#
# Usage:
#   cd terraform/live/dev/<module>
#   terragrunt init
#   terragrunt apply -auto-approve
#
# S3 Bucket Naming:
#   - Dev/Staging: petclinic-state-{env}-{random_suffix}
#   - Production:  petclinic-state-{account_id}
# =============================================================================

# =============================================================================
# AWS Provider Configuration
# =============================================================================
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "spring-petclinic"
      Environment = "${path_relative_to_include()}"
      ManageBy    = "Gsmash-DevTeam"
      Owner       = "gsmash"
    }
  }
}
EOF
}

# =============================================================================
# Terraform Version Constraints
# =============================================================================
generate "version" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }
}
EOF
}

# =============================================================================
# Remote State Configuration (S3 + DynamoDB)
# =============================================================================
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    # Dev/Staging: Random suffix for privacy
    # Production: Account ID for audit trail and compliance
    bucket         = local.env == "prod" ? "petclinic-state-${get_aws_account_id()}" : "petclinic-state-${local.env}-${local.random_suffix}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
    
    # Optional: Enable S3 bucket SSE-KMS for enhanced security
    # kms_key_id = "alias/petclinic-terraform-state"
    
    # Optional: Enable DynamoDB for state locking (already created)
    # dynamodb_table = "terraform-lock-table"
  }
  
  # Configure retry settings for S3 operations
  retry_max_attempts  = 3
  retry_sleep_interval = 10
}

# =============================================================================
# Local Configuration
# =============================================================================
locals {
  # Extract environment from path (e.g., "live/dev/vpc" -> "dev")
  env = element(split("/", path_relative_to_include()), 1)
  
  # Fixed random suffix for dev/staging (set once, never change)
  # Use different suffix for each environment to avoid state collisions
  random_suffix = local.env == "dev" ? "a7f3c2" : local.env == "staging" ? "b9d4e1" : "default"
  
  # Common tags to apply to all resources
  common_tags = {
    Project     = "spring-petclinic"
    Environment = local.env
    ManageBy    = "Gsmash-DevTeam"
    Owner       = "gsmash"
    Repository  = "https://github.com/spring-petclinic-microservices"
  }
}

# =============================================================================
# Download Settings
# =============================================================================
# Configure where Terragrunt downloads Terraform configurations
download_dir = ".terragrunt-cache"

# =============================================================================
# Retry Settings
# =============================================================================
# Configure retry behavior for failed API calls
retry_max_attempts  = 3
retry_sleep_interval = 10

# =============================================================================
# Dependency Optimization
# =============================================================================
# Skip downloading inputs from dependencies during certain operations
# skip_outputs_fetching = false

# =============================================================================
# IAC Validation
# =============================================================================
# Enable automatic validation before apply
# prevent_destroy = false

# =============================================================================
# Hooks (Optional - Uncomment to enable)
# =============================================================================
# before_hook "validate" {
#   commands     = ["apply", "plan"]
#   execute      = ["terraform", "validate"]
#   working_dir  = get_terragrunt_dir()
# }
#
# after_hook "cleanup" {
#   commands     = ["apply"]
#   execute      = ["echo", "Deployment completed!"]
#   working_dir  = get_terragrunt_dir()
# }

# =============================================================================
# Remote State Block for Cross-Module Dependencies
# =============================================================================
# Example: Access outputs from other modules
# dependency "vpc" {
#   config_path = "../vpc"
#   mock_outputs = {
#     vpc_id = "vpc-mock123"
#   }
# }
#
# dependency "security" {
#   config_path = "../bastion"
#   mock_outputs = {
#     security_group_id = "sg-mock123"
#   }
# }
