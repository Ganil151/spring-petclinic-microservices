resource "aws_instance" "k8s_node" {
  ami                    = var.ami_id == "" ? data.aws_ami.amazon_linux_2.id : var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [] # To be linked in next step

  tags = {
    Name        = "${var.project_name}-node"
    Environment = "dev"
  }
}