variable "aws_region" {}
variable "Environment" {}
variable "bucket_name" {
  default = "petclinic-terraform-state-17a538b3"
}
variable "spms_vpc_cidr" {}
variable "spms_subnet_cidr" {}