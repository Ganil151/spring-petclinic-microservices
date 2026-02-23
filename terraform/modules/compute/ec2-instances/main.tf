# =============================================================================
# EC2 Instances Module for Spring Petclinic
# Includes: Bastion Host, Jenkins Master, SonarQube, Worker Nodes
# =============================================================================

# Allowed ports for security groups
locals {
  ingress_ports = [
    22,   # SSH
    80,   # HTTP
    443,  # HTTPS
    8080, # Jenkins, API Gateway
    9000, # SonarQube
    8761, # Discovery Server
    8888, # Config Server
    9090, # Admin Server
    8081, # Customers Service
    8082, # Vets Service
    8083, # Visits Service
    9091, # Prometheus
    3000, # Grafana
    9411  # Zipkin
  ]
}

# =============================================================================
# Security Group for EC2 Instances
# =============================================================================
resource "aws_security_group" "ec2_instances" {
  name        = "${var.project_name}-${var.environment}-ec2-instances-sg"
  description = "Security group for EC2 instances with all required ports"
  vpc_id      = var.vpc_id

  # Dynamic ingress rules for all allowed ports
  dynamic "ingress" {
    for_each = local.ingress_ports
    content {
      description = "Port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-ec2-instances-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "ec2-instances"
  }, var.tags)
}

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
# =============================================================================
resource "aws_instance" "bastion" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = concat(var.security_group_ids, [aws_security_group.ec2_instances.id])
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring

  user_data = "terraform/scripts/bastion_bootstrap.sh"

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.bastion_instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "bastion"
    ManagedBy   = "Terraform"
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
    Component   = "bastion"
  }, var.tags)
}

# =============================================================================
# Jenkins Master
# Ansible Roles: java, docker, awscli, jenkins, security_tools
# =============================================================================
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = concat(var.security_group_ids, [aws_security_group.ec2_instances.id])
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.jenkins_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Extra volume for Jenkins builds/workspace
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

  user_data = "terraform/scripts/jenkins_bootstrap.sh"

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.jenkins_instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "jenkins"
    ManagedBy   = "Terraform"
  }, var.tags)
}

# =============================================================================
# SonarQube Server
# Ansible Roles: java, docker, awscli, sonarqube, security_tools
# =============================================================================
resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.sonarqube_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = concat(var.security_group_ids, [aws_security_group.ec2_instances.id])
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.sonarqube_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Extra volume for SonarQube data
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

  lifecycle {
    create_before_destroy = true
  }

  user_data = "terraform/scripts/sonarqube_bootstrap.sh"

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.sonarqube_instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "sonarqube"
    ManagedBy   = "Terraform"
  }, var.tags)
}

# =============================================================================
# Worker Nodes (Auto Scaling Group style - manual for now)
# Ansible Roles: java, docker, awscli, maven, kubectl, helm
# =============================================================================
resource "aws_instance" "worker_nodes" {
  count                  = var.worker_node_count
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.worker_node_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = concat(var.security_group_ids, [aws_security_group.ec2_instances.id])
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.worker_root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Extra volume for Docker images and containers
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

  user_data = "terraform/scripts/worker_bootstrap.sh"

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-${var.worker_instance_name}-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "worker-node"
    ManagedBy   = "Terraform"
  }, var.tags)
}
