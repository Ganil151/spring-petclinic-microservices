resource "aws_key_pair" "spms_dev" {
  key_name   = "spms-dev"
  

  tags = {
    Name        = "spms-pro"
    Environment = var.environment
    Project     = var.project_name
  }
}
