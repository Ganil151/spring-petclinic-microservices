# ============================================================================
# Terraform → Ansible Integration: Auto-Generated Inventory
# ============================================================================
# This resource creates the Ansible inventory file from live Terraform outputs.
# Every `terraform apply` keeps the inventory in sync with actual infrastructure.

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

module "iam" {
  source = "../../global/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  # Full list of microservice repositories for the Spring PetClinic project
  repository_names = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "admin-server",
    "genai-service"
  ]

  # IMMUTABLE tags prevent overwriting released images — use MUTABLE only in dev
  image_tag_mutability = "MUTABLE"

  # Enable CVE scanning on every push (SRE security standard)
  scan_on_push = true

  # IAM role must exist before ECR repos are created so Jenkins can push images
  depends_on = [module.iam]
}

module "jenkins_master" {
  source = "../../modules/compute/ec2"

  project_name                = var.project_name
  environment                 = var.environment
  instance_name               = var.jenkins_instance_name
  role                        = "master"
  ami_id                      = var.ami
  instance_type               = var.jenkins_instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  security_group_ids          = [module.sg.ec2_sg_id]
  key_name                    = var.key_name
  associate_public_ip         = var.associate_public_ip
  user_data                   = file("${path.module}/../../scripts/jenkins_bootstrap.sh")
  user_data_replace_on_change = true
  iam_instance_profile        = module.iam.ec2_profile_name
  root_volume_size            = var.jenkins_root_volume_size
  extra_volume_size           = var.jenkins_extra_volume_size
}


module "worker_node" {
  source = "../../modules/compute/ec2"

  project_name                = var.project_name
  environment                 = var.environment
  instance_name               = var.worker_instance_name
  role                        = "worker"
  ami_id                      = var.ami
  instance_type               = var.worker_instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  security_group_ids          = [module.sg.ec2_sg_id]
  key_name                    = var.key_name
  associate_public_ip         = var.associate_public_ip
  user_data                   = file("${path.module}/../../scripts/worker_bootstrap.sh")
  user_data_replace_on_change = true
  iam_instance_profile        = module.iam.ec2_profile_name
  root_volume_size            = var.worker_root_volume_size
  extra_volume_size           = var.worker_extra_volume_size
}

module "sonarqube_server" {
  source = "../../modules/compute/ec2"

  project_name                = var.project_name
  environment                 = var.environment
  instance_name               = var.sonarqube_instance_name
  role                        = "sonarqube"
  ami_id                      = var.ami
  instance_type               = var.sonarqube_instance_type
  subnet_id                   = module.vpc.public_subnet_ids[0]
  security_group_ids          = [module.sg.ec2_sg_id]
  key_name                    = var.key_name
  associate_public_ip         = var.associate_public_ip
  user_data                   = file("${path.module}/../../scripts/sonarqube_bootstrap.sh")
  user_data_replace_on_change = true
  root_volume_size            = var.sonarqube_root_volume_size
  extra_volume_size           = var.sonarqube_extra_volume_size
}

# ─────────────────────────────────────────────────────────────────────────────
# Terraform → Ansible Integration: Auto-Generated Inventory
# ─────────────────────────────────────────────────────────────────────────────
# This resource creates the Ansible inventory file from live Terraform outputs.
# Every `terraform apply` keeps the inventory in sync with actual infrastructure.

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../../ansible/inventory/dynamic_hosts"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    jenkins_master_ip    = module.jenkins_master.public_ips[0]
    jenkins_master_priv  = module.jenkins_master.private_ips[0]
    worker_node_ips      = module.worker_node.public_ips
    worker_node_priv_ips = module.worker_node.private_ips
    sonarqube_ip         = module.sonarqube_server.public_ips[0]
    sonarqube_priv       = module.sonarqube_server.private_ips[0]
    ssh_user             = "ec2-user"
    ssh_key_file         = var.ssh_private_key_path
  })

  depends_on = [
    module.jenkins_master,
    module.worker_node,
    module.sonarqube_server
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Optional: Auto-Trigger Ansible After Provisioning
# ─────────────────────────────────────────────────────────────────────────────
# Uncomment this block to automatically run the Ansible playbook after
# Terraform provisions the infrastructure. Requires ansible-playbook on PATH.

# resource "null_resource" "run_ansible" {
#   depends_on = [local_file.ansible_inventory]
#
#   triggers = {
#     inventory_id = local_file.ansible_inventory.id
#   }
#
#   provisioner "local-exec" {
#     working_dir = "${path.module}/../../../ansible"
#     command     = <<-EOT
#       echo "Waiting 60s for EC2 instances to initialize..."
#       sleep 60
#       ansible-playbook -i inventory/dynamic_hosts playbooks/install-tools.yml
#     EOT
#   }
# }
