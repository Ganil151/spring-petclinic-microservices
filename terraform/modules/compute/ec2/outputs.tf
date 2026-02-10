output "instance_ids" {
  description = "The IDs of the EC2 instances"
  value       = aws_instance.this[*].id
}

output "public_ips" {
  description = "The public IP addresses assigned to the instances"
  value       = aws_instance.this[*].public_ip
}

output "private_ips" {
  description = "The private IP addresses assigned to the instances"
  value       = aws_instance.this[*].private_ip
}

