terraform {
  backend "s3" {
    bucket  = "petclinic-terraform-state-17a538b3"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
