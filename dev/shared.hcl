# must match the terragrunt.remote_state.config in terraform.tfvars
terraform_state_bucket         = "admin-terraform-state.spi3pl-org"
terraform_state_bucket_region  = "us-east-1"
terraform_state_dynamodb_table = "admin-terraform-lock"
cloudtrail_bucket_name         = "admin-cloudtrail.spi3pl-org"

aws_default_region = "us-east-1"
org_name           = "spi3pl-org"

security_acct_email     = "aws.security@spi3pl.com"
authapi_acct_email      = "aws.auth_api@spi3pl.com"
authapi_dev_acct_email  = "aws.auth_api_dev@spi3pl.com"

administrator_default_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
developer_default_arn     = "arn:aws:iam::aws:policy/PowerUserAccess"
billing_default_arn       = "arn:aws:iam::aws:policy/job-function/Billing"
developer_role_name       = "Developer"

authapi_account_id = "526803499951"
security_account_id = "615052230087"
platform_name = "auth-api"
environment = "prod"
app_port = 80
availability_zones = ["us-east-1a", "us-east-1b"]
app_count = 2
app_image = "526803499951.dkr.ecr.us-east-1.amazonaws.com/authapi-ecr-repo:latest"

default_branch = "master"
repository_name = "authapi"
developer_group = ""
api_custom_domain = "auth.spi3pl-tech.com"
authapi_certificate_arn = "arn:aws:acm:us-east-1:526803499951:certificate/4d7cda61-d479-4d25-9660-fd5455d4f79e"
authapi_hosted_zone_id = "Z08129321PJM3HEZR9DA" # hosted zone in security account
deployment_service_account_user_arn = "arn:aws:iam::615052230087:user/deployment-service-account"
