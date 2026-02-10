module "stack" {
  source = "../../modules/stack"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  db_name              = var.db_name
  db_user              = var.db_user
  db_password          = var.db_password
}

output "vpc_id" {
  value = module.stack.vpc_id
}

output "eks_cluster_name" {
  value = module.stack.eks_cluster_name
}

output "rds_endpoint" {
  value = module.stack.rds_endpoint
}
