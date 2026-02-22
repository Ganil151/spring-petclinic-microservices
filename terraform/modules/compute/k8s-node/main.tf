resource "aws_instance" "k8s_node" {
  ami = var.ami.id
  instance_type = var.instance
}