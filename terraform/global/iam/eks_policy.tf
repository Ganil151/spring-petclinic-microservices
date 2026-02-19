
resource "aws_iam_policy" "eks_read_only" {
  name        = "${var.project_name}-${var.environment}-eks-read-only"
  description = "Allows ec2 instances to describe EKS clusters for kubeconfig updates"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.eks_read_only.arn
}
