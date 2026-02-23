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

output "ec2_common_role_name" {
  description = "Name of the common EC2 IAM role"
  value       = aws_iam_role.ec2_common_role.name
}

output "ec2_common_instance_profile_name" {
  description = "Name of the common EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_common_profile.name
}

output "ec2_common_instance_profile_arn" {
  description = "ARN of the common EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_common_profile.arn
}
