variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}
variable "name_prefix" {
  description = "Prefix for names of all VPC resources e.g. \"digistorm-prod-au\""
  default     = "digistorm-dev-us"
}
variable "subnet_first_two_octets" {
  type        = string
  description = "First two octets of subnet IP ranges e.g. \"10.100\" for subnets with CIDR like \"10.100.0.0/20\"."
  default     = "10.0"
}

locals {
  availability_zones = {
    a = "${var.region}a"
    b = "${var.region}b"
    c = "${var.region}c"
  }
  public_subnet_cidrs = {
    a = "${var.subnet_first_two_octets}.0.0/20",
    b = "${var.subnet_first_two_octets}.16.0/20",
    c = "${var.subnet_first_two_octets}.32.0/20",
  }
  private_subnet_cidrs = {
    a = "${var.subnet_first_two_octets}.64.0/20",
    b = "${var.subnet_first_two_octets}.80.0/20",
    c = "${var.subnet_first_two_octets}.96.0/20",
  }
  secure_subnet_cidrs = {
    a = "${var.subnet_first_two_octets}.128.0/20",
    b = "${var.subnet_first_two_octets}.144.0/20",
    c = "${var.subnet_first_two_octets}.160.0/20",
  }
}
