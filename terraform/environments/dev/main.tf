module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.data_availability_zone
}

module "ec2" " {
  source = "../../modules/ec2"

  project_name = var.project_name
  environment  = var.environment
  instance_name  = var.instance_name
  ami_id         = var.ami_id
  instance_type  = var.instance_type
  vpc_id         = module.vpc.id
  subnet_id      = module.vpc.private_subnet_ids[0]
  key_name       = var.key_name
  associate_public_ip = var.associate_public_ip
  user_data      = var.user_data
  iam_instance_profile = var.iam_instance_profile
  root_volume_size = var.root_volume_size
  allowed_cidr_blocks = var.allowed_cidr_blocks
  extra_volume_size = var.extra_volume_size
} 