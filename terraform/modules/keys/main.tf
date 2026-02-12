resource "tls_private_key" "spms_dev" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "spms_dev" {
  content = tls_private_key.spms_dev.private_key_pem
  filename = "${path.module}/spms-dev.pem"
}


