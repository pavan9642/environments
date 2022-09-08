terraform {
  backend "s3" {}
}

provider "aws" {

  assume_role {
    role_arn = "arn:aws:iam::${var.authapi_account_id}:role/Administrator"
  }

  region = var.aws_default_region
}

locals {
  name   = "auth-api-rds-postgresql"
  region = var.aws_default_region
  tags = {
    Owner       = local.name
    Environment = var.environment
  }
}



# VPC for ECS Fargate
module "vpc_for_ecs_fargate" {
  source = "./modules/base-api/vpc"
  vpc_tag_name = "${var.platform_name}-vpc"
  number_of_private_subnets = 2
  private_subnet_tag_name = "${var.platform_name}-private-subnet"
  route_table_tag_name = "${var.platform_name}-rt"
  environment = var.environment
  security_group_lb_name = "${var.platform_name}-alb-sg"
  security_group_ecs_tasks_name = "${var.platform_name}-ecs-tasks-sg"
  app_port = var.app_port
  main_pvt_route_table_id = module.vpc_for_ecs_fargate.main_pvt_route_table_id
  availability_zones = var.availability_zones
  aws_default_region = var.aws_default_region
  public_subnet_tag_name = "${var.platform_name}-public-subnet"
  number_of_public_subnets = 2
}

# ECS cluster
module ecs_cluster {
  source = "./modules/base-api/ecs-cluster"
  name = "${var.platform_name}-${var.environment}-cluster"
  cluster_tag_name = "${var.platform_name}-${var.environment}-cluster"
}

# ECS task definition and service
module ecs_task_definition_and_service {
  # Task definition and NLB
  source = "./modules/base-api/ecs-fargate"
  name = "${var.platform_name}-${var.environment}"
  enable_cross_zone_load_balancing = true
  app_image = var.app_image
  fargate_cpu                 = 512
  fargate_memory              = 1024
  app_port = var.app_port
  vpc_id = module.vpc_for_ecs_fargate.vpc_id
  environment = var.environment
  aws_default_region = var.aws_default_region
  # Service
  cluster_id = module.ecs_cluster.id 
  app_count = var.app_count
  aws_security_group_ecs_tasks_id = module.vpc_for_ecs_fargate.ecs_tasks_security_group_id
  private_subnet_ids = module.vpc_for_ecs_fargate.private_subnet_ids
}

# API Gateway and VPC link
module api_gateway {
  source = "./modules/base-api/api-gateway"
  name = "${var.platform_name}-${var.environment}"
  integration_input_type = "HTTP_PROXY"
  path_part = "{proxy+}"
  app_port = var.app_port
  nlb_dns_name = module.ecs_task_definition_and_service.nlb_dns_name
  nlb_arn = module.ecs_task_definition_and_service.nlb_arn
  environment = var.environment
}



module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4"

  name        = local.name
  description = "AuthAPI PostgreSQL security group"
  vpc_id      = module.vpc_for_ecs_fargate.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "AuthAPI PostgreSQL access from within VPC"
      cidr_blocks = module.vpc_for_ecs_fargate.vpc_cidr_block
    },
  ]

  tags = local.tags
}

################################################################################
# RDS Module
################################################################################

module "db" {
  source = "./modules/base-postgresql"

  identifier = local.name

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "11.13"
  family               = "postgres11" # DB parameter group
  major_engine_version = "11"         # DB option group
  instance_class       = "db.t2.micro" # Free tier

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = false

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  name     = "authapi_db_master"
  username = "authapi_db_master"
  password = var.auth_api_db_pw
  port     = 5432

  multi_az               = true
  subnet_ids             = module.vpc_for_ecs_fargate.private_subnet_ids
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  tags = local.tags
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
  db_subnet_group_tags = {
    "Sensitive" = "high"
  }
  app_db_pw = var.auth_api_db_pw
  app_account_id = var.authapi_account_id
  aws_default_region = var.aws_default_region
}

