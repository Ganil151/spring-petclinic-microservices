# S3 Backend configuration for remote state management
# To enable this, replace the bucket name with your actual S3 bucket name
# and run 'terraform init' to migrate your local state.

terraform {
#   backend "s3" {
#     bucket         = var.bucket_name
#     key            = "tfstate/dev/terraform.tfstate"
#     region         = var.aws_region
#     dynamodb_table = var.dynamodb_table
#     encrypt        = true
#   }
# }
