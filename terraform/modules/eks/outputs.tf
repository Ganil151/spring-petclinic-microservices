# Cluster Outputs
output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# Node Group Outputs (Multiple)
output "node_group_ids" {
  description = "Map of EKS node group IDs"
  value       = { for k, v in aws_eks_node_group.node_groups : k => v.id }
}

output "node_group_arns" {
  description = "Map of Amazon Resource Names (ARNs) of the EKS Node Groups"
  value       = { for k, v in aws_eks_node_group.node_groups : k => v.arn }
}

output "node_group_status" {
  description = "Map of statuses of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.node_groups : k => v.status }
}

output "node_group_names" {
  description = "List of EKS node group names"
  value       = keys(aws_eks_node_group.node_groups)
}

# IAM Role Outputs
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.eks_cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = aws_iam_role.eks_nodes.arn
}

# kubectl Configuration Command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.id} --name ${aws_eks_cluster.main.name}"
}

# Data source for current region
data "aws_region" "current" {}
