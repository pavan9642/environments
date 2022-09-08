terraform {
  backend "s3" {}
}

provider "aws" {

  assume_role {
    role_arn = "arn:aws:iam::${var.authapi_account_id}:role/Administrator"
  }

  region = var.aws_default_region
}








