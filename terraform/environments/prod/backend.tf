# S3 Backend configuration for remote state management
# terraform {
#   backend "s3" {
#     bucket         = var.bucket_name
#     key            = "tfstate/prod/terraform.tfstate"
#     region         = var.aws_region
#     dynamodb_table = var.dynamodb_table
#     encrypt        = true
#   }
# }
