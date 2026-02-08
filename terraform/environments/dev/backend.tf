terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "petclinic-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
