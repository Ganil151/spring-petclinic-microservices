output "api_gateway_security_group_id" {
  description = "Security group ID for API Gateway"
  value       = aws_security_group.api_gateway.id
}

output "admin_server_security_group_id" {
  description = "Security group ID for Admin Server"
  value       = aws_security_group.admin_server.id
}

output "config_server_security_group_id" {
  description = "Security group ID for Config Server"
  value       = aws_security_group.config_server.id
}

output "discovery_server_security_group_id" {
  description = "Security group ID for Discovery Server"
  value       = aws_security_group.discovery_server.id
}

output "microservices_security_group_id" {
  description = "Security group ID for backend microservices"
  value       = aws_security_group.microservices.id
}

output "database_security_group_id" {
  description = "Security group ID for database"
  value       = aws_security_group.database.id
}

output "zipkin_security_group_id" {
  description = "Security group ID for Zipkin"
  value       = var.enable_zipkin ? aws_security_group.zipkin[0].id : null
}

output "grafana_security_group_id" {
  description = "Security group ID for Grafana"
  value       = var.enable_grafana ? aws_security_group.grafana[0].id : null
}

output "prometheus_security_group_id" {
  description = "Security group ID for Prometheus"
  value       = var.enable_prometheus ? aws_security_group.prometheus[0].id : null
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "k8s_nodes_security_group_id" {
  description = "Security group ID for Kubernetes nodes"
  value       = aws_security_group.k8s_nodes.id
}

output "bastion_security_group_id" {
  description = "Security group ID for Bastion Host"
  value       = aws_security_group.bastion.id
}

output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    api_gateway   = aws_security_group.api_gateway.id
    admin_server  = aws_security_group.admin_server.id
    config_server = aws_security_group.config_server.id
    discovery     = aws_security_group.discovery_server.id
    microservices = aws_security_group.microservices.id
    database      = aws_security_group.database.id
    zipkin        = var.enable_zipkin ? aws_security_group.zipkin[0].id : null
    grafana       = var.enable_grafana ? aws_security_group.grafana[0].id : null
    prometheus    = var.enable_prometheus ? aws_security_group.prometheus[0].id : null
    alb           = aws_security_group.alb.id
    k8s_nodes     = aws_security_group.k8s_nodes.id
    bastion       = aws_security_group.bastion.id
  }
}
