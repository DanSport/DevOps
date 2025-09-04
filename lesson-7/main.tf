terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.30.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.13.1" }
  }
}

provider "aws" { region = var.aws_region }

# --- s3 backend infra (як у lesson-5) ---
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = var.tf_state_bucket_name
  table_name  = var.tf_lock_table_name
  tags        = { Project = "lesson-7" }
}

# --- vpc (можеш використати існуючі ресурси; тут показаний варіант створення) ---
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
  vpc_name           = "lesson-7-vpc"
}

# --- ecr ---
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = var.ecr_name
  scan_on_push = true
}

# --- eks ---
module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.eks_cluster_name
  cluster_version    = var.eks_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}
