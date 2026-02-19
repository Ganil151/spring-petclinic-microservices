data "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.project_name}-${var.environment}-oidc-provider"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Example: IAM Role for Load Balancer Controller (Placeholder for reference)
# In professional setups, you use this OIDC provider to bind K8s SA to IAM Roles
output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
