variable "terraform_state_bucket" {}
variable "terraform_state_bucket_region" {}
variable "aws_default_region" {}
variable "platform_name" {
  description = "The name of the platform"
  type = string
}

variable "environment" {
  description = "Application environment"
  type = string
}
