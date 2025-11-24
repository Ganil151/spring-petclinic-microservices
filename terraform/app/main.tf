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
  user_data                   = file("${path.module}/scripts/master.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.jenkins_root_volume_size
  root_volume_type            = var.root_volume_type
}


# Worker Instance
module "worker_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_2
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/worker.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.worker_root_volume_size
  root_volume_type            = var.root_volume_type
}

# Monitoring Instance
module "monitor_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_3
  instance_type               = "t2.small"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/monitoring.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.monitor_root_volume_size
  root_volume_type            = var.root_volume_type
}

# MySQL Instance
module "mysql_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_4
  instance_type               = "t2.small"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/mysql.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.mysql_root_volume_size
  root_volume_type            = var.root_volume_type
}

# K8s Master
module "k8s_master_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_5
  instance_type               = "t3.large"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/k8s_master.sh")
  user_data_replace_on_change = var.user_data_replace_on_change
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.k8s_master_root_volume_size
  root_volume_type            = var.root_volume_type
}

# K8s Worker
module "K8s_worker_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_6
  instance_type               = "t3.xlarge"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/k8s_worker.sh")
  user_data_replace_on_change = var.user_data_replace_on_change
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.k8s_worker_root_volume_size
  root_volume_type            = var.root_volume_type
}

# Webhook Receiver
module "webhook_receiver_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_7
  instance_type               = var.instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/webhook_receiver.sh")
  user_data_replace_on_change = false
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.webhook_root_volume_size
  root_volume_type            = var.root_volume_type
}









