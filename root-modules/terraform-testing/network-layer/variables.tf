variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}
variable "subnet_first_two_octets" {
  type        = string
  description = "First two octets of subnet IP ranges e.g. \"10.100\" for subnets with CIDR like \"10.100.0.0/20\"."
  default     = "10.0"
}
variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

locals {
  public_subnet_cidrs = [
    "${var.subnet_first_two_octets}.0.0/20",
    "${var.subnet_first_two_octets}.16.0/20",
    "${var.subnet_first_two_octets}.32.0/20",
  ]
  private_subnet_cidrs = [
    "${var.subnet_first_two_octets}.64.0/20",
    "${var.subnet_first_two_octets}.80.0/20",
    "${var.subnet_first_two_octets}.96.0/20",
  ]
  secure_subnet_cidrs = [
    "${var.subnet_first_two_octets}.128.0/20",
    "${var.subnet_first_two_octets}.144.0/20",
    "${var.subnet_first_two_octets}.160.0/20",
  ]
}
