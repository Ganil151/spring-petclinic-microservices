# S3 Backend configuration for remote state management
# terraform {
#   backend "s3" {
#     bucket         = "petclinic-terraform-state-17a538b3"
#     key            = "tfstate/staging/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "petclinic-terraform-locks-17a538b3"
#     encrypt        = true
#   }
# }
