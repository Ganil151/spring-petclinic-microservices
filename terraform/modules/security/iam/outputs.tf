output "web_sg_id" {
  description = "Security group ID for Web Tier (ALB)"
  value       = aws_security_group.web.id
}

output "mgmt_sg_id" {
  description = "Security group ID for Management Tier (Bastion)"
  value       = aws_security_group.mgmt.id
}

output "app_sg_id" {
  description = "Security group ID for Application Tier (Microservices/Tools)"
  value       = aws_security_group.app.id
}

output "data_sg_id" {
  description = "Security group ID for Data Tier (RDS)"
  value       = aws_security_group.data.id
}

output "all_security_group_ids" {
  description = "Map of all tiered security group IDs"
  value = {
    web   = aws_security_group.web.id
    mgmt  = aws_security_group.mgmt.id
    app   = aws_security_group.app.id
    data  = aws_security_group.data.id
  }
}
