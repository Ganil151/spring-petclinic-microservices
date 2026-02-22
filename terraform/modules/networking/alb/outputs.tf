output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.microservices.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "security_group_id" {
  description = "Security group ID for ALB"
  value       = var.security_group_id != null ? var.security_group_id : aws_security_group.alb[0].id
}

output "security_group_arn" {
  description = "Security group ARN for ALB"
  value       = var.security_group_id != null ? var.security_group_id : aws_security_group.alb[0].arn
}

output "key_pair_id" {
  description = "Key pair ID"
  value       = var.create_key_pair ? aws_key_pair.main[0].key_pair_id : null
}

output "key_pair_name" {
  description = "Key pair name"
  value       = var.create_key_pair ? aws_key_pair.main[0].key_name : null
}

output "private_key_pem" {
  description = "Private key in PEM format (sensitive)"
  value       = var.create_key_pair && var.key_pair_public_key == null ? tls_private_key.main[0].private_key_pem : null
  sensitive   = true
}
