# Backend configuration for prod environment
terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-17a538b3"
    key            = "tfstate/prod/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
