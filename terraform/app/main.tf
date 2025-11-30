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
  user_data_replace_on_change = var.user_data_replace_on_change
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
  user_data_replace_on_change = var.user_data_replace_on_change
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
  user_data_replace_on_change = var.user_data_replace_on_change
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
  user_data_replace_on_change = var.user_data_replace_on_change
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
module "K8s_agent_primary_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_6
  instance_type               = "t3.large"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/k8s_agent_1_server.sh")
  user_data_replace_on_change = var.user_data_replace_on_change
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.k8s_worker_primary_root_volume_size
  root_volume_type            = var.root_volume_type
}

# K8s Worker
module "K8s_agent_secondary_instance" {
  source                      = "../MODULES/EC2"
  ami                         = var.ami
  key_name                    = var.key_name
  project_name_1              = var.project_name_7
  instance_type               = "t3.large"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  user_data                   = file("${path.module}/scripts/k8s_agent_2_server.sh")
  user_data_replace_on_change = var.user_data_replace_on_change
  security_group_ids          = [module.master_sg.master_sg]
  environment                 = var.environment
  root_volume_size            = var.k8s_worker_secondary_root_volume_size
  root_volume_type            = var.root_volume_type
}


# # EKS Cluster (Optional - controlled by enable_eks variable)
# module "eks_cluster" {
#   count  = var.enable_eks ? 1 : 0
#   source = "../MODULES/eks"

#   cluster_name    = var.eks_cluster_name
#   cluster_version = var.eks_cluster_version

#   # Use public subnets from existing VPC
#   subnet_ids = module.vpc.public_subnet_ids

#   # Node Groups Configuration (Multiple)
#   node_groups = var.eks_node_groups

#   # Tags
#   tags = {
#     Name        = var.eks_cluster_name
#     Environment = var.environment
#     Terraform   = "true"
#     Project     = "spring-petclinic"
#   }
# }

# resource "kubernetes_config_map" "aws_auth" {
#   count = var.enable_eks ? 1 : 0
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     mapRoles = yamlencode([
#       {
#         rolearn  = module.eks_cluster[0].node_iam_role_arn
#         username = "system:node:{{EC2PrivateDNSName}}"
#         groups   = ["system:bootstrappers", "system:nodes"]
#       }
#     ])
#     mapUsers = yamlencode([
#       {
#         userarn  = var.admin_iam_arn
#         username = "admin"
#         groups   = ["system:masters"]
#       }
#     ])
#   }

#   depends_on = [module.eks_cluster]
# }

# # EKS Outputs (only when EKS is enabled)
# output "eks_cluster_endpoint" {
#   description = "Endpoint for EKS control plane"
#   value       = var.enable_eks ? module.eks_cluster[0].cluster_endpoint : null
# }

# output "eks_cluster_name" {
#   description = "EKS cluster name"
#   value       = var.enable_eks ? module.eks_cluster[0].cluster_id : null
# }

# output "eks_configure_kubectl" {
#   description = "Command to configure kubectl for EKS"
#   value       = var.enable_eks ? module.eks_cluster[0].configure_kubectl : "EKS not enabled"
# }

# output "eks_node_group_status" {
#   description = "Status of the EKS node group"
#   value       = var.enable_eks ? module.eks_cluster[0].node_group_status : null
# }
