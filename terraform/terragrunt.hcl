# Generate an AWS provider block
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = "us-east-1"
}
EOF
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

# Global inputs (applies to all modules)
inputs = {
  project = "petclinic"
  owner = "gsmash-team"
}
