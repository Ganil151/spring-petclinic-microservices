# =============================================================================
# Terragrunt Configuration for Ansible Inventory Generation
# =============================================================================
# This module generates the Ansible inventory file from Terraform outputs.
# Every `terragrunt apply` keeps the inventory in sync with infrastructure.
# =============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ansible"
}

# =============================================================================
# Module Dependencies
# =============================================================================

dependency "vpc" {
  config_path = "../vpc"

  # Mock outputs for plan/validate when VPC not yet deployed
  mock_outputs = {
    vpc_id          = "vpc-mock123456"
    vpc_cidr        = "10.0.0.0/16"
    public_subnets  = ["subnet-mock1", "subnet-mock2"]
    private_subnets = ["subnet-mock3", "subnet-mock4"]
  }
}

dependency "ec2_instances" {
  config_path = "../ec2-instances"

  # Mock outputs for plan/validate when EC2 not yet deployed
  mock_outputs = {
    bastion_public_ip       = "52.0.0.1"
    bastion_private_ip      = "10.0.1.1"
    jenkins_public_ip       = "52.0.0.2"
    jenkins_private_ip      = "10.0.1.2"
    sonarqube_public_ip     = "52.0.0.3"
    sonarqube_private_ip    = "10.0.1.3"
    worker_node_public_ips  = ["52.0.0.4", "52.0.0.5"]
    worker_node_private_ips = ["10.0.1.4", "10.0.1.5"]
  }
}

dependency "security" {
  config_path = "../security-groups"

  mock_outputs = {
    mgmt_sg_id = "sg-mock123"
    app_sg_id  = "sg-mock456"
  }
}

dependency "key_pair" {
  config_path = "../key-pair"

  mock_outputs = {
    key_pair_name = "spms-dev"
    key_pair_id   = "key-mock123"
  }
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    db_endpoint = "spring-petclinic-dev-db.xxxxx.us-east-1.rds.amazonaws.com:3306"
    db_address  = "spring-petclinic-dev-db.xxxxx.us-east-1.rds.amazonaws.com"
    db_port     = "3306"
  }
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs = {
    alb_dns_name = "petclinic-dev-alb.xxxxx.us-east-1.elb.amazonaws.com"
    alb_arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789:loadbalancer/app/petclinic-dev-alb/xxxxx"
  }
}

# =============================================================================
# Inputs for Ansible Inventory Module
# =============================================================================

inputs = {
  # Project Configuration
  project_name = "spring-petclinic"
  environment  = "dev"

  # Inventory Configuration
  inventory_file_path = "${get_parent_terragrunt_dir()}/../ansible/inventory/hosts"
  ansible_working_dir = "${get_parent_terragrunt_dir()}/../ansible"
  ssh_key_file        = "${get_parent_terragrunt_dir()}/live/dev/key-pair/spms-dev.pem"

  # VPC Information
  vpc_id     = dependency.vpc.outputs.vpc_id
  vpc_cidr   = dependency.vpc.outputs.vpc_cidr
  aws_region = "us-east-1"
  account_id = get_aws_account_id()

  # EC2 Instance Information
  bastion_ip           = try(dependency.ec2_instances.outputs.bastion_public_ip, "")
  bastion_priv_ip      = try(dependency.ec2_instances.outputs.bastion_private_ip, "")
  jenkins_master_ip    = try(dependency.ec2_instances.outputs.jenkins_public_ip, "")
  jenkins_master_priv  = try(dependency.ec2_instances.outputs.jenkins_private_ip, "")
  sonarqube_ip         = try(dependency.ec2_instances.outputs.sonarqube_public_ip, "")
  sonarqube_priv       = try(dependency.ec2_instances.outputs.sonarqube_private_ip, "")
  worker_node_ips      = try(dependency.ec2_instances.outputs.worker_node_public_ips, [])
  worker_node_priv_ips = try(dependency.ec2_instances.outputs.worker_node_private_ips, [])

  # Security Groups
  security_groups = {
    bastion       = try(dependency.security.outputs.mgmt_sg_id, null)
    k8s_nodes     = try(dependency.security.outputs.app_sg_id, null)
    ec2_instances = null
  }

  # Key Pair Information
  key_pair_name = try(dependency.key_pair.outputs.key_pair_name, "spms-dev")

  # Database Information
  database = {
    endpoint = try(dependency.rds.outputs.db_endpoint, null)
    address  = try(dependency.rds.outputs.db_address, null)
    port     = try(dependency.rds.outputs.db_port, "3306")
  }

  # Load Balancer Information
  alb = {
    dns_name = try(dependency.alb.outputs.alb_dns_name, null)
    arn      = try(dependency.alb.outputs.alb_arn, null)
  }

  # Ansible Configuration
  run_ansible              = true
  enable_ansible_inventory = true
  ssh_user                 = "ec2-user"

  # Extra variables for Ansible (Optional - if the module were to support them)
  # java_version       = "21"
  # sonarqube_version  = "10.4-community"
  # jenkins_image      = "jenkins/jenkins:lts-jdk21"
  # kubernetes_version = "1.28"
  # helm_version       = "3.13.0"

  # Inventory Groups Configuration
  inventory_groups = {
    # Bastion hosts
    bastion_hosts = {
      enabled = true
      vars = {
        ansible_roles = "docker,git,security_tools"
      }
    }

    # Jenkins masters
    jenkins_masters = {
      enabled = true
      vars = {
        ansible_roles  = "java,docker,awscli,jenkins,security_tools"
        jenkins_memory = "2g"
        jenkins_cpu    = "2.0"
      }
    }

    # SonarQube servers
    sonarqube_servers = {
      enabled = true
      vars = {
        ansible_roles    = "java,docker,awscli,sonarqube,security_tools"
        sonarqube_memory = "2g"
        sonarqube_cpu    = "2.0"
      }
    }

    # Kubernetes workers
    k8s_workers = {
      enabled = true
      vars = {
        ansible_roles = "java,docker,awscli,maven,kubectl,helm"
        k8s_max_pods  = 110
      }
    }
  }

  # Tags for all resources
  tags = {
    Project     = "spring-petclinic"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Team        = "DevOps"
  }
}

# =============================================================================
# Local Configuration
# =============================================================================

locals {
  # Generate inventory name
  inventory_name = "spring-petclinic-${local.env}-inventory"

  # Environment from path (e.g., live/dev/ansible -> dev)
  env = element(split("/", path_relative_to_include()), 1)
}
