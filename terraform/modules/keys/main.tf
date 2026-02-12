resource "aws_key_pair" "spms_dev" {
  key_name   = "spms-dev"
  public_key = file("${path.module}/../../modules/keys/spms-dev.pub")

  tags = {
    Name        = "spms-dev"
    Environment = var.environment
    Project     = var.project_name
  }
}