################################################################################
# RDS Proxy Module
################################################################################

module "rds_proxy_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "rds_proxy"
  description = "PostgreSQL RDS Proxy security group"
  vpc_id      = module.vpc_for_ecs_fargate.vpc_id

  revoke_rules_on_delete = true

  ingress_with_cidr_blocks = [
    {
      description = "Private subnet PostgreSQL access"
      rule        = "postgresql-tcp"
      cidr_blocks = join(",", module.vpc_for_ecs_fargate.private_subnet_cidr_blocks)
    }
  ]

  egress_with_cidr_blocks = [
    {
      description = "Database subnet PostgreSQL access"
      rule        = "postgresql-tcp"
      cidr_blocks = join(",", module.vpc_for_ecs_fargate.private_subnet_cidr_blocks)
    },
  ]

  tags = local.tags
}


module "rds_proxy" {
  source = "./modules/aws-rds-proxy"

  create_proxy = true

  name                   = local.name
  iam_role_name          = local.name
  vpc_subnet_ids         = module.vpc_for_ecs_fargate.private_subnet_ids
  vpc_security_group_ids = [module.rds_proxy_sg.security_group_id]

  db_proxy_endpoints = {
    read_write = {
      name                   = "read-write-endpoint"
      vpc_subnet_ids         = module.vpc_for_ecs_fargate.private_subnet_ids
      vpc_security_group_ids = [module.rds_proxy_sg.security_group_id]
      tags                   = local.tags
    }
  }

  secrets = {
    "authapi-rds-proxy" = {
      description = "rds-credentials"
      arn         = "arn:aws:secretsmanager:us-east-1:526803499951:secret:authapi-rds-proxy-YcP0Dc"
      kms_key_id  = "arn:aws:kms:us-east-1:526803499951:key/c514eb50-0014-4eb5-8b07-7f4ed90c5889"
    }
  }

  engine_family = "POSTGRESQL"
  debug_logging = true

  # Target RDS instance
  target_db_instance     = true
  db_instance_identifier = module.db.db_instance_id

  tags = local.tags
  app_account_id = var.authapi_account_id
  aws_default_region = var.aws_default_region
}




module authapi_custom_domain {
  source          = "./modules/custom-domain"
  api_id          = module.api_gateway.api_gateway_id
  api_stage_name  = module.api_gateway.api_gateway_stage_name
  domain_name     = var.api_custom_domain
  certificate_arn = var.authapi_certificate_arn
  route53_zone_id = var.authapi_hosted_zone_id
  tls_version = "TLS_1_2"
  security_account_id = var.security_account_id
  aws_default_region = var.aws_default_region
}

# Codebuild deployment resources
data "aws_iam_policy_document" "authapi_deployment_ecs_update_service" {
  statement {
    sid = "DeploymentECSUpdateService"

    effect = "Allow"

    actions = [
      "ecs:UpdateService",
      "iam:PassRole"
    ]

    resources = [
        "arn:aws:iam::${var.authapi_account_id}:role/main_ecs_tasks-auth-api-prod-role",
        "arn:aws:iam::${var.authapi_account_id}:role/ecs_tasks-auth-api-prod-role",
        "arn:aws:ecs:us-east-1:${var.authapi_account_id}:service/auth-api-prod-cluster/auth-api-prod-service"
    ]
  }
}


resource "aws_iam_policy" "authapi_ecs_codebuild_policy" {
  name = "DeploymentECSUpdate"
  policy = data.aws_iam_policy_document.authapi_deployment_ecs_update_service.json
}

resource aws_iam_role "assume_deployment_access_role" {
  name = "DeploymentECSUpdate"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.deployment_service_account_user_arn
        }
      }
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy_attachment" "authapi_ecs_codebuild_access" {
  policy_arn = aws_iam_policy.authapi_ecs_codebuild_policy.arn
  role       = aws_iam_role.assume_deployment_access_role.name
}
