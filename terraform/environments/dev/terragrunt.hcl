include "root" {
  path = find_in_parent_folders()
}

inputs = {
  aws_region       = "us-east-1"
  Environment      = "dev"
  spms_vpc_cidr    = "10.0.0.0/16"
  spms_subnet_cidr = "10.0.1.0/24"
}
