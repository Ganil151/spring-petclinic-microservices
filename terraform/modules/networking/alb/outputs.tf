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
