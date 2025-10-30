module "vpc" {
  source                  = "../MODULES/Vpc"
  vpc_id                  = var.vpc_id
  vpc_cidr_block          = var.vpc_cidr_block
  project_name_1          = var.project_name_1
  subnet_cidr_block       = var.subnet_cidr_block
  enable_dns_support      = var.enable_dns_support
  enable_dns_hostnames    = var.enable_dns_hostnames
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  map_public_ip_on_launch = var.map_public_ip_on_launch
}

# Security Group
module "master_sg" {
  source         = "../MODULES/SG"
  project_name_1 = var.project_name_1
  vpc_id         = module.vpc.vpc_id
  ingress_rules  = var.ingress_rules
  egress_rules   = var.egress_rules
  environment    = var.environment

}

# Keys
module "key" {
  source   = "../MODULES/Keys"
  key_name = var.key_name
}

# Master Instance
module "jenkins_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_1
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/jenkins.sh")
  user_data_replace_on_change = var.user_data_replace_on_change
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment

}

# Worker Instance
module "worker_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_2
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/docker.sh")
  user_data_replace_on_change = var.user_data_replace_on_change
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment

}







