resource "aws_instance" "master-server" {
  ami                         = var.ami
  key_name                    = var.key_name
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids # Use the passed security_group_ids
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  tags = {
    Name        = var.project_name_1
    Environment = var.environment
  }

  
}
