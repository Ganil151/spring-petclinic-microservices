resource "aws_instance" "k8s_node" {
  count                  = var.node_count
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data_base64 = var.user_data
  user_data_replace_on_change = true

  tags = {
    Name        = "${var.project_name}-worker-${count.index + 1}"
    Environment = var.environment
    Component   = "worker-node"
    Tier        = "Application"
  }
}