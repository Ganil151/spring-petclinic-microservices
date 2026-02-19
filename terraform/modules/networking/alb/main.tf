resource "aws_lb" "this" {
  name               = lower("${var.project_name}-${var.environment}-alb")
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-alb")
    Environment = var.environment
    Project     = var.project_name
  }
}

# Default Target Group (Placeholder)
resource "aws_lb_target_group" "default" {
  name     = lower("${var.project_name}-${var.environment}-default-tg")
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-default-tg")
    Environment = var.environment
    Project     = var.project_name
  }
}

# Default HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}
