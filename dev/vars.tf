variable "terraform_state_bucket" {}
variable "terraform_state_bucket_region" {}
variable "aws_default_region" {}
variable "org_name" {}
variable "authapi_account_id" {}

#variable "module" {
#  description = "The terraform module used to deploy"
#  type        = string
#}

variable "platform_name" {
  description = "The name of the platform"
  type = string
}

variable "environment" {
  description = "Application environment"
  type = string
}

variable "app_port" {
  description = "Application port"
  type = number
}

variable "app_image" {
  type = string
  description = "Container image to be used for application in task definition file"
}

variable "availability_zones" {
  type  = list(string)
  description = "List of availability zones for the selected region"
}

variable "app_count" {
  type = string
  description = "The number of instances of the task definition to place and keep running."
}

variable "auth_api_db_pw" {}

variable "default_branch" {}
variable "repository_name" {}
variable "developer_group" {}
variable "api_custom_domain" {
  default = ""
}

variable "authapi_certificate_arn" {
  default = ""
}

variable "authapi_hosted_zone_id" {
  default = ""
}

variable "security_account_id" {}

variable "deployment_service_account_user_arn" {}
