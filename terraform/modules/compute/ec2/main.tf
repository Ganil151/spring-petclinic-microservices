resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.instance_name}-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data
  iam_instance_profile        = var.iam_instance_profile

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.instance_name}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Optional Additional EBS Volume
resource "aws_ebs_volume" "extra" {
  count             = var.extra_volume_size > 0 ? 1 : 0
  availability_zone = aws_instance.this.availability_zone
  size              = var.extra_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.instance_name}-data"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_volume_attachment" "this" {
  count       = var.extra_volume_size > 0 ? 1 : 0
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.extra[0].id
  instance_id = aws_instance.this.id
}
