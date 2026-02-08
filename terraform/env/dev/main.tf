module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr = var.vpc_cidr  
  availability_zones = var.availability_zones
  public_subnets_cidr = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr

}