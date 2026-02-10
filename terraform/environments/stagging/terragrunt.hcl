include "root" {
  path = find_in_parent_folders()
}

inputs = {
  environment          = "staging"
  vpc_cidr             = "10.2.0.0/16"
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
  db_name              = "petclinic"
  db_user              = "petclinic"
  db_password          = "petclinic_password_staging"
}
