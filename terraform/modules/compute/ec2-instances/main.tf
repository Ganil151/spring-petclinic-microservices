# =============================================================================
# EC2 Instances Module for Spring Petclinic
# Includes: Bastion Host, Jenkins Master, SonarQube, Worker Nodes
# =============================================================================

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# Bastion Host
# Tier: Management
# =============================================================================
resource "aws_instance" "bastion" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.mgmt_security_group_id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring
  user_data  = var.bastion_user_data

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.bastion_instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "bastion"
    Tier        = "Management"
    ManagedBy   = var.manage_by
  }, var.tags)
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-bastion-eip"
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}

# =============================================================================
# Jenkins Master
# Tier: Application
# =============================================================================
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.app_security_group_id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.jenkins_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  dynamic "ebs_block_device" {
    for_each = var.jenkins_extra_volume_size > 0 ? [1] : []
    content {
      device_name           = "/dev/sdh"
      volume_size           = var.jenkins_extra_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring = var.enable_monitoring
  user_data  = var.jenkins_user_data

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.jenkins_instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "jenkins"
    Tier        = "Application"
    ManagedBy   = var.manage_by
  }, var.tags)
}

# =============================================================================
# SonarQube Server
# Tier: Application
# =============================================================================
resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.sonarqube_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.app_security_group_id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.sonarqube_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  dynamic "ebs_block_device" {
    for_each = var.sonarqube_extra_volume_size > 0 ? [1] : []
    content {
      device_name           = "/dev/sdh"
      volume_size           = var.sonarqube_extra_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring = var.enable_monitoring
  user_data  = var.sonarqube_user_data

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.sonarqube_instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "sonarqube"
    Tier        = "Application"
    ManagedBy   = var.manage_by
  }, var.tags)
}

# =============================================================================
# Worker Nodes
# Tier: Application
# =============================================================================
resource "aws_instance" "worker_nodes" {
  count                  = var.worker_node_count
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.worker_node_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [var.app_security_group_id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.worker_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  dynamic "ebs_block_device" {
    for_each = var.worker_extra_volume_size > 0 ? [1] : []
    content {
      device_name           = "/dev/sdh"
      volume_size           = var.worker_extra_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring = var.enable_monitoring
  user_data  = var.worker_user_data

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.worker_instance_name}-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "worker-node"
    Tier        = "Application"
    ManagedBy   = var.manage_by
  }, var.tags)
}
