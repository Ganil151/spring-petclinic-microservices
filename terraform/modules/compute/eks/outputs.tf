output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "The certificate-authority-data for the EKS cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_id" {
  description = "The ID of the EKS node group"
  value       = aws_eks_node_group.this.id
}

output "node_role_arn" {
  description = "The ARN of the IAM role used by the EKS nodes"
  value       = aws_iam_role.nodes.arn
}

output "cluster_security_group_id" {
  description = "The ID of the security group associated with the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
