# =============================================================================
# EC2 Key Pair for SSH Access
# =============================================================================

# Generate a new key pair if public_key is not provided
resource "tls_private_key" "main" {
  count = var.public_key == null ? 1 : 0

  # ED25519 is recommended for modern SSH (faster, smaller, equally secure)
  # RSA 4096 for legacy compatibility
  algorithm = var.key_algorithm
  rsa_bits  = var.key_algorithm == "RSA" ? var.rsa_bits : null

  lifecycle {
    create_before_destroy = true
  }
}

# Create the AWS key pair
resource "aws_key_pair" "main" {
  key_name   = var.key_pair_name
  public_key = var.public_key != null ? var.public_key : tls_private_key.main[0].public_key_openssh

  tags = merge({
    Name        = var.key_pair_name
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}

# Save private key to local file (if filename specified)
resource "local_file" "private_key" {
  count           = var.public_key == null && var.private_key_filename != "" ? 1 : 0
  content         = tls_private_key.main[0].private_key_pem
  filename        = var.private_key_filename
  file_permission = "0600"
}

# Store private key in SSM Parameter Store (optional)
resource "aws_ssm_parameter" "private_key" {
  count = var.public_key == null && var.store_in_ssm ? 1 : 0

  name  = coalesce(var.ssm_parameter_name, "/${var.project_name}/${var.environment}/key-pair/${var.key_pair_name}")
  type  = "SecureString"
  value = tls_private_key.main[0].private_key_pem
  overwrite = true

  tags = merge({
    Name        = var.key_pair_name
    Environment = var.environment
    Project     = var.project_name
  }, var.tags)
}
