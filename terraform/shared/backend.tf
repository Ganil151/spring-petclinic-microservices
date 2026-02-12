# Shared backend configuration template
# This file should be symlinked or copied to each environment
# Only the 'key' value should be different per environment

terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-17a538b3"
    # key will be set per environment: tfstate/{environment}/terraform.tfstate
    region         = "us-east-1"
    dynamodb_table = "petclinic-terraform-locks-17a538b3"
    encrypt        = true
  }
}
