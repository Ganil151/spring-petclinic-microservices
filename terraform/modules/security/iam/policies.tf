# =============================================================================
# IAM Roles & Policies for Spring Petclinic Microservices
# =============================================================================

# 1. Trust Relationship for EC2 Instances
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 2. Universal EC2 Instance Role
resource "aws_iam_role" "ec2_common_role" {
  name               = "${var.project_name}-${var.environment}-ec2-common-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-common-role"
    Environment = var.environment
  }
}

# 3. Attach Managed Policies (ECR Read-Only, CloudWatch, SSM)
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_common_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cw_logs" {
  role       = aws_iam_role.ec2_common_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_common_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 4. Instance Profile for EC2 Instances
resource "aws_iam_instance_profile" "ec2_common_profile" {
  name = "${var.project_name}-${var.environment}-ec2-common-profile"
  role = aws_iam_role.ec2_common_role.name
}
