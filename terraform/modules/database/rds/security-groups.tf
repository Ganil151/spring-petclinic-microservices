# Security Group for RDS (created here if not provided externally)
resource "aws_security_group" "rds" {
  count       = length(var.security_group_ids) == 0 ? 1 : 0
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# MySQL ingress rule
resource "aws_vpc_security_group_ingress_rule" "mysql" {
  count             = length(var.security_group_ids) == 0 ? 1 : 0
  security_group_id = aws_security_group.rds[0].id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
  description       = "MySQL from VPC"
}

# PostgreSQL ingress rule
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  count             = length(var.security_group_ids) == 0 ? 1 : 0
  security_group_id = aws_security_group.rds[0].id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "PostgreSQL from VPC"
}

# Egress rule - allow all outbound
resource "aws_vpc_security_group_egress_rule" "rds" {
  count             = length(var.security_group_ids) == 0 ? 1 : 0
  security_group_id = aws_security_group.rds[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}
