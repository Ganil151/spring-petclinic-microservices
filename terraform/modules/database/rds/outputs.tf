output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "rds_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.this.port
}

output "rds_security_group_id" {
  description = "The ID of the security group for the RDS instance"
  value       = aws_security_group.rds.id
}

output "rds_username" {
  description = "The master username for the RDS instance"
  value       = aws_db_instance.this.username
}
