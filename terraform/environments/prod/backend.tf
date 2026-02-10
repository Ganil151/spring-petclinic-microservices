# S3 Backend configuration for remote state management
# terraform {
#   backend "s3" {
#     bucket         = "petclinic-terraform-state-PLACEHOLDER"
#     key            = "tfstate/prod/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "petclinic-terraform-locks"
#     encrypt        = true
#   }
# }
