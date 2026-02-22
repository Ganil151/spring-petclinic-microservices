output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Database address (hostname)"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Database master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_password" {
  description = "Database master password"
  value       = aws_db_instance.main.password
  sensitive   = true
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "db_subnet_group_arn" {
  description = "DB subnet group ARN"
  value       = aws_db_subnet_group.main.arn
}

output "ssm_parameter_username" {
  description = "SSM parameter name for username"
  value       = aws_ssm_parameter.db_username.name
}

output "ssm_parameter_password" {
  description = "SSM parameter name for password"
  value       = aws_ssm_parameter.db_password.name
}

output "ssm_parameter_endpoint" {
  description = "SSM parameter name for endpoint"
  value       = aws_ssm_parameter.db_endpoint.name
}
