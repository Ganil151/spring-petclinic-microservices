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
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git wget
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              EOF

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-bastion"
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
# =============================================================================
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              # Install Java 17
              amazon-linux-extras install java-openjdk17 -y
              # Install Jenkins (via Docker)
              docker run -d -p 8080:8080 -p 50000:50000 --name jenkins \
                -v jenkins_home:/var/jenkins_home \
                jenkins/jenkins:lts
              EOF

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-jenkins-master"
    Environment = var.environment
    Project     = var.project_name
    Component   = "jenkins"
    ManagedBy   = "Terraform"
  }, var.tags)
}

# =============================================================================
# SonarQube Server
# =============================================================================
resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.sonarqube_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              # Install SonarQube (via Docker)
              docker run -d -p 9000:9000 --name sonarqube \
                -v sonarqube_data:/opt/sonarqube/data \
                -v sonarqube_extensions:/opt/sonarqube/extensions \
                -v sonarqube_logs:/opt/sonarqube/logs \
                sonarqube:lts-community
              EOF

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-sonarqube"
    Environment = var.environment
    Project     = var.project_name
    Component   = "sonarqube"
    ManagedBy   = "Terraform"
  }, var.tags)
}

# =============================================================================
# Worker Nodes (Auto Scaling Group style - manual for now)
# =============================================================================
resource "aws_instance" "worker_nodes" {
  count                  = var.worker_node_count
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.worker_node_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_pair_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = var.enable_monitoring

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git wget curl
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              # Install Kubernetes tools
              cat <<EOT > /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
              enabled=1
              gpgcheck=1
              gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
              EOT
              yum install -y kubelet kubeadm kubectl
              systemctl enable kubelet
              EOF

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-worker-node-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Component   = "worker-node"
    ManagedBy   = "Terraform"
  }, var.tags)
}
