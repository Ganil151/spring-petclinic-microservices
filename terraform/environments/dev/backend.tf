terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "petclinic-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
