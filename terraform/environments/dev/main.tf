module "networking" {
  source = "../../modules/networking"

  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

module "eks" {
  source = "../../modules/eks"

  environment        = var.environment
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "rds" {
  source = "../../modules/rds"

  environment        = var.environment
  db_name            = var.db_name
  db_username        = var.db_username
  db_instance_class  = var.db_instance_class
  allocated_storage  = var.allocated_storage
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  eks_security_group_id = module.eks.cluster_security_group_id
}

module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment
  repositories = [
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "genai-service",
    "config-server",
    "discovery-server"
  ]
}

module "secrets" {
  source = "../../modules/secrets"

  environment   = var.environment
  db_username   = var.db_username
  db_password   = var.db_password
  db_endpoint   = module.rds.db_endpoint
  db_name       = var.db_name
  openai_api_key = var.openai_api_key
}

module "alb" {
  source = "../../modules/alb"

  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  certificate_arn    = var.certificate_arn
}

module "monitoring" {
  source = "../../modules/monitoring"

  environment  = var.environment
  cluster_name = module.eks.cluster_name
  db_instance_id = module.rds.db_instance_id
  sns_email    = var.sns_email
}
