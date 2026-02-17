resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${var.output_path}/${var.key_name}.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh

  tags = merge(
    {
      Name        = var.key_name
      Environment = var.environment
      Project     = var.project_name
    },
    var.tags
  )
}
