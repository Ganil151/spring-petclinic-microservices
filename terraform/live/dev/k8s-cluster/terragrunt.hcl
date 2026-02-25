include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Load environment configuration
locals {
  env_vars = yamldecode(file(find_in_parent_folders("env.yaml")))
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/compute/k8s-node"
}

# Pull data from the security module
dependency "security" {
  config_path = "../security-groups"
  mock_outputs = {
    app_sg_id  = "sg-10000002"
  }
  skip_outputs = false
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000"
    private_subnets = ["subnet-00000001", "subnet-00000002"]
  }
}

# Pull data from the key-pair module
dependency "key_pair" {
  config_path = "../key-pair"
  mock_outputs = {
    key_pair_name = "spms-mock-key"
  }
}



# Pass inputs to the Terraform module
inputs = {
  project_name      = "spring-petclinic"
  environment       = "dev"
  
  vpc_id            = dependency.vpc.outputs.vpc_id
  subnet_ids        = dependency.vpc.outputs.private_subnets
  security_group_id = dependency.security.outputs.app_sg_id
  key_name          = dependency.key_pair.outputs.key_pair_name
  
  instance_type     = local.env_vars.k8s_cluster.worker_node_type
  node_count        = local.env_vars.k8s_cluster.desired_capacity
  root_volume_size  = 50

  # Render User data
  user_data = base64gzip(templatefile("${get_terragrunt_dir()}/../../../modules/scripts/worker_bootstrap.sh.tftpl", {
    hostname = "worker-node"
    project_url = "https://github.com/Ganil151/spring-petclinic-microservices.git"
    env = "dev"
    bashrc_content = file("${get_terragrunt_dir()}/../../../modules/scripts/.bashrc")
  }))
}