  # S3 Backend configuration for remote state management
# terraform {
#   backend "s3" {
#     bucket         = var.bucket_name
#     key            = "tfstate/staging/terraform.tfstate"
#     region         = var.aws_region
#     dynamodb_table = "petclinic-terraform-locks"
#     encrypt        = true
#   }
# }
