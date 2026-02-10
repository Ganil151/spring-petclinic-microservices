output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB (to be used in Route 53 Alias record)"
  value       = aws_lb.this.zone_id
}

output "default_target_group_arn" {
  description = "The ARN of the default target group"
  value       = aws_lb_target_group.default.arn
}
