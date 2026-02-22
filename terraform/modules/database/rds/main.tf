# =============================================================================
# RDS Database Module for Spring Petclinic
# =============================================================================

# Random password generation (if not provided)
resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 24
  special = true
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}

# RDS Instance
resource "aws_db_instance" "main" {
  # Basic Configuration
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version == "" ? null : var.db_engine_version
  instance_class = var.db_instance_class

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_engine == "mysql" ? 100 : null
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password == "" ? random_password.db_password[0].result : var.db_password

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Monitoring
  performance_insights_enabled = var.db_instance_class == "db.t3.micro" ? false : true
  performance_insights_retention_period = var.db_instance_class == "db.t3.micro" ? null : 7
  monitoring_interval          = 0  # Disabled by default (set to 60 for enhanced monitoring)
  monitoring_role_arn          = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  # Deletion Configuration
  skip_final_snapshot  = var.skip_final_snapshot
  deletion_protection  = var.deletion_protection
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot"

  # Tags
  tags = merge({
    Name        = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }, var.tags)
}

# Store database credentials in SSM Parameter Store
resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/${var.environment}/database/username"
  type  = "String"
  value = var.db_username

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-db-username"
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/${var.environment}/database/password"
  type  = "SecureString"
  value = var.db_password == "" ? random_password.db_password[0].result : var.db_password

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}

resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/${var.project_name}/${var.environment}/database/endpoint"
  type  = "String"
  value = aws_db_instance.main.endpoint

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-db-endpoint"
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}
