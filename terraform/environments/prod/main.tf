module "networking" {
  source = "../../modules/networking"

  vpc_cidr             = var.spms_vpc_cidr
  public_subnet_cidrs  = var.spms_public_subnet_cidrs
  private_subnet_cidrs = var.spms_private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.Environment
}
