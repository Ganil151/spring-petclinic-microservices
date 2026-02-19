resource "aws_security_group" "alb" {
  name        = lower("${var.project_name}-${var.environment}-alb-sg")
  description = "Security group for application load balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Allow HTTP from allowed CIDRs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-alb-sg")
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_security_group" "ec2" {
  name        = lower("${var.project_name}-${var.environment}-ec2-sg")
  description = "Security group for EC2 instances and microservices"
  vpc_id      = var.vpc_id

  # 1. Internal Traffic: Allow all services to talk to each other within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all internal VPC traffic"
  }

  # 2. Administrative/Public Traffic: Restrict external access to common ports
  # We loop through ports but apply a logic: only 22, 80, 443 are truly public.
  # Others (9000, 8080) are now internal-only via the rule above.
  dynamic "ingress" {
    for_each = [22, 80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "Allow public access to port ${ingress.value}"
    }
  }

  # Add 8080 and 9000 to public if they are specifically needed, 
  # but per user request to 'secure', we keep them internal-only for now.
  # (User can still access via SSH tunnel or by adding them back to this list)

  # Allow traffic from ALB
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow all traffic from ALB security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-ec2-sg")
    Environment = var.environment
    Project     = var.project_name
  }
}
