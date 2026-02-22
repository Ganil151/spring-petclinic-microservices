resource "aws_instance" "k8s_node" {
  ami           = var.ami.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_ids[0]

  tags = {
    Name = "${var.project_name}-node"
  }

}