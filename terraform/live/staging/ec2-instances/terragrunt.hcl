# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/compute/ec2-instances"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000"
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["subnet-00000001", "subnet-00000002"]
    public_subnets  = ["subnet-10000001", "subnet-10000002"]
  }
}

# Pull data from the security module
dependency "security" {
  config_path = "../bastion"
  mock_outputs = {
    mgmt_sg_id = "sg-10000001"
    app_sg_id  = "sg-10000002"
    data_sg_id = "sg-10000003"
    web_sg_id  = "sg-10000004"
  }
}

# Pull data from the key-pair module
dependency "keypair" {
  config_path = "../key-pair"
  mock_outputs = {
    key_name = "spms-mock-key"
  }
}

# 🧪 Industrial Rigor: Load environment configuration
locals {
  env_vars = yamldecode(file(find_in_parent_folders("env.yaml")))
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id     = dependency.vpc.outputs.vpc_id
  vpc_cidr   = dependency.vpc.outputs.vpc_cidr
  public_subnet_ids  = dependency.vpc.outputs.public_subnets
  private_subnet_ids = dependency.vpc.outputs.private_subnets
  mgmt_security_group_id = dependency.security.outputs.mgmt_sg_id
  app_security_group_id  = dependency.security.outputs.app_sg_id
  environment   = "dev"
  project_name  = "spring-petclinic"
  key_pair_name = "spms-dev"

  # Instance Names (Standardized)
  bastion_instance_name   = "bastion-host"
  jenkins_instance_name   = local.env_vars.instances.jenkins_master.name
  sonarqube_instance_name = local.env_vars.instances.sonarqube.name
  worker_instance_name    = "worker-node"

  # Instance Types (Configured via env.yaml)
  bastion_instance_type   = "t3.micro"
  jenkins_instance_type   = local.env_vars.instances.jenkins_master.type
  sonarqube_instance_type = local.env_vars.instances.sonarqube.type
  worker_node_type        = local.env_vars.k8s_cluster.worker_node_type
  worker_node_count       = local.env_vars.k8s_cluster.desired_capacity

  # Storage Configuration
  root_volume_size            = 20
  jenkins_root_volume_size    = 20
  jenkins_extra_volume_size   = 10
  sonarqube_root_volume_size  = 20
  sonarqube_extra_volume_size = 0
  worker_root_volume_size     = 50
  worker_extra_volume_size    = 50

  # System Configuration
  bashrc_content = file("${get_terragrunt_dir()}/../../../modules/scripts/.bashrc")

  # Render User data
  bastion_user_data = base64encode(templatefile("${get_terragrunt_dir()}/../../../modules/scripts/bastion_bootstrap.sh.tftpl", {
    hostname = "bastion-host"
    project_url = "https://github.com/Ganil151/spring-petclinic-microservices.git"
    env = "dev"
    bashrc_content = file("${get_terragrunt_dir()}/../../../modules/scripts/.bashrc")
  }))

  jenkins_user_data = base64encode(templatefile("${get_terragrunt_dir()}/../../../modules/scripts/jenkins_bootstrap.sh.tftpl", {
    hostname = "jenkins-master"
    project_url = "https://github.com/Ganil151/spring-petclinic-microservices.git"
    env = "dev"
    bashrc_content = file("${get_terragrunt_dir()}/../../../modules/scripts/.bashrc")
  }))

  worker_user_data = base64encode(templatefile("${get_terragrunt_dir()}/../../../modules/scripts/worker_bootstrap.sh.tftpl", {
    hostname = "worker-node"
    project_url = "https://github.com/Ganil151/spring-petclinic-microservices.git"
    env = "dev"
    bashrc_content = file("${get_terragrunt_dir()}/../../../modules/scripts/.bashrc")
  }))

  sonarqube_user_data = base64encode(templatefile("${get_terragrunt_dir()}/../../../modules/scripts/sonarqube_bootstrap.sh.tftpl", {
    hostname = "sonarqube-server"
    project_url = "https://github.com/Ganil151/spring-petclinic-microservices.git"
    env = "dev"
    bashrc_content = file("${get_terragrunt_dir()}/../../../modules/scripts/.bashrc")
  }))

  # Monitoring
  enable_monitoring = true

  # Security
  allowed_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Environment = "dev"
    ManagedBy   = "Gsmash DevTeam"
  }
}
