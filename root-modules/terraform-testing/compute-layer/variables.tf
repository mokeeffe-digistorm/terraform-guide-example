variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}
variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t2.micro"
}
variable "instance_name" {
  description = "EC2 instance name"
  default     = "Provisioned by Terraform"
}
variable "name_prefix" {
  description = "Prefix for names of resources e.g. \"digistorm-prod-au\""
  default     = "digistorm-dev-us"
}
variable "chef_recipes_repository_name" {
  default = "git@bitbucket.org:digistorm/chef-recipes.git"
}
variable "chef_recipes_repository_branch" {
  default = "no-opsworks"
}
variable "bitbucket_private_key_ssm_parameter_path" {
  description = "Path to secure SSM parameter for Bitbucket private key"
  default     = "/BitbucketKeys/AWSSystemsManager/private"
}

locals {
  ssm_output_s3_bucket_name = "${var.name_prefix}-ssm-logs"
}
