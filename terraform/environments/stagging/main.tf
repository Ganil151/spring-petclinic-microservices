module "networking" {
  source = "../../modules/networking"

  vpc_cidr    = var.spms_vpc_cidr
  subnet_cidr = var.spms_subnet_cidr
  environment = var.Environment
}
