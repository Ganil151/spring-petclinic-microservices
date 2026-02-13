module "vpc" {
  source = "../../modules/networking/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.data_availability_zone
}

module "sg" {
  source = "../../modules/networking/sg"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ingress_ports       = var.ingress_ports
}

module "jenkins_master" {
  source = "../../modules/compute/ec2"

  project_name         = var.project_name
  environment          = var.environment
  instance_name        = var.jenkins_instance_name
  role                 = "master"
  ami_id               = var.ami
  instance_type        = var.jenkins_instance_type
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.sg.ec2_sg_id]
  key_name             = var.key_name
  associate_public_ip  = var.associate_public_ip
  user_data            = file("${path.module}/../../scripts/jenkins_.sh")
  iam_instance_profile = var.iam_instance_profile
  root_volume_size     = var.jenkins_root_volume_size
  extra_volume_size    = var.jenkins_extra_volume_size
}


module "worker_node" {
  source = "../../modules/compute/ec2"

  project_name         = var.project_name
  environment          = var.environment
  instance_name        = var.worker_instance_name
  role                 = "worker"
  ami_id               = var.ami
  instance_type        = var.worker_instance_type
  subnet_id            = module.vpc.public_subnet_ids[0]
  security_group_ids   = [module.sg.ec2_sg_id]
  key_name             = var.key_name
  associate_public_ip  = var.associate_public_ip
  user_data            = file("${path.module}/../../scripts/worker_install.sh")
  iam_instance_profile = var.iam_instance_profile
  root_volume_size     = var.worker_root_volume_size
  extra_volume_size    = var.worker_extra_volume_size
}

module "sonarqube_server" {
  source = "../../modules/compute/ec2"

  project_name        = var.project_name
  environment         = var.environment
  instance_name       = var.sonarqube_instance_name
  role                = "sonarqube"
  ami_id              = var.ami
  instance_type       = var.sonarqube_instance_type
  subnet_id           = module.vpc.private_subnet_ids[0]
  security_group_ids  = [module.sg.ec2_sg_id]
  key_name            = var.key_name
  associate_public_ip = var.associate_public_ip
  user_data           = var.user_data
  root_volume_size    = var.sonarqube_root_volume_size
  extra_volume_size   = var.sonarqube_extra_volume_size
}