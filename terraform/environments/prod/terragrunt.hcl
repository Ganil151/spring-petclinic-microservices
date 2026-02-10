include "root" {
  path = find_in_parent_folders()
}

inputs = {
  aws_region               = "us-east-1"
  Environment              = "prod"
  spms_vpc_cidr            = "10.1.0.0/16"
  spms_public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  spms_private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
  availability_zones       = ["us-east-1a", "us-east-1b"]
}
