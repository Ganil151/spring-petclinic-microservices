# =============================================================================
# Tiered Security Groups for Spring Petclinic (Refactored)
# =============================================================================
# This module implements a tiered security model:
# 1. Web Tier (ALB) - Public entry
# 2. Management Tier (Bastion) - SSH/Admin entry
# 3. Application Tier (Microservices) - Logic
# 4. Data Tier (RDS) - Storage
# =============================================================================

# -----------------------------------------------------------------------------
# 1. MANAGEMENT TIER - Bastion Host / Jump Box
# -----------------------------------------------------------------------------
resource "aws_security_group" "mgmt" {
  name        = "${var.project_name}-${var.environment}-mgmt-sg"
  description = "Management Tier Security Group (Bastion/SSH)"
  vpc_id      = var.vpc_id

  # SSH from allowed CIDRs
  ingress {
    description = "SSH from authorized networks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks # In Prod, this would be restricted
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mgmt-sg"
    Environment = var.environment
    Tier        = "Management"
  }
}

# -----------------------------------------------------------------------------
# 2. WEB TIER - Application Load Balancer
# -----------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Web Tier Security Group (ALB)"
  vpc_id      = var.vpc_id

  # HTTP/HTTPS from Public
  ingress {
    description = "HTTP from Public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks
  }

  ingress {
    description = "HTTPS from Public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.public_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-sg"
    Environment = var.environment
    Tier        = "Web"
  }
}

# -----------------------------------------------------------------------------
# 3. APPLICATION TIER - Microservices & Tools
# -----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Application Tier Security Group (Microservices/Jenkins/Sonar)"
  vpc_id      = var.vpc_id

  # Traffic from Web Tier (ALB)
  ingress {
    description     = "Traffic from Web Tier"
    from_port       = 8080 # Jenkins / Apps
    to_port         = 9411 # Zipkin / Monitoring range
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # Admin Access from Mgmt Tier (Bastion)
  ingress {
    description     = "SSH from Management Tier"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.mgmt.id]
  }

  ingress {
    description     = "Internal Admin Access from Mgmt Tier"
    from_port       = 8080
    to_port         = 9411
    protocol        = "tcp"
    security_groups = [aws_security_group.mgmt.id]
  }

  # Internal Microservice Communication
  ingress {
    description = "Internal Cross-Service Communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-sg"
    Environment = var.environment
    Tier        = "Application"
  }
}

# -----------------------------------------------------------------------------
# 4. DATA TIER - RDS / Storage
# -----------------------------------------------------------------------------
resource "aws_security_group" "data" {
  name        = "${var.project_name}-${var.environment}-data-sg"
  description = "Data Tier Security Group (RDS)"
  vpc_id      = var.vpc_id

  # Database Access from App Tier
  ingress {
    description     = "Database Access from App Tier"
    from_port       = 3306 # MySQL
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "PostgreSQL Access from App Tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Direct access for Bastion (for DB Administration)
  ingress {
    description     = "Database Access from Mgmt Tier"
    from_port       = 3306
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.mgmt.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-sg"
    Environment = var.environment
    Tier        = "Data"
  }
}
