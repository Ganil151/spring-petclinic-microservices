resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  user_data_base64            = base64encode(var.user_data)
  iam_instance_profile        = var.iam_instance_profile

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = var.instance_count > 1 ? "${var.project_name}-${var.environment}-${var.instance_name}-${count.index + 1}" : "${var.project_name}-${var.environment}-${var.instance_name}"
    Environment = var.environment
    Project     = var.project_name
    Role        = var.role
    }
  }

  lifecycle {
    ignore_changes = [
      key_name,
      ami    
    ]
 }

# Optional Additional EBS Volume
resource "aws_ebs_volume" "extra" {
  count             = var.extra_volume_size > 0 ? var.instance_count : 0
  availability_zone = aws_instance.this[count.index].availability_zone
  size              = var.extra_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = var.instance_count > 1 ? "${var.project_name}-${var.environment}-${var.instance_name}-data-${count.index + 1}" : "${var.project_name}-${var.environment}-${var.instance_name}-data"
    Environment = var.environment
    Project     = var.project_name
    Role        = var.role
  }
}

resource "aws_volume_attachment" "this" {
  count       = var.extra_volume_size > 0 ? var.instance_count : 0
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.extra[count.index].id
  instance_id = aws_instance.this[count.index].id
}
