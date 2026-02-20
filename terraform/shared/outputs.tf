# ───────────────────────────────────────────────────────────────────
# Shared Terraform Outputs
# ───────────────────────────────────────────────────────────────────
# These outputs are shared across environments via symlinks.

# ─── Networking ───────────────────────────────────────────────────
output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = try(module.alb.alb_dns_name, "N/A")
}

# ─── Jenkins Master ──────────────────────────────────────────────
output "jenkins_master_public_ip" {
  description = "Public IP of the Jenkins Master"
  value       = try(module.jenkins_master.public_ips[0], "N/A")
}

output "jenkins_master_private_ip" {
  description = "Private IP of the Jenkins Master"
  value       = try(module.jenkins_master.private_ips[0], "N/A")
}

# ─── Worker Nodes ────────────────────────────────────────────────
output "worker_node_public_ips" {
  description = "Public IPs of the Worker Nodes"
  value       = try(module.worker_node.public_ips, [])
}

output "worker_node_private_ips" {
  description = "Private IPs of the Worker Nodes"
  value       = try(module.worker_node.private_ips, [])
}

# ─── SonarQube ───────────────────────────────────────────────────
output "sonarqube_public_ip" {
  description = "Public IP of the SonarQube Server"
  value       = try(module.sonarqube_server.public_ips[0], "N/A")
}

# ─── ECR (Container Registry) ───────────────────────────────────
output "ecr_registry_id" {
  description = "AWS account ID that owns the ECR registry"
  value       = try(module.ecr.registry_id, "N/A")
}

output "ecr_repository_urls" {
  description = "Map of microservice name → ECR repository URL"
  value       = try(module.ecr.repository_urls, {})
}

# ─── RDS (Database) ──────────────────────────────────────────────
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = try(module.rds.rds_endpoint, "N/A")
}

# ─── EKS (Kubernetes) ─────────────────────────────────────────────
output "eks_primary_cluster_name" {
  description = "The name of the primary EKS cluster"
  value       = try(module.eks_primary.cluster_name, "N/A")
}

output "eks_secondary_cluster_name" {
  description = "The name of the secondary EKS cluster"
  value       = try(module.eks_secondary.cluster_name, "N/A")
}

output "eks_primary_endpoint" {
  description = "The endpoint for the primary EKS cluster"
  value       = try(module.eks_primary.cluster_endpoint, "N/A")
}

output "eks_secondary_endpoint" {
  description = "The endpoint for the secondary EKS cluster"
  value       = try(module.eks_secondary.cluster_endpoint, "N/A")
}
