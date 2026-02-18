# ───────────────────────────────────────────────────────────────────
# Terraform Outputs — Staging Environment
# ───────────────────────────────────────────────────────────────────
# These outputs feed into CI/CD pipelines, Ansible, and documentation.

# ─── Networking ───────────────────────────────────────────────────
output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

# ─── ECR (Container Registry) ───────────────────────────────────
output "ecr_registry_id" {
  description = "AWS account ID that owns the ECR registry"
  value       = module.ecr.registry_id
}

output "ecr_repository_urls" {
  description = "Map of microservice name → ECR repository URL (use in docker push/pull)"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of microservice name → ECR repository ARN (use in IAM policies)"
  value       = module.ecr.repository_arns
}

output "ecr_repository_names" {
  description = "List of ECR repository names created in this environment"
  value       = module.ecr.repository_names
}
