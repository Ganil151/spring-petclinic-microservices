module "networking" {
  source = "../networking"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment
}

module "eks" {
  source = "../eks"

  cluster_name       = "${var.project_name}-${var.environment}-cluster"
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  environment        = var.environment
}

module "rds" {
  source = "../rds"

  db_name              = var.db_name
  db_user              = var.db_user
  db_password          = var.db_password
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  environment          = var.environment
  project_name         = var.project_name
}

module "bastion" {
  source = "../ec2"

  instance_name    = "${var.project_name}-${var.environment}-bastion"
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]
  environment      = var.environment
}
