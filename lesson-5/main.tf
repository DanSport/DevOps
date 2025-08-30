terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---- S3 + DynamoDB для стейтів ----
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = var.tf_state_bucket_name
  table_name  = var.tf_lock_table_name
  tags = {
    Project = "lesson-5"
  }
}

# ---- VPC ----
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
  vpc_name           = "lesson-5-vpc"
}

# ---- ECR ----
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-5-ecr"
  scan_on_push = true
}
