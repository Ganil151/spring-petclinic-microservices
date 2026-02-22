# =============================================================================
# EC2 Key Pair for SSH Access
# =============================================================================

resource "aws_key_pair" "main" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = coalesce(var.key_pair_name, "${var.project_name}-${var.environment}-key")
  public_key = var.key_pair_public_key != null ? var.key_pair_public_key : tls_private_key.main[0].public_key_openssh

  tags = {
    Name        = coalesce(var.key_pair_name, "${var.project_name}-${var.environment}-key")
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "tls_private_key" "main" {
  count     = var.create_key_pair && var.key_pair_public_key == null ? 1 : 0
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  count           = var.create_key_pair && var.key_pair_public_key == null && var.key_pair_filename != "" ? 1 : 0
  content         = tls_private_key.main[0].private_key_pem
  filename        = var.key_pair_filename
  file_permission = "0600"
}

resource "aws_security_group" "alb" {
  count       = var.enable_security_group && var.security_group_id == null ? 1 : 0
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB and Spring Petclinic infrastructure"
  vpc_id      = var.vpc_id

  # ==========================================================================
  # Public Access - ALB Ports
  # ==========================================================================
  ingress {
    description = "HTTP from public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "HTTPS from public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # ==========================================================================
  # API Gateway - Entry Point for UI Traffic
  # ==========================================================================
  ingress {
    description = "API Gateway - UI traffic entry point"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # ==========================================================================
  # Infrastructure Services - Internal Access
  # ==========================================================================
  ingress {
    description = "Config Server - Centralized configuration"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "Discovery Server (Eureka) - Service registration"
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # ==========================================================================
  # Backend Microservices - Internal Access
  # ==========================================================================
  ingress {
    description = "Customers Service"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "Visits Service"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "Vets Service"
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "GenAI Service"
    from_port   = 8084
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # ==========================================================================
  # Monitoring & Observability
  # ==========================================================================
  ingress {
    description = "Admin Server - Spring Boot Admin (health/metrics)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "Prometheus - Metrics collection"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "Grafana - Visualization dashboard"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  ingress {
    description = "Zipkin - Distributed tracing"
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # ==========================================================================
  # Database - MySQL/RDS (Internal Only)
  # ==========================================================================
  ingress {
    description = "MySQL/RDS - Database for customer, vet, and visit data"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id]
  }

  # ==========================================================================
  # SSH Access (Optional - for bastion/debugging)
  # ==========================================================================
  dynamic "ingress" {
    for_each = length(var.ssh_cidr_blocks) > 0 ? [1] : []
    content {
      description = "SSH access for bastion/debugging"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
    }
  }

  # ==========================================================================
  # Egress - Allow all outbound
  # ==========================================================================
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
    Component   = "alb"
  }
}

# =============================================================================
# Application Load Balancer for Spring Petclinic
# =============================================================================

resource "aws_lb" "main" {
  name               = coalesce(var.alb_name, "${var.project_name}-${var.environment}-alb")
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_id != null ? [var.security_group_id] : [aws_security_group.alb[0].id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name        = coalesce(var.alb_name, "${var.project_name}-${var.environment}-alb")
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group for microservices
resource "aws_lb_target_group" "microservices" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = var.target_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200-299"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# HTTP Listener - forward to target
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices.arn
  }
}
