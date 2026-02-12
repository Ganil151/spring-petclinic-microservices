resource "tls_private_key" "spms_dev" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "spms_dev" {
  content = tls_private_key.spms_dev.private_key_pem
  filename = "${path.module}/spms-dev.pem"
}

resource "aws_key_pair" "spms_dev" {
  key_name   = "spms-dev"
  public_key = local_file.spms_dev.content

  tags = {
    Name        = "spms-dev"
    Environment = var.environment
    Project     = var.project_name
  }
}

