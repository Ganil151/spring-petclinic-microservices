resource "aws_key_pair" "spms_pro" {
  key_name   = "spms-pro"
  public_key = file("${path.module}/../../../keys/spms-pro.pub")

  tags = {
    Name        = "spms-pro"
    Environment = var.environment
    Project     = var.project_name
  }
}
