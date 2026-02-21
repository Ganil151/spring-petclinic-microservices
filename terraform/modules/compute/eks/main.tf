# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}-cluster-role")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}-cluster-role")
    Environment = var.environment
    Project     = var.project_name
    Role        = var.cluster_role
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# EKS Node Group IAM Role
resource "aws_iam_role" "nodes" {
  name = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}-node-role")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}-node-role")
    Environment = var.environment
    Project     = var.project_name
    Role        = var.cluster_role
  }
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}")
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]

  tags = {
    Name        = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}")
    Environment = var.environment
    Project     = var.project_name
    Role        = var.cluster_role
  }
}

# Managed Node Group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}-node-group")
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types = var.node_group_instance_types

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name                                                 = lower("${var.project_name}-${var.environment}-${var.cluster_suffix}-node-group")
    Environment                                          = var.environment
    Project                                              = var.project_name
    Role                                                 = var.cluster_role
    "kubernetes.io/cluster/${aws_eks_cluster.this.name}" = "owned"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Access Entries (Modern IAM-to-RBAC Bridge)
# ─────────────────────────────────────────────────────────────────────────────

# Admin Access Entries
resource "aws_eks_access_entry" "admins" {
  for_each          = toset(var.admin_role_arns)
  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value
  type              = "STANDARD"
  kubernetes_groups = var.kubernetes_groups
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = toset(var.admin_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}

# Viewer Access Entries
resource "aws_eks_access_entry" "viewers" {
  for_each      = toset(var.cluster_viewer_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "viewers" {
  for_each      = toset(var.cluster_viewer_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:iam::aws:policy/AmazonEKSViewPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.viewers]
}

# 1. Access Entry: Recognizes the Jenkins Role at the Cluster level
resource "aws_eks_access_entry" "jenkins" {
  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/jenkins-agent-role" # Update with actual ARN
  kubernetes_groups = ["ec2-user-deployers"] 
  type              = "STANDARD"
}

# 2. Association: Grant a base "View" policy via EKS API (Optional but recommended)
resource "aws_eks_access_policy_association" "jenkins_view" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:iam::aws:policy/AmazonEKSViewPolicy"
  principal_arn = aws_eks_access_entry.jenkins.principal_arn

  access_scope {
    type = "cluster"
  }
}
