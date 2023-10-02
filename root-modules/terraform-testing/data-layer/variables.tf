variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}
variable "name_prefix" {
  description = "Prefix for names of resources e.g. \"digistorm-prod-au\""
  default     = "digistorm-dev-us"
}
variable "bitbucket_private_key_ssm_parameter_path" {
  description = "Path to secure SSM parameter for Bitbucket private key"
  default     = "/BitbucketKeys/AWSSystemsManager/private"
}
variable "bitbucket_private_key" {
  description = "Private key value for Bitbucket deployment key. Use Terraform Cloud variable."
  type = string
}

locals {
  ssm_output_s3_bucket_name = "${var.name_prefix}-ssm-logs"
}
