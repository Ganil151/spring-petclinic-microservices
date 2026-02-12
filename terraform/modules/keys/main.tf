resource "tls_private_key" "spms_dev" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
