resource "local_file" "ansible_inventory" {
  filename        = var.inventory_file_path
  file_permission = "0600"

  content = templatefile("${path.module}/templates/ansible_inventory.tftpl", {
    jenkins_master_ip    = var.jenkins_master_ip
    jenkins_master_priv  = var.jenkins_master_priv
    worker_node_ips      = var.worker_node_ips
    worker_node_priv_ips = var.worker_node_priv_ips
    sonarqube_ip         = var.sonarqube_ip
    sonarqube_priv       = var.sonarqube_priv
    ssh_user             = var.ssh_user
    ssh_key_file         = var.ssh_key_file
    eks_cluster_name     = var.eks_cluster_name
    cluster_suffix       = var.cluster_suffix
    aws_region           = var.aws_region
    vpc_id               = var.vpc_id
    account_id           = var.account_id
    project_name         = var.project_name
    env_name             = var.environment
  })
}

resource "null_resource" "encrypt_inventory" {
  count = 1
  
  triggers = {
    inventory_content = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = "ansible-vault encrypt ${var.inventory_file_path} --vault-password-file ../.vault_pass"
  }

  depends_on = [local_file.ansible_inventory]
}

resource "null_resource" "run_ansible" {
  count = var.run_ansible ? 1 : 0

  triggers = {
    inventory_id = local_file.ansible_inventory.id
  }

  provisioner "local-exec" {
    command = "cd ${var.ansible_working_dir} && ansible-playbook -i ${var.inventory_file_path} --private-key ${var.ssh_key_file} playbooks/site.yml"
  }

  depends_on = [local_file.ansible_inventory, null_resource.encrypt_inventory]
}
